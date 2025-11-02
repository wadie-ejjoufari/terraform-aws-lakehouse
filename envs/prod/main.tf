data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

locals {
  tags = {
    Project    = "DataPlatform"
    Env        = "prod"
    Owner      = "wadie"
    CostCenter = "DE"
  }
}

# KMS key policy document for S3 bucket encryption
data "aws_iam_policy_document" "s3_kms" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow S3 to use the key"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = ["*"]
  }
}

# Shared KMS key for all S3 buckets in this environment
resource "aws_kms_key" "s3" {
  description             = "Shared KMS key for prod environment S3 buckets"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.s3_kms.json
  tags                    = local.tags
}

resource "aws_kms_alias" "s3" {
  name          = "alias/dp-prod-s3"
  target_key_id = aws_kms_key.s3.key_id
}

module "logs" {
  source      = "../../modules/observability"
  name_prefix = "dp-prod-${local.account_id}"
  kms_key_id  = aws_kms_key.s3.arn
  tags        = local.tags
}

module "data_lake" {
  source            = "../../modules/data_lake"
  name_prefix       = "dp-prod-${local.account_id}"
  log_bucket        = module.logs.log_bucket_name
  kms_key_id        = aws_kms_key.s3.arn
  tags              = local.tags
  tier_ia_days      = 30
  tier_glacier_days = 180
  expiration_days   = 730
}
