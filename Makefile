# Terraform AWS Lakehouse - Makefile
# Common operations for infrastructure management

.PHONY: help init-remote-state init-oidc init-dev init-stage init-prod \
        plan-dev plan-stage plan-prod apply-dev apply-stage apply-prod \
        destroy-dev destroy-stage destroy-prod destroy-all \
        fmt validate lint security cost pre-commit \
        check-dev check-stage check-prod check-all \
        empty-buckets-dev verify-destroy \
        import-kms-alias fix-state-lock

# Default environment variable
ENV ?= dev

help:
	@echo "╔════════════════════════════════════════════════════════════════╗"
	@echo "║        Terraform AWS Lakehouse - Available Commands           ║"
	@echo "╚════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "SETUP & INITIALIZATION:"
	@echo "  make init-remote-state    - Bootstrap S3 backend (one-time setup)"
	@echo "  make init-oidc            - Setup GitHub OIDC for CI/CD"
	@echo "  make init-dev             - Initialize dev environment"
	@echo "  make init-stage           - Initialize stage environment"
	@echo "  make init-prod            - Initialize prod environment"
	@echo ""
	@echo "DEPLOYMENT:"
	@echo "  make plan-dev             - Plan changes for dev environment"
	@echo "  make plan-stage           - Plan changes for stage environment"
	@echo "  make plan-prod            - Plan changes for prod environment"
	@echo "  make apply-dev            - Apply changes to dev environment"
	@echo "  make apply-stage          - Apply changes to stage environment"
	@echo "  make apply-prod           - Apply changes to prod environment"
	@echo ""
	@echo "DESTROY:"
	@echo "  make destroy-dev          - Destroy dev environment (with confirmation)"
	@echo "  make destroy-stage        - Destroy stage environment (with confirmation)"
	@echo "  make destroy-prod         - Destroy prod environment (with confirmation)"
	@echo "  make destroy-all          - Destroy all environments (DANGER)"
	@echo "  make empty-buckets-dev    - Force empty all dev S3 buckets"
	@echo "  make verify-destroy       - Verify all resources are destroyed"
	@echo ""
	@echo "VALIDATION & TESTING:"
	@echo "  make check-dev            - Full validation for dev environment"
	@echo "  make check-stage          - Full validation for stage environment"
	@echo "  make check-prod           - Full validation for prod environment"
	@echo "  make check-all            - Validate all environments"
	@echo "  make fmt                  - Format all Terraform files"
	@echo "  make validate             - Validate Terraform configurations"
	@echo "  make lint                 - Run TFLint on all environments"
	@echo "  make security             - Run security scans (Trivy + Checkov)"
	@echo ""
	@echo "COST ANALYSIS:"
	@echo "  make cost                 - Run Infracost on all environments"
	@echo "  make cost-dev             - Cost estimate for dev only"
	@echo ""
	@echo "TROUBLESHOOTING:"
	@echo "  make import-kms-alias     - Import existing KMS alias into state"
	@echo "  make fix-state-lock       - Force unlock state (use with caution)"
	@echo "  make state-list-dev       - List all resources in dev state"
	@echo ""
	@echo "DEVELOPMENT:"
	@echo "  make pre-commit           - Install and run pre-commit hooks"
	@echo "  make clean                - Clean up Terraform cache files"
	@echo ""
	@echo "Examples:"
	@echo "  make init-remote-state    # First time setup"
	@echo "  make plan-dev             # Review changes"
	@echo "  make apply-dev            # Deploy to dev"
	@echo "  make check-dev            # Validate deployment"
	@echo ""

# ============================================================================
# SETUP & INITIALIZATION
# ============================================================================

init-remote-state:
	@echo "Bootstrapping remote state infrastructure..."
	@if [ ! -f global/remote-state/terraform.tfvars ]; then \
		echo "terraform.tfvars not found. Creating from example..."; \
		cp global/remote-state/terraform.tfvars.example global/remote-state/terraform.tfvars; \
		echo "Please edit global/remote-state/terraform.tfvars with your values"; \
		exit 1; \
	fi
	cd global/remote-state && terraform init && terraform plan
	@echo "Remote state ready. Run 'cd global/remote-state && terraform apply' to create."

init-oidc:
	@echo "Initializing GitHub OIDC..."
	@if [ ! -f global/iam_gh_oidc/terraform.tfvars ]; then \
		echo "terraform.tfvars not found. Creating from example..."; \
		cp global/iam_gh_oidc/terraform.tfvars.example global/iam_gh_oidc/terraform.tfvars; \
		echo "Please edit global/iam_gh_oidc/terraform.tfvars with your values"; \
		exit 1; \
	fi
	cd global/iam_gh_oidc && terraform init && terraform plan

