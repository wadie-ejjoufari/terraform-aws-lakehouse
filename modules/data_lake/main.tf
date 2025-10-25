terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

locals {
  tiers = toset(["raw", "silver", "gold"])
}

resource "aws_s3_bucket" "dl" {
  for_each      = local.tiers
  bucket        = "${var.name_prefix}-${each.key}"
  force_destroy = false
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "v" {
  for_each = aws_s3_bucket.dl
  bucket   = each.value.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  for_each = aws_s3_bucket.dl
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pab" {
  for_each                = aws_s3_bucket.dl
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Access logging to central log bucket
resource "aws_s3_bucket_logging" "log" {
  for_each      = aws_s3_bucket.dl
  bucket        = each.value.id
  target_bucket = var.log_bucket
  target_prefix = "${each.key}/"
}

# Lifecycle: IA after N days, Glacier after M, expire after X
resource "aws_s3_bucket_lifecycle_configuration" "lc" {
  for_each = aws_s3_bucket.dl
  bucket   = each.value.id
  rule {
    id     = "tiering"
    status = "Enabled"
    filter {}
    transition {
      days          = var.tier_ia_days
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = var.tier_glacier_days
      storage_class = "GLACIER"
    }
    expiration {
      days = var.expiration_days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Bucket policy: enforce TLS only
resource "aws_s3_bucket_policy" "policy" {
  for_each = aws_s3_bucket.dl
  bucket   = each.value.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "DenyInsecureTransport",
      Effect    = "Deny",
      Principal = "*",
      Action    = "s3:*",
      Resource = [
        each.value.arn,
        "${each.value.arn}/*"
      ],
      Condition = {
        Bool = {
          "aws:SecureTransport" = "false"
        }
      }
    }]
  })
}
