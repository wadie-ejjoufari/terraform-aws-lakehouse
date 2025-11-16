# S3 bucket metrics for each tier
resource "aws_cloudwatch_metric_alarm" "bucket_4xx_errors" {
  for_each = var.enable_monitoring ? aws_s3_bucket.dl : {}

  alarm_name          = "${var.name_prefix}-${each.key}-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4xxErrors"
  namespace           = "AWS/S3"
  period              = 300
  statistic           = "Sum"
  threshold           = 50
  alarm_description   = "S3 bucket ${each.key} has high 4xx error rate"
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName = each.value.id
    FilterId   = "EntireBucket"
  }

  alarm_actions = var.alarm_topic_arn != "" ? [var.alarm_topic_arn] : []

  tags = var.tags
}

# Monitor bucket size (cost control)
resource "aws_cloudwatch_metric_alarm" "bucket_size_warning" {
  for_each = var.enable_monitoring ? aws_s3_bucket.dl : {}

  alarm_name          = "${var.name_prefix}-${each.key}-size-warning"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BucketSizeBytes"
  namespace           = "AWS/S3"
  period              = 86400 # 1 day
  statistic           = "Average"
  threshold           = 107374182400 # 100 GB in bytes
  alarm_description   = "S3 bucket ${each.key} size exceeds 100 GB"
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName  = each.value.id
    StorageType = "StandardStorage"
  }

  alarm_actions = var.alarm_topic_arn != "" ? [var.alarm_topic_arn] : []

  tags = var.tags
}
