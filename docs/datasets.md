# Datasets Documentation

This document describes the structure and contents of each data layer in the lakehouse.

## Bronze Layer (Raw Data)

**Table Name:** `github_events_bronze`

**Location:** `s3://<env>-raw/github/events/ingest_dt=YYYY-MM-DD/`

**Format:** JSONL (JSON Lines)

**Partitioning:** `ingest_dt` (date) - automatic partition projection

**Columns:**

| Column        | Type   | Description                               |
| ------------- | ------ | ----------------------------------------- |
| `id`          | string | GitHub event ID                           |
| `type`        | string | Event type (PushEvent, PullRequest, etc.) |
| `created_at`  | string | ISO 8601 timestamp of event creation      |
| `repo_id`     | bigint | Repository ID                             |
| `repo_name`   | string | Repository name (org/repo)                |
| `actor_id`    | bigint | User ID of event creator                  |
| `actor_login` | string | Username of event creator                 |
| `payload_raw` | string | Raw JSON payload from GitHub API          |

**Retention:** 730 days (2 years)

**Access Pattern:** Debugging, raw data exploration, schema validation

**Example Query:**

```sql
SELECT * FROM github_events_bronze
WHERE ingest_dt = '2024-01-15'
LIMIT 10;
```

---

## Silver Layer (Cleaned Data)

**Table Name:** `github_events_silver`

**Location:** `s3://<env>-silver/github/events_silver/year=YYYY/month=MM/`

**Format:** Parquet (columnar, compressed)

**Partitioning:** `year` (YYYY), `month` (MM) - derived from `event_date`

**Columns:**

| Column        | Type   | Description                            |
| ------------- | ------ | -------------------------------------- |
| `event_id`    | string | GitHub event ID (from Bronze.id)       |
| `event_type`  | string | Event type (cleaned from Bronze.type)  |
| `event_date`  | date   | Date of event (parsed from created_at) |
| `repo_name`   | string | Repository name (org/repo)             |
| `actor_login` | string | Username of event creator              |

**Retention:** 730 days (2 years)

**Data Quality:**

- All nulls validated and handled
- Timestamps parsed to ISO 8601 dates
- Duplicates removed per event ID
- Parquet format provides compression (80% smaller than raw JSON)

**Access Pattern:** Fact tables, detailed analysis by repo/actor/type, time-series analysis

**Example Query:**

```sql
-- Count events per type for a specific month
SELECT
  event_type,
  COUNT(*) as event_count
FROM github_events_silver
WHERE year = '2024' AND month = '01'
GROUP BY event_type
ORDER BY event_count DESC;
```

**Transform Logic (Athena Scheduled INSERT):**

```sql
INSERT INTO github_events_silver
  (event_id, event_type, event_date, repo_name, actor_login, year, month)
SELECT
  CAST(id AS varchar) AS event_id,
  CAST(type AS varchar) AS event_type,
  DATE(from_iso8601_timestamp(created_at)) AS event_date,
  CAST(repo_name AS varchar) AS repo_name,
  CAST(actor_login AS varchar) AS actor_login,
  CAST(date_format(from_iso8601_timestamp(created_at), '%Y') AS varchar) AS year,
  CAST(date_format(from_iso8601_timestamp(created_at), '%m') AS varchar) AS month
FROM github_events_bronze
WHERE ingest_dt = date_format(current_date, '%Y-%m-%d');
```

---

## Gold Layer (Analytics-Ready Aggregates)

**Table Name:** `github_events_gold_daily`

**Location:** `s3://<env>-gold/github/events_gold_daily/ingest_dt=YYYY-MM-DD/`

**Format:** Parquet (columnar, compressed)

**Partitioning:** `ingest_dt` (date)

**Columns:**

| Column         | Type   | Description                           |
| -------------- | ------ | ------------------------------------- |
| `ingest_dt`    | date   | Date of the aggregated data           |
| `event_type`   | string | Type of GitHub event                  |
| `repo_name`    | string | Repository name (org/repo)            |
| `events_count` | bigint | Number of events for this combination |

**Retention:** 730 days (2 years)

**Aggregation Level:** Daily aggregates by event type and repository

**Access Pattern:** Dashboards, analytics, reporting, KPI tracking

**Example Queries:**

### 1. Top Event Types (Today)

```sql
SELECT
  event_type,
  SUM(events_count) AS total_events
FROM github_events_gold_daily
WHERE ingest_dt = date_format(current_date, '%Y-%m-%d')
GROUP BY event_type
ORDER BY total_events DESC
LIMIT 10;
```

