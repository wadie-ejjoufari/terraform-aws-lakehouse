variable "name_prefix" {
  type        = string
  description = "Prefix for naming AWS resources"
}
variable "s3_bucket" {
  type        = string
  description = "S3 bucket name for storing GitHub events"
}
variable "s3_prefix" {
  type        = string
  default     = "github/events"
  description = "S3 prefix for GitHub events"
}
variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for S3 encryption"
}
variable "log_level" {
  type        = string
  default     = "INFO"
  description = "Log level for Lambda function (DEBUG, INFO, WARNING, ERROR)"
}
variable "gh_token" {
  type        = string
  default     = ""
  description = "GitHub personal access token for API authentication"
}
variable "tags" {
  type        = map(string)
  description = "Tags to apply to AWS resources"
}
