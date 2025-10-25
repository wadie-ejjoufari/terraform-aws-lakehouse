output "role_arn" {
  description = "ARN of the IAM role created for GitHub Actions"
  value       = module.iam_gh_oidc.role_arn
}
