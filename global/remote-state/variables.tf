variable "region" {
  description = "AWS region for remote state resources"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "Region must be a valid AWS region format (e.g., eu-west-3)."
  }
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Account ID must be exactly 12 digits."
  }
}