### 2. Top Active Repositories (Today)

```sql
SELECT
  repo_name,
  SUM(events_count) AS total_events
FROM github_events_gold_daily
WHERE ingest_dt = date_format(current_date, '%Y-%m-%d')
GROUP BY repo_name
ORDER BY total_events DESC
LIMIT 10;
```

### 3. Event Trend (Last 7 Days)

```sql
SELECT
  ingest_dt,
  SUM(events_count) AS total_events
FROM github_events_gold_daily
WHERE ingest_dt >= date_add('day', -7, current_date)
GROUP BY ingest_dt
ORDER BY ingest_dt;
```

### 4. Repository Trend (Top 5, Last 30 Days)

```sql
WITH top_repos AS (
  SELECT repo_name
  FROM github_events_gold_daily
  WHERE ingest_dt >= date_add('day', -30, current_date)
  GROUP BY repo_name
  ORDER BY SUM(events_count) DESC
  LIMIT 5
)
SELECT
  ingest_dt,
  repo_name,
  SUM(events_count) AS events_count
FROM github_events_gold_daily
WHERE ingest_dt >= date_add('day', -30, current_date)
  AND repo_name IN (SELECT repo_name FROM top_repos)
GROUP BY ingest_dt, repo_name
ORDER BY ingest_dt DESC, repo_name;
```

**Transform Logic (Athena Scheduled INSERT):**

```sql
INSERT INTO github_events_gold_daily
SELECT
  ingest_dt,
  type        AS event_type,
  repo_name,
  COUNT(*)    AS events_count
FROM github_events_silver
WHERE ingest_dt = date_format(current_date, '%Y-%m-%d')
GROUP BY ingest_dt, type, repo_name;
```

---

## Medallion Architecture Benefits

| Aspect         | Bronze      | Silver           | Gold             |
| -------------- | ----------- | ---------------- | ---------------- |
| **Speed**      | Seconds     | Minutes          | Minutes          |
| **Cost**       | High (JSON) | Medium (Parquet) | Low (aggregated) |
| **Complexity** | Simple      | Medium           | Simple           |
| **Users**      | Engineers   | Analysts         | Business users   |
| **Use Case**   | Debugging   | Analysis         | Reporting        |

---

## Scheduling

| Layer  | Job Name         | Schedule    | Dependency       | Typical Duration |
| ------ | ---------------- | ----------- | ---------------- | ---------------- |
| Bronze | GitHub Lambda    | Hourly      | GitHub API       | < 1 minute       |
| Silver | silver-scheduler | Hourly      | Bronze populated | 2-5 minutes      |
| Gold   | gold-scheduler   | Daily (1am) | Silver populated | 1-2 minutes      |

---

## Monitoring & Alerts

Each scheduled job has CloudWatch monitoring:

- **Lambda Duration:** Tracks execution time
- **Lambda Errors:** Alerts on failures
- **Athena Query Status:** Tracks INSERT success/failure
- **S3 File Counts:** Validates new partitions created

View logs via:

```bash
# Silver scheduler
aws logs tail /aws/lambda/dp-dev-silver-scheduler --follow

# Gold scheduler
aws logs tail /aws/lambda/dp-dev-gold-scheduler --follow
```

---

## Cost Optimization

| Layer  | Optimization        | Details                                     |
| ------ | ------------------- | ------------------------------------------- |
| Bronze | S3 Lifecycle        | Move to IA after 30 days, Glacier after 180 |
| Silver | Parquet + Partition | 80% reduction vs JSON, easy pruning         |
| Gold   | Pre-aggregated      | Only stores aggregates (minimal size)       |

Estimated sizes (per environment, per month):

- Bronze: ~5 GB (raw JSONL)
- Silver: ~1 GB (Parquet)
- Gold: ~10 MB (aggregates only)

**Total: ~6 GB/month → ~$0.14 in storage costs**

---

## Data Quality Validation

- **Nulls:** Minimal, validated during Silver transform
- **Duplicates:** Removed by event ID in Silver
- **Timeliness:** Bronze within 1 hour, Silver within 2 hours, Gold within 3 hours
- **Completeness:** All partitions generated daily for last 2 years

---

## Access Control

All tables use **column-level access** via IAM:

- **Public Access:** Blocked on all S3 buckets
- **Athena Queries:** Restricted via workgroup IAM policies
- **Encryption:** KMS keys per environment (no cross-environment access)

---
