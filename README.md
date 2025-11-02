# terraform-aws-lakehouse

Production-ready AWS Data Lakehouse infrastructure as code using Terraform.

## Architecture

A modern data lakehouse implementation on AWS featuring:

- **S3** for data lake storage (Bronze/Silver/Gold layers)
- **AWS Glue** for data catalog and ETL
- **Amazon Athena** for SQL analytics
- **Lake Formation** for data governance
- **IAM** for fine-grained access control
- **KMS** for encryption at rest with automatic key rotation

See [docs/architecture.md](docs/architecture.md) for detailed architecture.

## Features

### Data Lake Storage

Three-tier medallion architecture implemented with S3:

| Tier      | Purpose                                   | Bucket Pattern    |
| --------- | ----------------------------------------- | ----------------- |
| 🥉 Raw    | Ingestion layer for raw, unprocessed data | `{prefix}-raw`    |
| 🥈 Silver | Cleansed and validated data               | `{prefix}-silver` |
| 🥇 Gold   | Curated, business-ready data              | `{prefix}-gold`   |

**Example:** `dp-dev-{account-id}-raw`, `dp-dev-{account-id}-silver`, `dp-dev-{account-id}-gold`

### Security

- **Encryption at Rest:** AWS KMS with customer-managed keys (CMK)
  - Automatic annual key rotation enabled
  - One shared key per environment for cost optimization
  - Separate key for Terraform state
- **Encryption in Transit:** TLS-only access enforced via bucket policies
- **Access Control:**
  - Public access blocked by default on all buckets
  - Service-specific KMS key policies (least privilege)
  - IAM OIDC for CI/CD (no long-lived credentials)
- **Audit & Compliance:**
  - Centralized access logging to observability bucket
  - S3 versioning enabled for data recovery
  - Point-in-time recovery on DynamoDB state lock table

### Lifecycle Management

Automatic data tiering to optimize costs:

- **Standard-IA:** After 30 days
- **Glacier:** After 180 days
- **Expiration:** After 730 days (2 years)
- **Incomplete multipart uploads:** Cleaned up after 7 days

### Observability

Centralized logging infrastructure:

- Dedicated S3 bucket for access logs
- 90-day transition to Glacier for log archives
- 365-day log retention
- Same KMS encryption as data lake buckets

## Prerequisites

- Terraform >= 1.8.0
- AWS CLI configured with appropriate credentials
- Python 3.8+ (for pre-commit hooks)
- pre-commit: `pip install pre-commit`

## Quick Start

### Using Makefile (Recommended)

The project includes a comprehensive Makefile for all common operations:

```bash
# View all available commands
make help

# Setup (one-time)
make init-remote-state    # Bootstrap S3 backend
make init-dev             # Initialize dev environment

# Deploy
make plan-dev             # Plan changes
make apply-dev            # Apply changes

# Validate
make check-dev            # Full validation
make security             # Security scans

# Destroy (with safeguards)
make destroy-dev          # Destroy dev environment
```

See `make help` for the complete list of commands.

### Manual Setup

### 1. Bootstrap Remote State (One-time setup)

```bash
cd global/remote-state
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your AWS account ID and region
terraform init
terraform plan
terraform apply
```

Note the outputs - you'll need them for environment backend configuration.

### 2. Configure GitHub OIDC for CI/CD

Set up AWS IAM OIDC provider and role for GitHub Actions:

```bash
cd global/iam_gh_oidc
terraform init
terraform apply \
  -var "region=eu-west-3" \
  -var "repo=<your-github-org>/<your-repo-name>" \
  -var "role_name=gh-actions-plan-dev"
```

