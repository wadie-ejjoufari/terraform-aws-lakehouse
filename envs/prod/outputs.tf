output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "region_name" {
  description = "AWS region"
  value       = local.region
}

output "common_tags" {
  description = "Common tags for resources"
  value       = local.common_tags
}

output "data_bucket_prefix" {
  description = "Prefix for data lake buckets"
  value       = var.data_bucket_prefix
}

output "enable_glue_catalog" {
  description = "Flag for Glue Catalog"
  value       = var.enable_glue_catalog
}

output "enable_athena" {
  description = "Flag for Athena"
  value       = var.enable_athena
}

output "account_id_local" {
  description = "AWS account id (used to silence tflint unused-local)"
  value       = local.account_id
}

output "kms_key_arn" {
  description = "ARN of the shared environment KMS key"
  value       = aws_kms_key.s3.arn
}

output "kms_key_id" {
  description = "ID of the shared environment KMS key"
  value       = aws_kms_key.s3.key_id
}

output "kms_key_alias" {
  description = "Alias of the shared environment KMS key"
  value       = aws_kms_alias.s3.name
}

output "data_lake_buckets" {
  description = "Map of data lake bucket names by tier"
  value       = module.data_lake.bucket_names
}

output "log_bucket_name" {
  description = "Name of the centralized logging bucket"
  value       = module.logs.log_bucket_name
}
