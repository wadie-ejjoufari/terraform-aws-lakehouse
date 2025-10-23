variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "lakehouse"
}

# Lakehouse-specific variables
variable "data_bucket_prefix" {
  description = "Prefix for data lake buckets"
  type        = string
  default     = "datalake"
}

variable "enable_glue_catalog" {
  description = "Enable AWS Glue Data Catalog"
  type        = bool
  default     = true
}

variable "enable_athena" {
  description = "Enable Amazon Athena"
  type        = bool
  default     = true
}