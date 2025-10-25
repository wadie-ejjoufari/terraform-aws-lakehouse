output "role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = aws_iam_role.gh_actions.arn
}
