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
