# Operational Runbook

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Deployment Procedures](#deployment-procedures)
3. [Validation & Testing](#validation--testing)
4. [Troubleshooting](#troubleshooting)
5. [Maintenance Tasks](#maintenance-tasks)
6. [Destroy Procedures](#destroy-procedures)
7. [Rollback Procedures](#rollback-procedures)
8. [Monitoring & Alerts](#monitoring--alerts)

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

# Destroy environment (DANGER - see Destroy Procedures section)
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

## Destroy Procedures

### WARNING: Destructive Operations

Destroying infrastructure will **permanently delete all data** in S3 buckets and remove all resources. This action cannot be undone. Always:

- Backup critical data before destroying
- Verify you're in the correct AWS account
- Double-check the environment (dev/stage/prod)
- Get approval for non-dev environments

### Pre-Destroy Checklist

```bash
# 1. Verify AWS account
aws sts get-caller-identity

# 2. Verify environment
pwd  # Should show correct env path

# 3. List resources that will be destroyed
terraform state list

# 4. Review what will be destroyed
terraform plan -destroy
```

### Destroying Environments (Safe Order)

#### Step 1: Export/Backup Data (Optional but Recommended)

```bash
cd envs/dev

# List all data lake buckets
BUCKETS=$(terraform output -json data_lake_buckets | jq -r '.[]')

# Backup important data
for BUCKET in $BUCKETS; do
  echo "Backing up $BUCKET..."
  aws s3 sync s3://$BUCKET ./backups/$BUCKET/ --only-show-errors
done

# Backup logs
LOG_BUCKET=$(terraform output -raw log_bucket_name)
aws s3 sync s3://$LOG_BUCKET ./backups/$LOG_BUCKET/ --only-show-errors
```

#### Step 2: Destroy a Single Environment

```bash
cd envs/dev  # or stage/prod

# Review destruction plan
terraform plan -destroy

# Destroy with confirmation prompt
terraform destroy

# If buckets have objects and force_destroy=false, you may need to empty them first:
# See "Force Empty Buckets" section below
```

#### Step 3: Destroy All Environments

```bash
# Destroy in order: prod → stage → dev
cd envs/prod
terraform destroy -auto-approve  # Use -auto-approve only if certain

cd ../stage
terraform destroy -auto-approve

cd ../dev
terraform destroy -auto-approve
```

#### Step 4: Destroy Global Resources

```bash
# Destroy GitHub OIDC (if no longer needed)
cd global/iam_gh_oidc
terraform destroy

# ⚠️ LAST STEP: Destroy remote state (WARNING: No more Terraform management after this!)
cd ../remote-state
terraform destroy

# This will delete:
# - Terraform state S3 bucket
# - State logs S3 bucket
# - DynamoDB lock table
# - KMS key (scheduled for deletion after 10 days)
```

### Force Empty Buckets (If Needed)

If `force_destroy = false` in bucket configuration, you must manually empty buckets:

```bash
cd envs/dev

# Get bucket names
RAW_BUCKET=$(terraform output -json data_lake_buckets | jq -r '.raw')
SILVER_BUCKET=$(terraform output -json data_lake_buckets | jq -r '.silver')
GOLD_BUCKET=$(terraform output -json data_lake_buckets | jq -r '.gold')
LOG_BUCKET=$(terraform output -raw log_bucket_name)

# Empty each bucket (this deletes all objects and versions)
aws s3 rm s3://$RAW_BUCKET --recursive
aws s3api delete-objects \
  --bucket $RAW_BUCKET \
  --delete "$(aws s3api list-object-versions \
    --bucket $RAW_BUCKET \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --max-items 1000)"

aws s3 rm s3://$SILVER_BUCKET --recursive
aws s3api delete-objects \
  --bucket $SILVER_BUCKET \
  --delete "$(aws s3api list-object-versions \
    --bucket $SILVER_BUCKET \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --max-items 1000)"

aws s3 rm s3://$GOLD_BUCKET --recursive
aws s3api delete-objects \
  --bucket $GOLD_BUCKET \
  --delete "$(aws s3api list-object-versions \
    --bucket $GOLD_BUCKET \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --max-items 1000)"

aws s3 rm s3://$LOG_BUCKET --recursive
aws s3api delete-objects \
  --bucket $LOG_BUCKET \
  --delete "$(aws s3api list-object-versions \
    --bucket $LOG_BUCKET \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --max-items 1000)"

# Now retry destroy
terraform destroy
```

### Quick Destroy Script (Use with Caution)

Create a helper script for development environments:

```bash
cat > destroy-dev.sh << 'EOF'
#!/bin/bash
set -e

echo "WARNING: This will destroy the DEV environment"
echo "Current AWS Account: $(aws sts get-caller-identity --query Account --output text)"
read -p "Type 'destroy-dev' to confirm: " confirm

if [ "$confirm" != "destroy-dev" ]; then
  echo "Aborted."
  exit 1
fi

cd envs/dev

echo "Emptying S3 buckets..."
for bucket in $(terraform output -json data_lake_buckets | jq -r '.[]') $(terraform output -raw log_bucket_name); do
  echo "  Emptying $bucket..."
  aws s3 rm s3://$bucket --recursive --quiet || true
  # Delete all versions
  aws s3api delete-objects \
    --bucket $bucket \
    --delete "$(aws s3api list-object-versions \
      --bucket $bucket \
      --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
      --max-items 1000 2>/dev/null)" \
    2>/dev/null || true
done

echo "Destroying Terraform resources..."
terraform destroy -auto-approve

echo "Dev environment destroyed"
EOF

chmod +x destroy-dev.sh
```

Usage:

```bash
./destroy-dev.sh
```

### Destroying Specific Resources

Target specific resources for deletion:

```bash
cd envs/dev

# Destroy only data lake buckets
terraform destroy -target=module.data_lake

# Destroy only observability resources
terraform destroy -target=module.observability

# Destroy specific bucket
terraform destroy -target=module.data_lake.aws_s3_bucket.dl[\"raw\"]

# View what will be affected
terraform plan -destroy -target=module.data_lake
```

### Handling Destroy Failures

#### Issue: KMS Key Pending Deletion

**Symptom:**

```
Error: KMS key is pending deletion and cannot be used
```

**Solution:**

```bash
# Cancel key deletion
KMS_KEY_ID=$(terraform state show module.data_lake.aws_kms_key.s3 | grep "id " | awk '{print $3}' | tr -d '"')
aws kms cancel-key-deletion --key-id $KMS_KEY_ID

# Retry destroy
terraform destroy
```

#### Issue: Bucket Not Empty

**Symptom:**

```
Error: error deleting S3 Bucket: BucketNotEmpty
```

**Solution:**
See "Force Empty Buckets" section above.

#### Issue: State Lock During Destroy

**Symptom:**

```
Error: Error acquiring the state lock
```

**Solution:**

```bash
# Force unlock
terraform force-unlock <LOCK_ID>

# Retry destroy
terraform destroy
```

#### Issue: Dependency Violations

**Symptom:**

```
Error: deleting KMS Key: key is in use by other resources
```

**Solution:**

```bash
# Find dependent resources
KMS_KEY_ID="your-key-id"
aws kms list-grants --key-id $KMS_KEY_ID

# Delete resources using the key first
terraform destroy -target=module.data_lake.aws_s3_bucket_server_side_encryption_configuration.sse

# Then destroy KMS key
terraform destroy -target=module.data_lake.aws_kms_key.s3
```

### Post-Destroy Verification

```bash
# Verify buckets are deleted
aws s3 ls | grep dp-dev

# Verify KMS keys are scheduled for deletion
aws kms list-keys --query 'Keys[*].KeyId' --output text | while read key; do
  aws kms describe-key --key-id $key --query 'KeyMetadata.[KeyId,KeyState]' --output text
done | grep "PendingDeletion"

# Verify DynamoDB tables are deleted
aws dynamodb list-tables | grep tf-locks

# Check for any remaining resources with tags
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=terraform-aws-lakehouse \
  --query 'ResourceTagMappingList[*].[ResourceARN]' \
  --output text
```

### Complete Teardown (Nuclear Option)

For complete cleanup of everything including remote state:

```bash
#!/bin/bash
# complete-teardown.sh - Use only for complete project removal

set -e

echo " ~~~ COMPLETE TEARDOWN ~~~ "
echo "This will destroy ALL infrastructure including remote state"
echo "This action is IRREVERSIBLE"
echo ""
echo "Current AWS Account: $(aws sts get-caller-identity --query Account --output text)"
echo ""
read -p "Type 'destroy-everything' to confirm: " confirm

if [ "$confirm" != "destroy-everything" ]; then
  echo "Aborted."
  exit 1
fi

# Destroy environments in order
for env in prod stage dev; do
  echo "Destroying $env environment..."
  cd envs/$env

  # Empty buckets
  terraform output -json 2>/dev/null | jq -r '.. | select(type == "string" and startswith("arn:aws:s3:::"))' | \
    sed 's/arn:aws:s3::://g' | while read bucket; do
    echo "  Emptying $bucket..."
    aws s3 rm s3://$bucket --recursive --quiet 2>/dev/null || true
  done

  terraform destroy -auto-approve || echo "Failed to destroy $env (continuing...)"
  cd ../..
done

# Destroy global resources
echo "Destroying GitHub OIDC..."
cd global/iam_gh_oidc
terraform destroy -auto-approve || echo "Failed to destroy OIDC (continuing...)"

echo "Destroying remote state infrastructure..."
cd ../remote-state

# Empty state buckets
STATE_BUCKET="tf-state-$(aws sts get-caller-identity --query Account --output text)-eu-west-3"
LOGS_BUCKET="tf-state-logs-$(aws sts get-caller-identity --query Account --output text)-eu-west-3"

echo "  Emptying $STATE_BUCKET..."
aws s3 rm s3://$STATE_BUCKET --recursive --quiet 2>/dev/null || true
echo "  Emptying $LOGS_BUCKET..."
aws s3 rm s3://$LOGS_BUCKET --recursive --quiet 2>/dev/null || true

terraform destroy -auto-approve || echo "Failed to destroy remote state (continuing...)"

cd ../..

echo ""
echo "Teardown complete"
echo ""
echo "Note: KMS keys are scheduled for deletion (10-day waiting period)"
echo "To immediately delete (cannot be undone):"
echo "  aws kms schedule-key-deletion --key-id <KEY_ID> --pending-window-in-days 7"
```

### Recovery After Accidental Destroy

If you accidentally destroyed resources:

```bash
# 1. Check S3 bucket versioning (if versioning was enabled)
aws s3api list-object-versions --bucket <bucket-name>

# 2. Restore from Terraform state backup
cd envs/dev
# State is versioned in S3 - see "Restoring from State Backup" section

# 3. Re-deploy infrastructure
terraform init -backend-config=backend.hcl
terraform apply

# 4. Restore data from backups (if you made backups)
aws s3 sync ./backups/<bucket-name>/ s3://<bucket-name>/
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

| Role               | Contact Method | Use Case                |
| ------------------ | -------------- | ----------------------- |
| Platform Team Lead | [Email/Slack]  | Infrastructure issues   |
| Security Team      | [Email/Slack]  | Security incidents      |
| AWS Support        | Support Case   | AWS service issues      |
| On-Call Engineer   | PagerDuty      | After-hours emergencies |

---

## Change Log

| Date       | Change                                     | Author |
| ---------- | ------------------------------------------ | ------ |
| 2025-11-02 | Initial runbook creation                   | System |
| 2025-11-02 | Added KMS key consolidation procedures     | System |
| 2025-11-02 | Added validation and troubleshooting steps | System |

---

## Additional Resources

- [Architecture Documentation](architecture.md)
- [Architectural Decision Records](decisions.md)
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/best-practices.html)
- [KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
