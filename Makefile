# Terraform AWS Lakehouse - Modular Makefile
# Common operations for infrastructure management
#
# This Makefile is organized into separate modules for better maintainability:
#   - Makefile.setup     : Initialization and bootstrap operations
#   - Makefile.deploy    : Plan and apply deployments
#   - Makefile.destroy   : Destroy and cleanup operations
#   - Makefile.validate  : Formatting, validation, and security checks
#   - Makefile.utils     : Troubleshooting and utility commands
#   - Makefile.dev       : Cost analysis and development tools

SHELL := /bin/bash

# Default environment variable
ENV ?= dev

# ============================================================================
# HELP
# ============================================================================

.PHONY: help

help:
	@echo "╔════════════════════════════════════════════════════════════════╗"
	@echo "║        Terraform AWS Lakehouse - Available Commands            ║"
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
	@echo "  make empty-buckets-stage  - Force empty all stage S3 buckets"
	@echo "  make empty-buckets-prod   - Force empty all prod S3 buckets"
	@echo "  make empty-buckets-all    - Force empty all S3 buckets in all environments"
	@echo "  make empty-state-bucket   - Force empty Terraform state bucket"
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
	@echo "  make check-tools          - Check required tool installations"
	@echo ""
	@echo "Examples:"
	@echo "  make init-remote-state    # First time setup"
	@echo "  make plan-dev             # Review changes"
	@echo "  make apply-dev            # Deploy to dev"
	@echo "  make check-dev            # Validate deployment"
	@echo ""
	@echo "For detailed documentation, see:"
	@echo "  - docs/runbook.md         # Operational procedures"
	@echo "  - docs/architecture.md    # System architecture"
	@echo "  - docs/decisions.md       # Architecture decisions"
	@echo ""

# ============================================================================
# INCLUDE MODULES
# ============================================================================

include Makefile.setup
include Makefile.deploy
include Makefile.destroy
include Makefile.validate
include Makefile.utils
include Makefile.dev
