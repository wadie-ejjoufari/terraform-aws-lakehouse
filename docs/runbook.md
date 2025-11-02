# Operational Runbook

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Deployment Procedures](#deployment-procedures)
3. [Validation & Testing](#validation--testing)
4. [Troubleshooting](#troubleshooting)
5. [Maintenance Tasks](#maintenance-tasks)
6. [Rollback Procedures](#rollback-procedures)
7. [Monitoring & Alerts](#monitoring--alerts)

---

## Quick Reference

### Key Commands

```bash
# Format code
terraform fmt -recursive

# Validate configuration
cd envs/{env} && terraform validate

# Plan changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan

# View outputs
terraform output

# Destroy environment (DANGER)
terraform destroy
```

### Important ARNs & Resources

```bash
# View KMS key ARN
cd envs/dev && terraform output kms_key_arn

# View all bucket names
terraform output data_lake_buckets

# View log bucket
terraform output log_bucket_name
```

---

## Deployment Procedures

### Initial Setup (First Time Only)

#### Step 1: Bootstrap Remote State

```bash
# Navigate to remote state directory
cd global/remote-state

# Copy and configure tfvars
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values:
# - account_id = "your-aws-account-id"
# - region = "eu-west-3"
vim terraform.tfvars

# Initialize and apply
terraform init
terraform plan
terraform apply

# Note the outputs - you'll need these values
terraform output
```

**Expected Outputs:**
- `state_bucket_name`: S3 bucket for Terraform state
- `dynamodb_table_name`: DynamoDB table for state locking
- `kms_key_id`: KMS key ID for state encryption

#### Step 2: Setup GitHub OIDC (Optional - for CI/CD)

```bash
cd global/iam_gh_oidc

terraform init
terraform apply \
  -var "region=eu-west-3" \
  -var "repo=your-github-org/your-repo-name" \
  -var "role_name=gh-actions-plan-dev"

# Add the role ARN to GitHub repository secrets as AWS_OIDC_ROLE_ARN
terraform output role_arn
```

#### Step 3: Configure Environment Backend

```bash
# Update backend configuration for each environment
cd envs/dev

# Edit backend.hcl with your account ID
vim backend.hcl
# bucket = "tf-state-YOUR_ACCOUNT_ID-eu-west-3"
```

### Deploying an Environment

#### Deploy Dev Environment

```bash
cd envs/dev

# Copy example tfvars
cp terraform.tfvars.example terraform.tfvars

# Edit configuration (optional - defaults are sensible)
vim terraform.tfvars

# Initialize with backend
terraform init -backend-config=backend.hcl

# Plan and review changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan

# Verify deployment
terraform output
```

#### Deploy Stage/Prod Environments

```bash
# Replace 'stage' with 'prod' as needed
cd envs/stage

cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

---

## Validation & Testing

### Pre-Deployment Validation

```bash
# 1. Format check
terraform fmt -recursive -check

# 2. Validate all configurations
cd envs/dev && terraform validate
cd ../stage && terraform validate
cd ../prod && terraform validate

# 3. Run pre-commit hooks
cd ../..
pre-commit run --all-files

# 4. Security scan with Trivy
trivy config .

# 5. Policy check with Checkov
checkov -d . --config-file ci/policies/checkov_custom.yaml

# 6. Linting with TFLint
cd envs/dev
tflint --config=../../.tflint.hcl
```

### Post-Deployment Validation

```bash
cd envs/dev

# 1. Verify outputs are present
terraform output

# Expected outputs:
# - kms_key_arn
# - kms_key_id
# - kms_key_alias
# - data_lake_buckets (raw, silver, gold)
# - log_bucket_name

# 2. Verify S3 buckets exist
aws s3 ls | grep dp-dev

# 3. Verify KMS key exists and rotation is enabled
KMS_KEY_ID=$(terraform output -raw kms_key_id)
aws kms describe-key --key-id $KMS_KEY_ID
aws kms get-key-rotation-status --key-id $KMS_KEY_ID

# 4. Verify bucket encryption
BUCKET_NAME=$(terraform output -json data_lake_buckets | jq -r '.raw')
aws s3api get-bucket-encryption --bucket $BUCKET_NAME

# 5. Verify versioning is enabled
aws s3api get-bucket-versioning --bucket $BUCKET_NAME

# 6. Verify public access is blocked
aws s3api get-public-access-block --bucket $BUCKET_NAME

# 7. Test bucket policy (TLS enforcement)
# This should fail (403) without TLS
aws s3api head-object --bucket $BUCKET_NAME --key test.txt --no-verify-ssl || echo "✓ TLS enforcement working"
```

### Integration Testing

```bash
# Test write to raw bucket
BUCKET_NAME=$(cd envs/dev && terraform output -json data_lake_buckets | jq -r '.raw')
echo "test data" > test.txt
aws s3 cp test.txt s3://$BUCKET_NAME/test/test.txt
aws s3 rm s3://$BUCKET_NAME/test/test.txt
rm test.txt

# Verify access logs are being written
LOG_BUCKET=$(cd envs/dev && terraform output -raw log_bucket_name)
aws s3 ls s3://$LOG_BUCKET/raw/ | head -5
```

---

## Troubleshooting

### Common Issues

#### Issue 1: KMS Permission Denied

**Symptom:**
```
Error: AccessDeniedException: User is not authorized to perform: kms:Decrypt
```

**Cause:** IAM user/role lacks KMS permissions

**Solution:**
```bash
# Check your IAM identity
aws sts get-caller-identity

# Verify KMS key policy allows your user/role
cd envs/dev
KMS_KEY_ID=$(terraform output -raw kms_key_id)
aws kms get-key-policy --key-id $KMS_KEY_ID --policy-name default

# For CI/CD: Ensure GitHub OIDC role has kms:Decrypt and kms:Encrypt permissions
cd ../../global/iam_gh_oidc
terraform apply  # This will update permissions
```

#### Issue 2: State Lock Conflict

**Symptom:**
```
Error: Error acquiring the state lock
```

**Cause:** Previous Terraform run didn't release lock (crash/interrupt)

**Solution:**
```bash
# List locks
aws dynamodb scan --table-name tf-locks

# Force unlock (use lock ID from error message)
terraform force-unlock <LOCK_ID>

# If stuck, manually delete from DynamoDB (LAST RESORT)
aws dynamodb delete-item \
  --table-name tf-locks \
  --key '{"LockID": {"S": "tf-state-ACCOUNT_ID/envs/dev/terraform.tfstate"}}'
```

#### Issue 3: Module Not Found

**Symptom:**
```
Error: Module not installed
```

**Cause:** Terraform modules not initialized

**Solution:**
```bash
cd envs/dev
rm -rf .terraform
terraform init -backend-config=backend.hcl
```

#### Issue 4: Backend Configuration Error

**Symptom:**
```
Error: Failed to get existing workspaces: NoSuchBucket
```

**Cause:** Remote state bucket doesn't exist or backend config incorrect

**Solution:**
```bash
# Verify state bucket exists
aws s3 ls | grep tf-state

# If missing, deploy remote state first
cd global/remote-state
terraform apply

# Verify backend.hcl has correct bucket name
cd ../../envs/dev
cat backend.hcl

# Re-initialize
terraform init -backend-config=backend.hcl -reconfigure
```

#### Issue 5: Observability Module Missing KMS Variable

**Symptom:**
```
Error: No declaration found for "var.kms_key_id"
```

**Cause:** Module update didn't propagate

**Solution:**
```bash
# Re-initialize modules
cd envs/dev
terraform get -update
terraform init -upgrade
```

---

## Maintenance Tasks

### Rotating KMS Keys

KMS keys have automatic rotation enabled, but you can manually rotate:

```bash
cd envs/dev
KMS_KEY_ID=$(terraform output -raw kms_key_id)

# Check current rotation status
aws kms get-key-rotation-status --key-id $KMS_KEY_ID

# Enable rotation (already enabled in code)
aws kms enable-key-rotation --key-id $KMS_KEY_ID

# Check key age
aws kms describe-key --key-id $KMS_KEY_ID --query 'KeyMetadata.CreationDate'
```

### Updating Lifecycle Policies

```bash
cd envs/dev

# Edit main.tf to change lifecycle days
vim main.tf
# Update tier_ia_days, tier_glacier_days, or expiration_days

# Plan and apply
terraform plan -out=tfplan
terraform apply tfplan
```

### Cleaning Up Old Bucket Versions

```bash
# List versions (for debugging)
BUCKET_NAME=$(cd envs/dev && terraform output -json data_lake_buckets | jq -r '.raw')
aws s3api list-object-versions --bucket $BUCKET_NAME --max-items 10

# Lifecycle rules automatically handle cleanup
# Check lifecycle configuration
aws s3api get-bucket-lifecycle-configuration --bucket $BUCKET_NAME
```

### Updating Terraform Version

```bash
# Update required_version in terraform blocks
find . -name "*.tf" -exec grep -l "required_version" {} \;

# Update all files
vim modules/*/main.tf
vim envs/*/main.tf

# Re-initialize
cd envs/dev
terraform init -upgrade

# Verify
terraform version
```

### Updating Provider Versions

```bash
# Update required_providers in terraform blocks
vim modules/data_lake/main.tf
# Change version = ">= 4.0" to version = ">= 5.0"

# Update lock file
cd envs/dev
terraform init -upgrade

# Verify
terraform version
terraform providers
```

---

## Rollback Procedures

### Rolling Back a Failed Apply

```bash
# If terraform apply fails mid-execution:

# 1. Check state
cd envs/dev
terraform show

# 2. Refresh state to sync with AWS
terraform refresh

# 3. Revert code changes
git log --oneline -5
git checkout <previous-commit>

# 4. Plan to see removal
terraform plan

# 5. Apply rollback (only if safe)
terraform apply

# 6. Alternative: Manually fix in AWS Console if Terraform state corrupted
```

### Restoring from State Backup

```bash
# State is versioned in S3 - list versions
BUCKET_NAME="tf-state-$(aws sts get-caller-identity --query Account --output text)-eu-west-3"
aws s3api list-object-versions \
  --bucket $BUCKET_NAME \
  --prefix envs/dev/terraform.tfstate \
  --max-items 10

# Download previous version
aws s3api get-object \
  --bucket $BUCKET_NAME \
  --key envs/dev/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.backup

# Review backup
cat terraform.tfstate.backup | jq .

# If needed, copy backup to current
aws s3 cp terraform.tfstate.backup s3://$BUCKET_NAME/envs/dev/terraform.tfstate
```

### Emergency Bucket Restore

```bash
# If bucket deleted accidentally and versioning was enabled:

# 1. Check if bucket still exists in S3
aws s3 ls | grep dp-dev

# 2. If deleted, recreate using Terraform
cd envs/dev
terraform apply -target=module.data_lake.aws_s3_bucket.dl

# 3. Restore objects from backup/cross-region replication
# (Assumes you have backups - implement separately)
```

---

## Monitoring & Alerts

### Key Metrics to Monitor

1. **S3 Bucket Metrics:**
   - Number of objects
   - Total size
   - Request rates (GET/PUT)
   - 4xx/5xx errors

2. **KMS Metrics:**
   - API request count
   - Throttled requests
   - Key state (Enabled)

3. **Cost Metrics:**
   - S3 storage costs by tier
   - KMS API request costs
   - Data transfer costs

### CloudWatch Dashboards (To Implement)

```bash
# Create CloudWatch dashboard for environment
aws cloudwatch put-dashboard \
  --dashboard-name "DataLake-Dev" \
  --dashboard-body file://dashboard-config.json
```

### Setting Up CloudWatch Alarms (To Implement)

```terraform
# Add to modules/observability/main.tf:
resource "aws_cloudwatch_metric_alarm" "bucket_4xx_errors" {
  alarm_name          = "${var.name_prefix}-bucket-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4xxErrors"
  namespace           = "AWS/S3"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "Alert when S3 bucket has >100 4xx errors"
  treat_missing_data  = "notBreaching"
}
```

### Cost Monitoring

```bash
# View current month costs by service
aws ce get-cost-and-usage \
  --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE

# Use infracost for pre-deployment estimates
cd envs/dev
infracost breakdown --path=.
```

---

## Emergency Contacts & Escalation

| Role                 | Contact Method | Use Case                     |
| -------------------- | -------------- | ---------------------------- |
| Platform Team Lead   | [Email/Slack]  | Infrastructure issues        |
| Security Team        | [Email/Slack]  | Security incidents           |
| AWS Support          | Support Case   | AWS service issues           |
| On-Call Engineer     | PagerDuty      | After-hours emergencies      |

---

## Change Log

| Date       | Change                                      | Author |
| ---------- | ------------------------------------------- | ------ |
| 2025-11-02 | Initial runbook creation                    | System |
| 2025-11-02 | Added KMS key consolidation procedures     | System |
| 2025-11-02 | Added validation and troubleshooting steps | System |

---

## Additional Resources

- [Architecture Documentation](architecture.md)
- [Architectural Decision Records](decisions.md)
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/best-practices.html)
- [KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
