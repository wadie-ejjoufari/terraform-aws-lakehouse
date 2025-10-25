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

module "logs" {
  source      = "../../modules/observability"
  name_prefix = "dp-prod-${local.account_id}"
  tags        = local.tags
}

# KMS key for S3 bucket encryption
resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  tags                    = local.tags

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use the key",
        Effect = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "s3" {
  name          = "alias/dp-prod-s3"
  target_key_id = aws_kms_key.s3.key_id
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