init-dev:
	@echo "Initializing dev environment..."
	@if [ ! -f envs/dev/terraform.tfvars ]; then \
		cp envs/dev/terraform.tfvars.example envs/dev/terraform.tfvars; \
	fi
	cd envs/dev && terraform init -backend-config=backend.hcl
	@echo "Dev environment initialized"

init-stage:
	@echo "Initializing stage environment..."
	@if [ ! -f envs/stage/terraform.tfvars ]; then \
		cp envs/stage/terraform.tfvars.example envs/stage/terraform.tfvars; \
	fi
	cd envs/stage && terraform init -backend-config=backend.hcl
	@echo "Stage environment initialized"

init-prod:
	@echo "Initializing prod environment..."
	@if [ ! -f envs/prod/terraform.tfvars ]; then \
		cp envs/prod/terraform.tfvars.example envs/prod/terraform.tfvars; \
	fi
	cd envs/prod && terraform init -backend-config=backend.hcl
	@echo "Prod environment initialized"

# ============================================================================
# DEPLOYMENT - PLAN
# ============================================================================

plan-dev:
	@echo "Planning changes for dev environment..."
	cd envs/dev && terraform plan -out=tfplan
	@echo "Plan saved to envs/dev/tfplan"

plan-stage:
	@echo "Planning changes for stage environment..."
	cd envs/stage && terraform plan -out=tfplan
	@echo "Plan saved to envs/stage/tfplan"

plan-prod:
	@echo "Planning changes for prod environment..."
	@echo "WARNING: This is PRODUCTION environment"
	cd envs/prod && terraform plan -out=tfplan
	@echo "Plan saved to envs/prod/tfplan"

# ============================================================================
# DEPLOYMENT - APPLY
# ============================================================================

apply-dev:
	@echo "Applying changes to dev environment..."
	cd envs/dev && terraform apply tfplan
	@echo "Dev environment deployed"
	@$(MAKE) verify-deployment-dev

apply-stage:
	@echo "Applying changes to stage environment..."
	@echo "Deploying to STAGE environment"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd envs/stage && terraform apply tfplan; \
		echo "Stage environment deployed"; \
	else \
		echo "Deployment cancelled"; \
		exit 1; \
	fi

apply-prod:
	@echo "Applying changes to prod environment..."
	@echo "WARNING: PRODUCTION DEPLOYMENT"
	@echo "Current AWS Account: $$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'Unknown')"
	@read -p "Type 'deploy-prod' to confirm: " confirm; \
	if [ "$$confirm" = "deploy-prod" ]; then \
		cd envs/prod && terraform apply tfplan; \
		echo "Production environment deployed"; \
	else \
		echo "Deployment cancelled"; \
		exit 1; \
	fi

# ============================================================================
# DESTROY
# ============================================================================

destroy-dev:
	@echo "Destroying dev environment..."
	@echo "This will DELETE all resources in dev environment"
	@echo "Current AWS Account: $$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'Unknown')"
	@read -p "Type 'destroy-dev' to confirm: " confirm; \
	if [ "$$confirm" = "destroy-dev" ]; then \
		cd envs/dev && terraform destroy; \
		echo "Dev environment destroyed"; \
	else \
		echo "Destroy cancelled"; \
		exit 1; \
	fi

destroy-stage:
	@echo "Destroying stage environment..."
	@echo "This will DELETE all resources in stage environment"
	@echo "Current AWS Account: $$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'Unknown')"
	@read -p "Type 'destroy-stage' to confirm: " confirm; \
	if [ "$$confirm" = "destroy-stage" ]; then \
		cd envs/stage && terraform destroy; \
		echo "Stage environment destroyed"; \
	else \
		echo "Destroy cancelled"; \
		exit 1; \
	fi

destroy-prod:
	@echo "Destroying prod environment..."
	@echo "WARNING: PRODUCTION DESTROY"
	@echo "Current AWS Account: $$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'Unknown')"
	@read -p "Type 'destroy-prod' to confirm: " confirm; \
	if [ "$$confirm" = "destroy-prod" ]; then \
		cd envs/prod && terraform destroy; \
		echo "Production environment destroyed"; \
	else \
		echo "Destroy cancelled"; \
		exit 1; \
	fi

