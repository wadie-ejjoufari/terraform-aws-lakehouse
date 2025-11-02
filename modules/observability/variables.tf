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
