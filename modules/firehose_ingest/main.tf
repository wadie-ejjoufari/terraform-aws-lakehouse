terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  kms_arn_provided = var.kms_key_arn != "" && var.kms_key_arn != null

  s3_statement = {
    Effect = "Allow"
    Action = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
    ]
    Resource = [
      "arn:aws:s3:::${var.bucket_name}",
      "arn:aws:s3:::${var.bucket_name}/*",
    ]
  }

  kms_statement = local.kms_arn_provided ? {
    Effect   = "Allow"
    Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    Resource = var.kms_key_arn
  } : null

  iam_statements = concat(
    [local.s3_statement],
    local.kms_arn_provided ? [local.kms_statement] : []
  )

  iam_policy = {
    Version   = "2012-10-17"
    Statement = local.iam_statements
  }
}

resource "aws_iam_role_policy" "firehose_policy" {
  role   = aws_iam_role.firehose.id
  policy = jsonencode(local.iam_policy)
}

resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = "${var.name_prefix}-github-events"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose.arn
    bucket_arn         = "arn:aws:s3:::${var.bucket_name}"
    buffering_size     = var.buffering_mb
    buffering_interval = var.buffering_seconds
    compression_format = "GZIP"
    kms_key_arn        = local.kms_arn_provided ? var.kms_key_arn : null

    prefix              = "github/events/ingest_dt=!{timestamp:yyyy-MM-dd}/"
    error_output_prefix = "github/errors/!{firehose:error-output-type}/!{timestamp:yyyy/MM/dd}/"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/${var.name_prefix}-github-events"
      log_stream_name = "s3"
    }
  }
  tags = var.tags
}

# IAM role for Firehose to write to S3 and use KMS
resource "aws_iam_role" "firehose" {
  name = "${var.name_prefix}-firehose-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "firehose.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
