variable "name_prefix" {
  description = "Prefix for resource names (e.g., dp-dev)"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket for Firehose to write to (e.g., dp-dev-raw)"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN to use for Firehose. Empty string disables KMS."
  type        = string
  default     = ""
  validation {
    condition     = var.kms_key_arn == "" || can(regex("^arn:aws:kms:[a-z0-9-]+:\\d{12}:key/.+$", var.kms_key_arn))
    error_message = "kms_key_arn must be empty or a valid KMS key ARN (arn:aws:kms:region:012345678901:key/...)."
  }
}

variable "buffering_mb" {
  description = "Firehose buffer size in MB"
  type        = number
  default     = 5
}

variable "buffering_seconds" {
  description = "Firehose buffer interval in seconds"
  type        = number
  default     = 60
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}
