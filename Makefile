.PHONY: help init-remote-state fmt validate lint cost

help:
    @echo "Available targets:"
    @echo "  init-remote-state  - Bootstrap S3 backend"
    @echo "  fmt                - Format all Terraform files"
    @echo "  validate           - Validate Terraform configurations"
    @echo "  lint               - Run TFLint on all environments"
    @echo "  cost               - Run Infracost on all environments"
    @echo "  pre-commit         - Install and run pre-commit hooks"

init-remote-state:
    cd global/remote-state && terraform init && terraform plan

fmt:
    terraform fmt -recursive

validate:
    @for env in dev stage prod; do \
        echo "Validating envs/$$env..."; \
        cd envs/$$env && terraform init -backend=false && terraform validate && cd ../..; \
    done

lint:
    @for env in dev stage prod; do \
        echo "Linting envs/$$env..."; \
        cd envs/$$env && tflint --config=../../.tflint.hcl && cd ../..; \
    done

cost:
    @for env in dev stage prod; do \
        echo "Cost estimate for envs/$$env..."; \
        infracost breakdown --path=envs/$$env; \
    done

pre-commit:
    pre-commit install
    pre-commit run --all-files
