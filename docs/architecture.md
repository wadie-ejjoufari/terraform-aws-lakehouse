# Architecture Documentation

## Overview

This project implements a modern data lakehouse on AWS, combining the best features of data lakes and data warehouses.

## Components

### Data Storage

- **S3 Buckets**: Multi-tier storage (Bronze/Silver/Gold)
  - Bronze: Raw data ingestion
  - Silver: Cleaned and validated data
  - Gold: Business-ready aggregated data

### Data Catalog

- **AWS Glue Data Catalog**: Central metadata repository
- **Glue Crawlers**: Automatic schema discovery

### Query Engine

- **Amazon Athena**: Serverless SQL queries
- **Athena Workgroups**: Query isolation and cost control

### Data Governance

- **Lake Formation**: Fine-grained access control
- **IAM Policies**: Service-level permissions

### ETL/Processing

- **AWS Glue Jobs**: Serverless ETL
- **Glue Workflows**: Orchestration

## Architecture Diagram

```
┌─────────────────────────────────────────┐
│   GitHub Public Events API              │
└────────────────────┬────────────────────┘
                     │
                Lambda (Scheduled)
                     │
                     v
┌─────────────────────────────────────────┐
│   Bronze Layer (S3)                     │
│   Raw JSONL Data                        │
│   s3://<env>-raw/github/events/         │
│   ingest_dt=YYYY-MM-DD/                 │
└────────────────────┬────────────────────┘
                     │
            Athena INSERT (Hourly)
                     │
                     v
┌─────────────────────────────────────────┐
│   Silver Layer (S3)                     │
│   Parsed & Validated Parquet            │
│   s3://<env>-silver/github/events_      │
│   silver/year=YYYY/month=MM/            │
│   Columns: event_id, event_type,        │
│   event_date, repo_name, actor_login    │
└────────────────────┬────────────────────┘
                     │
            Athena INSERT (Daily)
                     │
                     v
┌─────────────────────────────────────────┐
│   Gold Layer (S3)                       │
│   Aggregated Analytics Data             │
│   s3://<env>-gold/github/               │
│   events_gold_daily/ingest_dt=YYYY-MM-DD│
│   Columns: ingest_dt, event_type,       │
│   repo_name, events_count               │
└────────────────────┬────────────────────┘
                     │
                     v
        ┌────────────────────────┐
        │  AWS Glue Catalog      │
        │  (Metadata Registry)   │
        └────────────┬───────────┘
                     │
                     v
        ┌────────────────────────┐
        │  Amazon Athena         │
        │  (SQL Query Engine)    │
        │  with KMS Encryption   │
        └────────────────────────┘
```

## Data Flow

1. **Ingestion**: GitHub Events Lambda runs hourly, pulls latest events from GitHub Public Events API, writes raw JSONL to Bronze
2. **Silver Transform**: Hourly scheduled Athena job runs `INSERT INTO github_events_silver SELECT ...` from Bronze
3. **Gold Transform**: Daily scheduled Athena job runs `INSERT INTO github_events_gold_daily SELECT ...` from Silver, aggregating by event type and repo
4. **Query**: Users query Bronze, Silver, or Gold via Athena based on use case:
   - **Bronze**: Raw data exploration, debugging
   - **Silver**: Cleaned data, fact tables
   - **Gold**: Business-ready analytics, dashboards

## Data Catalog

All three tables are registered in **AWS Glue Data Catalog**:

| Table                      | Layer     | Format  | Partitioning       | Retention |
| -------------------------- | --------- | ------- | ------------------ | --------- |
| `github_events_bronze`     | Raw       | JSONL   | `ingest_dt` (date) | 730 days  |
| `github_events_silver`     | Clean     | Parquet | `year`, `month`    | 730 days  |
| `github_events_gold_daily` | Analytics | Parquet | `ingest_dt` (date) | 730 days  |

## Security Model

1. **Encryption**: AES-256 for S3, encryption at rest and in transit
2. **Access Control**: IAM + Lake Formation
3. **Network**: VPC endpoints for private connectivity
4. **Audit**: CloudTrail + S3 access logs

## Disaster Recovery

- S3 versioning enabled
- Cross-region replication for critical data (prod)
- Point-in-time recovery for DynamoDB

## Cost Optimization

- S3 Intelligent-Tiering for automatic cost optimization
- Athena query result caching
- Glue job bookmarks to process only new data
