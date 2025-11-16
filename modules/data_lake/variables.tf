variable "name_prefix" {
  description = "Prefix for S3 bucket names (e.g., 'dp-dev')"
  type        = string
}

variable "log_bucket" {
  description = "Target S3 bucket for access logs"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}

variable "kms_key_id" {
  description = "KMS key ID for S3 bucket encryption"
  type        = string
}

variable "expiration_days" {
  description = "Number of days before objects expire"
  type        = number
  default     = 730
}

variable "tier_ia_days" {
  description = "Number of days before transitioning to Infrequent Access storage"
  type        = number
  default     = 30
}

variable "tier_glacier_days" {
  description = "Number of days before transitioning to Glacier storage"
  type        = number
  default     = 180
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and alarms"
  type        = bool
  default     = true
}

variable "alarm_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  type        = string
  default     = ""
}
