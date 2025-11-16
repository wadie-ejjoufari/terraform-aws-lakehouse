variable "name_prefix" {
  type        = string
  description = "Prefix to be used for naming resources"
}

variable "tags" {
  type        = map(string)
  description = "Tags to be applied to all resources"
}

variable "kms_key_id" {
  description = "KMS key ARN for S3 bucket encryption"
  type        = string
}

variable "enable_alerting" {
  description = "Enable SNS alerting"
  type        = bool
  default     = true
}

# variable "alert_email" {
#   description = "Email address for critical alerts (optional)"
#   type        = string
#   default     = ""
# }

variable "enable_cost_monitoring" {
  description = "Enable AWS Budgets cost monitoring"
  type        = bool
  default     = true
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = string
  default     = "50"
}

variable "budget_alert_emails" {
  description = "Email addresses for budget alerts"
  type        = list(string)
  default     = []
}

variable "enable_dashboard" {
  description = "Enable CloudWatch dashboard"
  type        = bool
  default     = true
}

variable "lambda_function_names" {
  description = "List of Lambda function names to monitor"
  type        = list(string)
  default     = null
}

variable "bucket_names" {
  description = "List of S3 bucket names to monitor"
  type        = list(string)
  default     = null
}

variable "region" {
  description = "AWS region for dashboard"
  type        = string
  default     = "eu-west-3"
}
