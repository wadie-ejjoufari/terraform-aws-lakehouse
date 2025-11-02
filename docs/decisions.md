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