destroy-all:
	@echo "Complete Infrastructure Teardown"
	@echo "DANGER: This will destroy EVERYTHING"
	@echo "This includes:"
	@echo "  - All environments (prod, stage, dev)"
	@echo "  - GitHub OIDC configuration"
	@echo "  - Remote state infrastructure"
	@echo "  - All data in S3 buckets"
	@echo ""
	@echo "Current AWS Account: $$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'Unknown')"
	@echo ""
	@read -p "Type 'destroy-everything' to confirm: " confirm; \
	if [ "$$confirm" = "destroy-everything" ]; then \
		echo "Destroying prod..."; \
		cd envs/prod && terraform destroy -auto-approve || true; \
		cd ../..; \
		echo "Destroying stage..."; \
		cd envs/stage && terraform destroy -auto-approve || true; \
		cd ../..; \
		echo "Destroying dev..."; \
		cd envs/dev && terraform destroy -auto-approve || true; \
		cd ../..; \
		echo "Destroying OIDC..."; \
		cd global/iam_gh_oidc && terraform destroy -auto-approve || true; \
		cd ../..; \
		echo "Destroying remote state..."; \
		cd global/remote-state && terraform destroy -auto-approve || true; \
		echo "Complete teardown finished"; \
	else \
		echo "Teardown cancelled"; \
		exit 1; \
	fi

empty-buckets-dev:
	@echo "Emptying all S3 buckets in dev environment..."
	@echo "This will delete all data in dev buckets"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd envs/dev && \
		for bucket in $$(terraform output -json data_lake_buckets 2>/dev/null | jq -r '.[]' 2>/dev/null) $$(terraform output -raw log_bucket_name 2>/dev/null); do \
			echo "  Emptying $$bucket..."; \
			aws s3 rm s3://$$bucket --recursive --quiet 2>/dev/null || true; \
			aws s3api delete-objects --bucket $$bucket \
				--delete "$$(aws s3api list-object-versions --bucket $$bucket \
				--query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
				--max-items 1000 2>/dev/null)" 2>/dev/null || true; \
		done; \
		echo "Buckets emptied"; \
	fi

verify-destroy:
	@echo "Verifying resource cleanup..."
	@echo ""
	@echo "Checking S3 buckets:"
	@aws s3 ls 2>/dev/null | grep -E "(dp-dev|dp-stage|dp-prod|tf-state)" || echo "No lakehouse buckets found"
	@echo ""
	@echo "Checking DynamoDB tables:"
	@aws dynamodb list-tables 2>/dev/null | grep "tf-locks" || echo "No state lock table found"
	@echo ""
	@echo "Checking KMS keys (pending deletion):"
	@aws kms list-keys --query 'Keys[*].KeyId' --output text 2>/dev/null | while read key; do \
		aws kms describe-key --key-id $$key --query 'KeyMetadata.[KeyId,KeyState,Description]' --output text 2>/dev/null | grep -i "terraform\|lakehouse" || true; \
	done
	@echo ""
	@echo "Checking tagged resources:"
	@aws resourcegroupstaggingapi get-resources \
		--tag-filters Key=Project,Values=terraform-aws-lakehouse \
		--query 'ResourceTagMappingList[*].[ResourceARN]' \
		--output text 2>/dev/null || echo "No tagged resources found"

# ============================================================================
# VALIDATION & TESTING
# ============================================================================

fmt:
	@echo "Formatting Terraform files..."
	terraform fmt -recursive
	@echo "Files formatted"

validate:
	@echo "Validating Terraform configurations..."
	@for env in dev stage prod; do \
		echo "  Validating envs/$$env..."; \
		cd envs/$$env && terraform init -backend=false && terraform validate && cd ../..; \
	done
	@echo "All configurations valid"

lint:
	@echo "Running TFLint..."
	@for env in dev stage prod; do \
		echo "  Linting envs/$$env..."; \
		cd envs/$$env && tflint --config=../../.tflint.hcl && cd ../..; \
	done
	@echo "Linting complete"

security:
	@echo "Running security scans..."
	@echo "Running Trivy..."
	trivy config . --severity HIGH,CRITICAL || true
	@echo ""
	@echo "Running Checkov..."
	checkov -d . --config-file ci/policies/checkov_custom.yaml --compact || true
	@echo "Security scans complete"

check-dev: fmt validate
	@echo "Full validation for dev environment..."
	cd envs/dev && terraform init -backend-config=backend.hcl
	cd envs/dev && terraform validate
	cd envs/dev && terraform fmt -check
	@echo "Dev environment validation complete"

check-stage: fmt validate
	@echo "Full validation for stage environment..."
	cd envs/stage && terraform init -backend-config=backend.hcl
	cd envs/stage && terraform validate
	cd envs/stage && terraform fmt -check
	@echo "Stage environment validation complete"

check-prod: fmt validate
	@echo "Full validation for prod environment..."
	cd envs/prod && terraform init -backend-config=backend.hcl
	cd envs/prod && terraform validate
	cd envs/prod && terraform fmt -check
	@echo "Prod environment validation complete"

check-all: fmt validate lint security
	@echo "Complete validation passed"

