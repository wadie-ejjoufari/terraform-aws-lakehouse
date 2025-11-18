variable "name_prefix" {
  description = "Prefix for naming resources, e.g., 'dp-dev'"
  type        = string
}

variable "raw_bucket" {
  description = "S3 bucket name for raw/bronze layer data"
  type        = string
}

variable "silver_bucket" {
  description = "S3 bucket name for silver layer data"
  type        = string
}

variable "gold_bucket" {
  description = "S3 bucket name for gold layer data"
  type        = string
}

variable "athena_results_bucket" {
  description = "S3 bucket name for Athena query results"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
}
