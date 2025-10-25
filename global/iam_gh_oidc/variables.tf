variable "region" {
  description = "AWS region where resources will be created"
  type        = string
}
variable "repo" {
  description = "GitHub repository in the format owner/repo"
  type        = string
}
variable "role_name" {
  description = "Name of the IAM role to create for GitHub Actions"
  type        = string
}