or, if you prefer using a variable file:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GitHub organization and repository name
terraform apply
```

Note the role ARN output and add it to your GitHub repository secrets as `AWS_OIDC_ROLE_ARN`.

### 3. Update Environment Backend Configurations

Replace `<ACCOUNT_ID>` in each `envs/*/backend.hcl` with your AWS account ID.

### 4. Deploy to an Environment

```bash
cd envs/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars as needed
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

### 5. View Deployed Resources

```bash
# View bucket names and KMS key details
terraform output

# Example output:
# kms_key_arn = "arn:aws:kms:eu-west-3:123456789:key/abc-123"
# data_lake_buckets = {
#   "raw"    = "dp-dev-123456789-raw"
#   "silver" = "dp-dev-123456789-silver"
#   "gold"   = "dp-dev-123456789-gold"
# }
```

## Project Structure

```
.
├── global/
│   ├── remote-state/          # S3 backend bootstrap
│   └── iam_gh_oidc/           # GitHub OIDC provider for CI/CD
├── modules/
│   ├── data_lake/             # S3 buckets (raw/silver/gold)
│   ├── observability/         # Centralized logging
│   └── iam_gh_oidc/           # Reusable IAM OIDC module
├── envs/
│   ├── dev/                   # Development environment
│   ├── stage/                 # Staging environment
│   └── prod/                  # Production environment
├── .github/
│   └── workflows/
│       └── plan-validate.yml  # CI/CD pipeline
├── docs/                      # Documentation
├── .pre-commit-config.yaml    # Pre-commit hooks
├── .tflint.hcl                # TFLint configuration
└── infracost.yml              # Cost estimation config
```

## Environments

| Environment | AWS Region | Purpose                   |
| ----------- | ---------- | ------------------------- |
| dev         | eu-west-3  | Development and testing   |
| stage       | eu-west-3  | Pre-production validation |
| prod        | eu-west-3  | Production workloads      |

## KMS Key Architecture

| Component         | KMS Key                 | Purpose                       | Monthly Cost |
| ----------------- | ----------------------- | ----------------------------- | ------------ |
| Terraform State   | `alias/terraform-state` | Remote state & DynamoDB locks | $1.00        |
| Dev Environment   | `alias/dp-dev-s3`       | All dev S3 buckets (shared)   | $1.00        |
| Stage Environment | `alias/dp-stage-s3`     | All stage S3 buckets (shared) | $1.00        |
| Prod Environment  | `alias/dp-prod-s3`      | All prod S3 buckets (shared)  | $1.00        |
| **Total**         |                         |                               | **$4.00/mo** |

All KMS keys feature:

- Automatic annual rotation
- 10-day deletion window for recovery
- Service-scoped policies (S3, DynamoDB)

## CI/CD

The project includes a GitHub Actions workflow that automatically:

- Runs on pull requests affecting infrastructure code
- Executes pre-commit hooks (formatting, linting, security scans)
- Authenticates to AWS using OIDC (no long-lived credentials)
- Validates Terraform configurations
- Runs security scans with TFLint, Trivy, and Checkov
- Generates and uploads Terraform plans as artifacts
- Posts a summary comment on pull requests

### Setting up CI/CD

1. Deploy the IAM OIDC configuration (see Quick Start step 2)
2. Add the role ARN to GitHub repository secrets as `AWS_OIDC_ROLE_ARN`
3. The workflow will automatically run on pull requests

## Development Setup

### Quick Setup with Makefile

```bash
# Check installed tools
make check-tools

# Setup development environment
make setup

# Check AWS configuration
make check-aws
```

### Install Pre-commit Hooks

```bash
pre-commit install
pre-commit run --all-files
```

### Install Required CLIs

```bash
# TFLint
curl -sSL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
tflint --init

# Trivy (security scanning)
# See: https://aquasecurity.github.io/trivy/latest/getting-started/installation/

# Checkov (policy as code)
pipx install checkov
```

### Linting & Validation

```bash
# Using Makefile (recommended)
make check-all            # Complete validation
make fmt                  # Format code
make validate             # Validate configs
make lint                 # Run TFLint
make security             # Security scans

# Manual commands
# Format all Terraform files
terraform fmt -recursive

# Validate configurations
cd envs/dev
terraform init -backend-config=backend.hcl
terraform validate

# Run TFLint
tflint --config=../../.tflint.hcl

# Security scan
trivy config .
```

### Cost Estimation

```bash
# Using Makefile (recommended)
make cost                 # All environments
make cost-dev             # Dev only
make cost-diff-dev        # Show cost changes

# Manual commands
# Install infracost
curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh

# Estimate costs
cd envs/dev
infracost breakdown --path=.

# Compare changes
infracost diff --path=.
```

## Outputs

Each environment exports the following outputs:

| Output              | Description                                    |
| ------------------- | ---------------------------------------------- |
| `kms_key_arn`       | ARN of the shared environment KMS key          |
| `kms_key_id`        | ID of the shared environment KMS key           |
| `kms_key_alias`     | Alias of the KMS key (e.g., `alias/dp-dev-s3`) |
| `data_lake_buckets` | Map of bucket names by tier (raw/silver/gold)  |
| `log_bucket_name`   | Name of the centralized logging bucket         |

## Cost Breakdown

Estimated monthly costs per environment:

| Resource Type      | Quantity | Unit Cost | Monthly Cost |
| ------------------ | -------- | --------- | ------------ |
| KMS Key            | 1        | $1.00     | $1.00        |
| S3 Storage (100GB) | 3 tiers  | $0.023/GB | $6.90        |
| S3 Requests        | Variable | $0.005/1k | ~$0.10       |
| **Total (dev)**    |          |           | **~$8.00**   |

**3 environments (dev/stage/prod): ~$24/month + Global state key ($1) = ~$25/month**

> Costs vary based on actual data storage and request volume. Use `infracost` for accurate estimates.

## Documentation

- [Architecture](docs/architecture.md) - System architecture and design
- [Decisions](docs/decisions.md) - Architectural decision records (ADRs)
- [Runbook](docs/runbook.md) - Operational procedures and destroy steps
