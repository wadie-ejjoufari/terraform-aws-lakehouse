# Architectural Decision Records (ADR)

This document captures the key architectural decisions and their rationale.

---

## ADR-001: Terraform for All Infrastructure

**Decision:** Use Terraform as the single source of truth for all AWS resources (S3, KMS, Lambda, Athena, Glue, IAM).

**Rationale:**

- Reproducible, version-controlled infrastructure
- Easy to replicate across environments (dev/stage/prod)
- PR-based review workflow
- Automated CI/CD validation

**Implementation:**

- Modular structure: `global/` (state, OIDC), `modules/` (reusable), `envs/` (per-environment)
- Remote state in S3 with DynamoDB locking
- Makefile wrappers for common operations

---

## ADR-002: Lambda → S3 for Real-Time GitHub Events (No Firehose/Kinesis)

**Decision:** Use EventBridge + Lambda for ingestion instead of Kinesis/Firehose.

**Rationale:**

- Free tier eligible (Kinesis/Firehose cost $25+/month)
- GitHub Public API rate limit fits 5-minute polling (60 req/hr, 288 req/day ≈ 10/hr avg)
- Simple and maintainable
- No message queue overhead for single-producer, predictable schedule

**Trade-offs:**

- ✓ Cost: ~$2/month vs $26+/month (87% savings)
- ✓ Simplicity: Single Lambda function
- ✗ Latency: ~5 min batches, not real-time
- ✗ Limited to polling (can't handle webhooks)

---

## ADR-003: Manual Glue Catalog Schemas (No Crawlers)

**Decision:** Define all Glue Catalog tables declaratively in Terraform instead of using Glue Crawlers.

**Rationale:**

- Explicit schema control (no hidden crawler magic)
- Cost savings (~$0.44/DPU-hour per crawler)
- Version-controlled, reproducible
- Partition projection for Bronze eliminates crawler dependency

**Implementation:**

- Bronze: Partition projection on `ingest_dt` (no crawler needed)
- Silver: Manual schema with `year`/`month` partitions
- Gold: Manual schema with `ingest_dt` partition

---

## ADR-004: Silver Partitioning by Year/Month (Not ingest_dt)

**Decision:** Partition Silver table by `year` and `month` (derived from parsed timestamps).

**Rationale:**

- Aligns with typical business analytics queries (monthly reports, year-over-year)
- Accommodates late arrivals (events created in Dec but arrived in Jan partition into correct month)
- Easier to understand partition structure (`year=2024/month=01` vs `ingest_dt=2024-01-15`)
- Same Parquet compression benefits

**Note:** Gold uses `ingest_dt` partitioning because aggregates are scoped to "today's data."

---

## ADR-005: Athena CTAS for Silver/Gold Transforms (Not Glue Jobs)

**Decision:** Use Athena `INSERT INTO ... SELECT` queries (triggered by Lambda) for transforms instead of Glue Jobs or Step Functions.

**Rationale:**

- Fully serverless, pay-per-query
- Simple, transparent SQL (easier to debug/modify)
- No Glue job cluster management
- EventBridge + Lambda simple to understand

**Implementation:**

- Silver scheduler: Runs hourly, executes INSERT query
- Gold scheduler: Runs daily, executes INSERT query
- Both monitor via CloudWatch logs and alarms

---

## ADR-006: Single Shared KMS CMK Per Environment

**Decision:** Use one shared KMS key per environment for all S3 buckets (raw/silver/gold/logs).

**Rationale:**

- Cost: $1/month per key (vs $3/month for separate keys)
- Simplified key management
- Cross-bucket data access doesn't require cross-key policy complexity

**Implementation:**

- One key per environment: `alias/dp-<env>-s3`
- Separate key for Terraform state

**Cost Savings:** $2/month × 3 envs = $72/year

---

## ADR-007: SSE-KMS + TLS-Only Bucket Policy

**Decision:** Encrypt all S3 buckets with KMS and enforce TLS-only access via bucket policy.

**Rationale:**

- Production-grade security posture
- Audit trail through KMS API calls
- Protects against unencrypted writes
- Demonstrates security best practices

**Implementation:**

- Default encryption: `SSE-KMS`
- Bucket policy: `aws:SecureTransport = true`
- Public access blocked on all buckets

---

## ADR-008: Makefile Wrappers + Direct Terraform

**Decision:** Provide Makefile targets for common operations, but allow direct `terraform` commands.

**Rationale:**

- Makefile: Enforces best practices, hides complexity, good for CI and new team members
- Direct terraform: Flexibility for debugging, advanced operations, local development

**Implementation:**

- `make init-dev`, `make plan-dev`, `make apply-dev`
- `make destroy-dev`, `make check-dev`
- Direct alternatives always documented

**Makefile Philosophy:** "Batteries included, but hackable"

---

## ADR-009: Nightly Drift Detection via GitHub Actions

**Decision:** Run `terraform plan -detailed-exitcode` nightly to detect infrastructure drift.

**Rationale:**

- Automatic detection of manual console changes
- GitHub Issues created when drift detected (label: `drift`)
- Ensures actual state == desired state
- Low cost (runs only at night)

---

## ADR-010: OIDC for GitHub Actions CI/CD (No Long-Lived Credentials)

**Decision:** Use AWS IAM OIDC provider to authenticate GitHub Actions instead of long-lived access keys.

**Rationale:**

- No credentials to rotate/manage
- Short-lived tokens (scoped to specific repo/branch)
- Follows AWS and GitHub best practices
- Reduced blast radius if compromised

**Implementation:**

- GitHub OIDC provider created in `global/iam_gh_oidc/`
- Plan-only role for CI (no apply permissions)
- Drift detection role can detect but not modify

---

## ADR-011: Cost-Conscious Design

**Decision:** Optimize for minimal AWS costs without sacrificing functionality.

**Rationale:**

- Small team/project budget constraints
- Educational/portfolio context (cost awareness is marketable)
- Free tier eligibility (Lambda, Athena, Glue Catalog basics)

**Implementation:**

- Lambda → S3 instead of Kinesis
- Athena instead of Glue Jobs
- Partition projection instead of Crawlers
- Shared KMS keys
- Estimated: ~$8/month per environment + $1/month state

---

## Rejected Alternatives

| Alternative                  | Why Rejected                                              |
| ---------------------------- | --------------------------------------------------------- |
| **Glue Crawlers**            | Cost + implicit behavior. Manual schemas preferred.       |
| **Kinesis Firehose**         | $26+/month vs $2/month Lambda. Not needed for GitHub API. |
| **Lake Formation**           | Overkill for 3-bucket setup. IAM policies sufficient.     |
| **Step Functions**           | Complexity. EventBridge + Lambda simpler.                 |
| **Separate KMS per bucket**  | $36/year savings with shared key. Not worth complexity.   |
| **Cross-region replication** | Dev doesn't need it. Prod could add later.                |
| **VPC endpoints**            | Public endpoints + TLS sufficient for this use case.      |
