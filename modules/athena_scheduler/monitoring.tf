# CloudWatch alarm for transformation errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.name_prefix}-${var.job_name}-scheduler-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 3600 # 1 hour
  statistic           = "Sum"
  threshold           = 2
  alarm_description   = "${var.job_name} transformation Lambda has errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.fn.function_name
  }

  alarm_actions = var.alarm_topic_arn != "" ? [var.alarm_topic_arn] : []
  ok_actions    = var.alarm_topic_arn != "" ? [var.alarm_topic_arn] : []

  tags = var.tags
}

# Metric filter for Athena query failures
resource "aws_cloudwatch_log_metric_filter" "query_failures" {
  count          = var.enable_monitoring ? 1 : 0
  name           = "${var.name_prefix}-athena-query-failures"
  log_group_name = aws_cloudwatch_log_group.lambda.name
  pattern        = "[time, request_id, level=ERROR*, msg=\"*Query*failed*\"]"

  metric_transformation {
    name      = "AthenaQueryFailures"
    namespace = "CustomMetrics/DataLake"
    value     = "1"
  }
}

# Alarm for Athena query failures
resource "aws_cloudwatch_metric_alarm" "query_failures" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.name_prefix}-athena-query-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "AthenaQueryFailures"
  namespace           = "CustomMetrics/DataLake"
  period              = 3600
  statistic           = "Sum"
  threshold           = 2
  alarm_description   = "Athena queries failing in Silver transformation"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_topic_arn != "" ? [var.alarm_topic_arn] : []

  tags = var.tags
}

# Metric filter for data volume processed
resource "aws_cloudwatch_log_metric_filter" "data_scanned" {
  count          = var.enable_monitoring ? 1 : 0
  name           = "${var.name_prefix}-athena-data-scanned"
  log_group_name = aws_cloudwatch_log_group.lambda.name
  pattern        = "[time, request_id, level=INFO, msg=\"*data_scanned_bytes*\", value]"

  metric_transformation {
    name      = "AthenaDataScannedBytes"
    namespace = "CustomMetrics/DataLake"
    value     = "$value"
    unit      = "Bytes"
  }
}
