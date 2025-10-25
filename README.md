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

### 2. Update Environment Backend Configurations

Replace `<ACCOUNT_ID>` in each `envs/*/backend.hcl` with your AWS account ID.

### 3. Deploy to an Environment

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
│   └── remote-state/          # S3 backend bootstrap
├── envs/
│   ├── dev/                   # Development environment
│   ├── stage/                 # Staging environment
│   └── prod/                  # Production environment
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
