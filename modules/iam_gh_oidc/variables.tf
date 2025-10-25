variable "repo" {
  description = "GitHub repo"
  type        = string
}
variable "role_name" {
  description = "Name of the IAM role to create for GitHub Actions"
  type        = string
}
variable "policy_json" {
  description = "JSON policy document to attach to the IAM role"
  type        = string
}