verify-deployment-dev:
	@echo "Verifying dev deployment..."
	@cd envs/dev && \
	echo "Outputs:" && terraform output && \
	echo "" && \
	echo "Checking buckets:" && \
	aws s3 ls 2>/dev/null | grep dp-dev || echo "Warning: No dev buckets found" && \
	echo "" && \
	echo "Checking KMS key:" && \
	KMS_KEY_ID=$$(terraform output -raw kms_key_id 2>/dev/null) && \
	aws kms describe-key --key-id $$KMS_KEY_ID --query 'KeyMetadata.[KeyId,KeyState,Description]' --output table 2>/dev/null || true
	@echo "Verification complete"

# ============================================================================
# COST ANALYSIS
# ============================================================================

cost:
	@echo "Cost estimates for all environments..."
	@for env in dev stage prod; do \
		echo ""; \
		echo "Environment: $$env"; \
		echo "─────────────────────────────────────"; \
		infracost breakdown --path=envs/$$env 2>/dev/null || echo "Infracost not installed or configured"; \
	done
	@echo ""
	@echo "Cost analysis complete"

cost-dev:
	@echo "Cost estimate for dev environment..."
	infracost breakdown --path=envs/dev

cost-diff-dev:
	@echo "Cost diff for dev environment..."
	infracost diff --path=envs/dev

# ============================================================================
# TROUBLESHOOTING
# ============================================================================

import-kms-alias:
	@echo "Importing existing KMS alias into Terraform state..."
	@read -p "Enter environment (dev/stage/prod): " env; \
	cd envs/$$env && \
	terraform import aws_kms_alias.tf_state alias/terraform-state
	@echo "KMS alias imported"

fix-state-lock:
	@echo "Force unlocking Terraform state..."
	@echo "Use this only if previous run was interrupted"
	@read -p "Enter environment (dev/stage/prod): " env; \
	read -p "Enter Lock ID from error message: " lockid; \
	cd envs/$$env && terraform force-unlock $$lockid
	@echo "State unlocked"

state-list-dev:
	@echo "Listing all resources in dev state..."
	cd envs/dev && terraform state list

state-list-stage:
	@echo "Listing all resources in stage state..."
	cd envs/stage && terraform state list

state-list-prod:
	@echo "Listing all resources in prod state..."
	cd envs/prod && terraform state list

state-show-dev:
	@echo "Showing dev state..."
	@read -p "Enter resource name: " resource; \
	cd envs/dev && terraform state show $$resource

# ============================================================================
# DEVELOPMENT
# ============================================================================

pre-commit:
	@echo "Setting up pre-commit hooks..."
	pre-commit install
	pre-commit run --all-files
	@echo "Pre-commit hooks installed"

clean:
	@echo "Cleaning up Terraform cache files..."
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "tfplan" -delete 2>/dev/null || true
	find . -type f -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@echo "Cleanup complete"

clean-all: clean
	@echo "Deep cleaning (including state backups)..."
	find . -type f -name "terraform.tfstate.backup" -delete 2>/dev/null || true
	find . -type f -name "*.tfstate" ! -path "*/global/*" -delete 2>/dev/null || true
	@echo "Deep cleanup complete"

# ============================================================================
# UTILITY TARGETS
# ============================================================================

check-aws:
	@echo "Checking AWS configuration..."
	@echo "AWS Account: $$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'Not configured')"
	@echo "AWS User: $$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo 'Not configured')"
	@echo "AWS Region: $$(aws configure get region 2>/dev/null || echo 'Not configured')"

check-tools:
	@echo "Checking required tools..."
	@command -v terraform >/dev/null 2>&1 && echo "terraform: $$(terraform version | head -n1)" || echo "terraform: not installed"
	@command -v aws >/dev/null 2>&1 && echo "aws-cli: $$(aws --version)" || echo "aws-cli: not installed"
	@command -v tflint >/dev/null 2>&1 && echo "tflint: $$(tflint --version)" || echo "tflint: not installed"
	@command -v trivy >/dev/null 2>&1 && echo "trivy: $$(trivy --version | head -n1)" || echo "trivy: not installed"
	@command -v checkov >/dev/null 2>&1 && echo "checkov: $$(checkov --version)" || echo "checkov: not installed"
	@command -v infracost >/dev/null 2>&1 && echo "infracost: $$(infracost --version)" || echo "infracost: not installed"
	@command -v pre-commit >/dev/null 2>&1 && echo "pre-commit: $$(pre-commit --version)" || echo "pre-commit: not installed"
	@command -v jq >/dev/null 2>&1 && echo "jq: $$(jq --version)" || echo "jq: not installed"

# Quick setup target for new developers
setup: check-tools
	@echo "Setting up development environment..."
	@$(MAKE) pre-commit
	@echo ""
	@echo "Setup complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Configure AWS credentials: aws configure"
	@echo "  2. Bootstrap remote state: make init-remote-state"
	@echo "  3. Initialize dev environment: make init-dev"
	@echo "  4. Plan changes: make plan-dev"
	@echo "  5. Apply changes: make apply-dev"
