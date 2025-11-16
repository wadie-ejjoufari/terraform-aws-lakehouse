variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "database" {
  type        = string
  description = "Athena/Glue database name"
}

variable "workgroup" {
  type        = string
  description = "Athena workgroup name"
}

variable "query_sql" {
  type        = string
  description = "SQL query to execute"
}

variable "schedule" {
  type        = string
  description = "EventBridge schedule expression"
  default     = "rate(1 hour)"
}

variable "output_location" {
  type        = string
  description = "S3 path for Athena query results"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for S3 encryption"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
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
