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
┌─────────────┐
│   Sources   │
└──────┬──────┘
       │
       v
┌─────────────────────────────────┐
│     Bronze Layer (S3)           │
│  Raw Data / Landing Zone        │
└────────────┬────────────────────┘
             │
        Glue Crawlers
             │
             v
┌─────────────────────────────────┐
│     Silver Layer (S3)           │
│  Cleaned & Validated Data       │
└────────────┬────────────────────┘
             │
        Glue ETL Jobs
             │
             v
┌─────────────────────────────────┐
│      Gold Layer (S3)            │
│  Aggregated Business Data       │
└────────────┬────────────────────┘
             │
             v
    ┌────────────────────┐
    │  Glue Data Catalog │
    └────────────────────┘
             │
             v
    ┌────────────────────┐
    │  Amazon Athena     │
    │  (Query Engine)    │
    └────────────────────┘
```

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
