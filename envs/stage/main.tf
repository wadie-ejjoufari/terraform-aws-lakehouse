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
    Env        = "stage"
    Owner      = "wadie"
    CostCenter = "DE"
  }
}

module "logs" {
  source      = "../../modules/observability"
  name_prefix = "dp-stage-${local.account_id}"
  tags        = local.tags
}

# KMS key for S3 bucket encryption
resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  tags                    = local.tags
}

resource "aws_kms_alias" "s3" {
  name          = "alias/dp-stage-s3"
  target_key_id = aws_kms_key.s3.key_id
}

module "data_lake" {
  source            = "../../modules/data_lake"
  name_prefix       = "dp-stage-${local.account_id}"
  log_bucket        = module.logs.log_bucket_name
  kms_key_id        = aws_kms_key.s3.arn
  tags              = local.tags
  tier_ia_days      = 30
  tier_glacier_days = 180
  expiration_days   = 730
}
