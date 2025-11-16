output "log_bucket_name" {
  value       = aws_s3_bucket.logs.bucket
  description = "Name of the S3 bucket used for logs"
}

output "critical_alerts_topic_arn" {
  description = "ARN of the critical alerts SNS topic"
  value       = var.enable_alerting ? aws_sns_topic.critical_alerts.arn : null
}

output "warning_alerts_topic_arn" {
  description = "ARN of the warning alerts SNS topic"
  value       = var.enable_alerting ? aws_sns_topic.warning_alerts.arn : null
}

output "info_alerts_topic_arn" {
  description = "ARN of the info alerts SNS topic"
  value       = var.enable_alerting ? aws_sns_topic.info_alerts.arn : null
}
