# Architecture Documentation

## Overview

This project implements a **Terraform-managed data lakehouse on AWS** that ingests GitHub Public Events in real-time, stores them in a **Bronze/Silver/Gold** medallion architecture, and exposes analytics through **Amazon Athena** with security, CI/CD, and observability built-in.

All infrastructure is defined declaratively in Terraform and deployed via Makefiles or direct `terraform` commands.

---

## Core Components

### 1. Data Storage (S3)

- **S3 Buckets (per environment)**: Named `dp-<env>-<account-id>-{raw|silver|gold|logs}`
  - **Bronze**: Raw JSONL from GitHub events
  - **Silver**: Cleaned, typed Parquet
  - **Gold**: Daily aggregates for analytics
  - **Logs**: Access logs and Athena query results

**Key properties:**

- **SSE-KMS** encryption: One shared CMK per environment for all lake buckets
- **Versioning enabled** on lake buckets for data recovery
- **Public access blocked** on all buckets
- **TLS-only** bucket policy (`aws:SecureTransport = true`)
- **Lifecycle rules**: STANDARD → IA (30d) → Glacier (180d) → Expiration (730d)

### 2. Data Catalog (AWS Glue Catalog)

Three tables defined **declaratively in Terraform** (no crawlers):

- `github_events_bronze`: Raw JSONL with partition projection on `ingest_dt`
- `github_events_silver`: Parquet, partitioned by `year` and `month`
- `github_events_gold_daily`: Parquet aggregates, partitioned by `ingest_dt`

**No Glue Crawlers** — schemas are explicit for full control and reproducibility.

### 3. Query Engine (Amazon Athena)

- **Athena Workgroup**: Enforces KMS-encrypted results to logs bucket
- **Glue Database**: Metadata repository for all three tables
- Used for both interactive queries and scheduled transforms

### 4. Ingestion & Transform (Serverless Lambda + EventBridge)

**Bronze Ingestion** (Lambda + EventBridge, every 5 minutes):

- Fetches GitHub Public Events API
- Writes JSONL (gzip) to `s3://<env>-<account-id>-raw/github/events/ingest_dt=YYYY-MM-DD/`

**Silver Transform** (Lambda + Athena, every hour):

- Executes `INSERT INTO github_events_silver ... FROM github_events_bronze`
- Parses timestamps, normalizes fields
- Outputs Parquet to `s3://<env>-<account-id>-silver/github/events_silver/year=YYYY/month=MM/`

**Gold Transform** (Lambda + Athena, daily):

- Executes `INSERT INTO github_events_gold_daily ... FROM github_events_silver`
- Aggregates by `ingest_dt`, `event_type`, `repo_name`
- Outputs Parquet to `s3://<env>-<account-id>-gold/github/events_gold_daily/ingest_dt=YYYY-MM-DD/`

### 5. Security & Governance

- **KMS**: One shared CMK per environment + separate state key
- **IAM**: Least-privilege roles per Lambda (ingest, silver, gold schedulers)
- **Network**: Public endpoints (no VPC) with TLS enforcement
- **Audit**: S3 access logs, CloudWatch logs, CloudTrail

### 6. Observability & Drift

- **CloudWatch Logs**: Per-Lambda log groups under `/aws/lambda/`
- **CloudWatch Alarms**: Errors on ingest Lambda, failures on Athena transforms
- **Drift Detection**: Nightly GitHub Actions workflow (`terraform plan -detailed-exitcode`)

## Architecture Diagram

```
┌────────────────────────────────────┐
│  GitHub Public Events API          │
└─────────────────┬──────────────────┘
                  │
          EventBridge (5 min)
                  │
                  v
         ┌────────────────┐
         │ Lambda Ingest  │
         │ (GitHub → S3)  │
         └────────┬───────┘
                  │ JSONL
                  v
    ┌─────────────────────────────────────┐
    │ Bronze: s3://<env>-raw/...          │
    │ github/events/ingest_dt=YYYY-MM-DD/ │
    └─────────────────────────────────────┘
                  │
          EventBridge (hourly)
                  │
                  v
         ┌────────────────────┐
         │ Lambda: Silver     │
         │ (Athena INSERT)    │
         └────────┬───────────┘
                  │ Parquet
                  v
    ┌────────────────────────────────────────┐
    │ Silver: s3://<env>-silver/...          │
    │ github/events_silver/year/month/       │
    └────────────────────────────────────────┘
                  │
          EventBridge (daily)
                  │
                  v
         ┌────────────────────┐
         │ Lambda: Gold       │
         │ (Athena INSERT)    │
         └────────┬───────────┘
                  │ Parquet
                  v
    ┌────────────────────────────────────────┐
    │ Gold: s3://<env>-gold/...              │
    │ events_gold_daily/ingest_dt=YYYY-MM-DD/│
    └────────────────────────────────────────┘
                  │
                  v
        ┌──────────────────┐
        │ Glue Catalog     │
        │ (Metadata)       │
        └─────────┬────────┘
                  │
                  v
        ┌──────────────────┐
        │ Athena (KMS)     │
        │ Query Engine     │
        └──────────────────┘
```

## Data Flow

1. **Bronze (Ingestion)**: Lambda polls GitHub API every 5 minutes, writes JSONL to `ingest_dt=YYYY-MM-DD/` partition
2. **Silver (Transform)**: Hourly Athena job inserts into Silver from Bronze, parsing timestamps and outputting Parquet to `year/month/` partitions
3. **Gold (Analytics)**: Daily Athena job aggregates Silver into daily stats, outputs to `ingest_dt=YYYY-MM-DD/` partitions
4. **Query**: Users/dashboards query any tier via Athena based on use case
   - Bronze: Raw debugging
   - Silver: Detailed fact tables
   - Gold: Aggregated analytics & KPIs

## Data Catalog Summary

| Table                      | Layer     | Format  | Partitioning                       | Retention |
| -------------------------- | --------- | ------- | ---------------------------------- | --------- |
| `github_events_bronze`     | Raw       | JSONL   | `ingest_dt` (partition projection) | 730 days  |
| `github_events_silver`     | Clean     | Parquet | `year`, `month`                    | 730 days  |
| `github_events_gold_daily` | Analytics | Parquet | `ingest_dt`                        | 730 days  |

---

## Deployment & Operations

All infrastructure changes flow through:

1. **Code**: Changes in Terraform files
2. **Plan**: `make plan-<env>` (Makefile) or `terraform plan` (direct)
3. **Review**: GitHub PR review + automated validations (linting, security, cost)
4. **Apply**: `make apply-<env>` (Makefile) or `terraform apply` (direct)
5. **Verify**: Automated post-deployment checks

See [docs/runbook.md](runbook.md) for detailed operational procedures.
