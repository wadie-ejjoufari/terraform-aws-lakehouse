# CloudWatch alarm for Lambda errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.name_prefix}-gh-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "GitHub ingestion Lambda has errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.fn.function_name
  }

  alarm_actions = var.alarm_topic_arn != "" ? [var.alarm_topic_arn] : []
  ok_actions    = var.alarm_topic_arn != "" ? [var.alarm_topic_arn] : []

  tags = var.tags
}

# CloudWatch alarm for Lambda throttles
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.name_prefix}-gh-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "GitHub ingestion Lambda is being throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.fn.function_name
  }

  alarm_actions = var.alarm_topic_arn != "" ? [var.alarm_topic_arn] : []

  tags = var.tags
}

# CloudWatch alarm for Lambda duration
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.name_prefix}-gh-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 25000 # 25 seconds (83% of 30s timeout)
  alarm_description   = "GitHub ingestion Lambda approaching timeout"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.fn.function_name
  }

  alarm_actions = var.alarm_topic_arn != "" ? [var.alarm_topic_arn] : []

  tags = var.tags
}

# Metric filter for GitHub API rate limit errors
resource "aws_cloudwatch_log_metric_filter" "api_rate_limit" {
  count          = var.enable_monitoring ? 1 : 0
  name           = "${var.name_prefix}-gh-api-rate-limit"
  log_group_name = "/aws/lambda/${aws_lambda_function.fn.function_name}"
  pattern        = "[time, request_id, level=ERROR*, msg=\"*rate limit*\"]"

  metric_transformation {
    name      = "GitHubAPIRateLimitErrors"
    namespace = "CustomMetrics/DataLake"
    value     = "1"
  }
}

# Alarm for API rate limit errors
resource "aws_cloudwatch_metric_alarm" "api_rate_limit" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.name_prefix}-gh-api-rate-limit"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "GitHubAPIRateLimitErrors"
  namespace           = "CustomMetrics/DataLake"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "GitHub API rate limit being hit"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_topic_arn != "" ? [var.alarm_topic_arn] : []

  tags = var.tags
}
