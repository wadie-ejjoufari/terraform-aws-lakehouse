# terraform-aws-lakehouse

AWS Data Lakehouse infrastructure as code using Terraform.

## Architecture

A modern data lakehouse implementation on AWS featuring:

- **S3** for data lake storage (Bronze/Silver/Gold layers)
- **AWS Glue** for data catalog and ETL
- **Amazon Athena** for SQL analytics
- **Lake Formation** for data governance
- **IAM** for fine-grained access control

See [docs/architecture.md](docs/architecture.md) for detailed architecture.

## Prerequisites

- Terraform >= 1.8.0
- AWS CLI configured with appropriate credentials
- Python 3.8+ (for pre-commit hooks)
- pre-commit: `pip install pre-commit`

## Quick Start

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

## Development Setup

### Install the required CLIs

```bash
# --- TFLint ---
curl -sSL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
sudo cp .tflint.hcl /usr/local/bin
tflint --version

# --- Trivy (replaces tfsec) ---
sudo apt-get update
sudo apt-get install -y wget gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo gpg --dearmor -o /usr/share/keyrings/trivy.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt-get update && sudo apt-get install -y trivy
trivy --version

# --- Checkov ---
pipx install checkov
checkov --version
```

### Initialize TFLint plugins

```bash
tflint --init
```

### Install Pre-commit Hooks

```bash
pre-commit install
pre-commit run --all-files
```

### Run Linting

```bash
# Format all Terraform files
terraform fmt -recursive

# Validate configurations
cd envs/dev
terraform validate

# Run TFLint
tflint --config=../../.tflint.hcl
```

### Cost Estimation

```bash
# Install infracost: https://www.infracost.io/docs/
# Downloads the CLI based on your OS/arch and puts it in /usr/local/bin
curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh
infracost breakdown --path=envs/dev
infracost diff --path=envs/dev
```

## Project Structure

```
.
├── global/
│   ├── remote-state/          # S3 backend bootstrap
│   └── iam_gh_oidc/           # GitHub OIDC provider for CI/CD
├── modules/
│   └── iam_gh_oidc/           # Reusable IAM OIDC module
├── envs/
│   ├── dev/                   # Development environment
│   ├── stage/                 # Staging environment
│   └── prod/                  # Production environment
├── .github/
│   └── workflows/
│       └── plan-validate.yml  # CI/CD pipeline for PR validation
├── docs/                      # Documentation
├── .pre-commit-config.yaml    # Pre-commit hooks
├── .tflint.hcl                # TFLint configuration
└── infracost.yml              # Infracost configuration
```

## Environments

| Environment | AWS Region | Purpose                   |
| ----------- | ---------- | ------------------------- |
| dev         | eu-west-3  | Development and testing   |
| stage       | eu-west-3  | Pre-production validation |
| prod        | eu-west-3  | Production workloads      |

## CI/CD

The project includes a GitHub Actions workflow (`plan-validate.yml`) that automatically:

- Runs on pull requests affecting infrastructure code
- Executes pre-commit hooks (formatting, linting, security scans)
- Authenticates to AWS using OIDC (no long-lived credentials)
- Validates Terraform configurations
- Runs security scans with TFLint, Tfsec, and Checkov
- Generates and uploads Terraform plans as artifacts
- Posts a summary comment on pull requests

### Setting up CI/CD

1. Deploy the IAM OIDC configuration (see Quick Start step 2)
2. Add the role ARN to GitHub repository secrets as `AWS_OIDC_ROLE_ARN`
3. The workflow will automatically run on pull requests

## Documentation

- [Architecture](docs/architecture.md) - System architecture and design
- [Decisions](docs/decisions.md) - Architectural decision records
- [Runbook](docs/runbook.md) - Operational procedures

## Security

- All S3 buckets are encrypted at rest
- State files are stored in S3 with versioning enabled
- DynamoDB state locking prevents concurrent modifications
- Pre-commit hooks scan for security issues with tfsec and checkov
- Private keys detection enabled
