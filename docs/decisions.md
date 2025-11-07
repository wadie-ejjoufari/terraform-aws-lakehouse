# Architecture Decisions (ADRs)

## Infrastructure Decisions

- Use S3 remote state (SSE-S3) and DynamoDB locking in eu-west-3 to avoid CMK cost.
- Start without VPC/NAT to minimize cost; add later.
- Use Firehose DirectPut from Lambda to avoid Kinesis Streams cost.
- Skip Glue Crawler; define schemas manually in Terraform.

## IAM Policy Management: `aws_iam_policy_document` vs `jsonencode()`

**Decision:** Use `aws_iam_policy_document` data sources for KMS key policies

**Rationale:**

- Type-safe validation at plan time
- Better readability than inline JSON
- Reusable across modules and environments
- Easier to test with `terraform console`
- Reduces code duplication

**Implementation:**

- KMS key policies use `data "aws_iam_policy_document"`
- S3 bucket policies remain as `jsonencode()` (simpler, less duplication)
- Future complex policies should prefer data sources

**Alternative Considered:** External JSON template files

- **Rejected:** Adds complexity for small team without clear benefit
- **Reconsider when:** Policy count exceeds 20 or team grows beyond 5 members

## KMS Key Consolidation

**Decision:** Use one shared KMS key per environment for all S3 buckets

**Rationale:**

- Cost reduction: $2/month → $1/month per environment ($36/year savings)
- Simplified key management
- Reduced IAM policy complexity
- Easier cross-service data access

**Implementation:**

- Each environment (dev/stage/prod) creates one KMS key
- Shared by data_lake and observability modules
- Key alias: `alias/dp-{env}-s3`

**Migration Strategy:**

- New consolidated keys deployed alongside existing keys
- No data migration required (existing buckets keep current keys)
- Future buckets use new shared key

## Query Layer Implementation

**Decision:** Implement Glue Catalog and Athena for SQL-based analytics

**Rationale:**

- Serverless, pay-per-query pricing model
- Native integration with S3 data lake
- Standard SQL interface for data analysts
- No infrastructure management overhead
- Automatic schema evolution support

**Implementation:**

- Created `catalog_athena` module for reusable query infrastructure
- Glue Catalog database for metadata management
- Athena workgroup with encrypted query results
- Bronze and Silver table definitions with partition projection
- Query results stored in centralized logging bucket with KMS encryption

**Table Architecture:**

- **Bronze (Raw) Table:** `github_events_bronze`
  - JSON format with partition projection (no crawler needed)
  - Partitioned by `ingest_dt` (YYYY-MM-DD)
  - Schema defined declaratively in Terraform
  - Location: `s3://{raw_bucket}/github/events/`
- **Silver (Processed) Table:** `github_events_silver`
  - Parquet format for optimized query performance
  - Managed via Athena CTAS queries
  - Partitioned by year/month for efficient queries
  - Location: `s3://{silver_bucket}/github/events_silver/`

**Cost Optimization:**

- Partition projection eliminates need for Glue Crawler ($0.44/DPU-hour saved)
- Parquet format reduces scan costs by ~80% vs JSON
- Lifecycle policies automatically archive query results
- Athena charges only $5 per TB scanned

**Security:**

- All query results encrypted with environment KMS key
- Workgroup configuration enforced (prevents unencrypted queries)
- Results stored in observability bucket with same security controls

```

```
