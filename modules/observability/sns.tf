# SNS topics for different alert severities
resource "aws_sns_topic" "critical_alerts" {
  name              = "${var.name_prefix}-critical-alerts"
  display_name      = "Critical Infrastructure Alerts"
  kms_master_key_id = var.kms_key_id

  tags = merge(var.tags, {
    AlertSeverity = "critical"
  })
}

resource "aws_sns_topic" "warning_alerts" {
  name              = "${var.name_prefix}-warning-alerts"
  display_name      = "Warning Infrastructure Alerts"
  kms_master_key_id = var.kms_key_id

  tags = merge(var.tags, {
    AlertSeverity = "warning"
  })
}

resource "aws_sns_topic" "info_alerts" {
  name              = "${var.name_prefix}-info-alerts"
  display_name      = "Informational Alerts"
  kms_master_key_id = var.kms_key_id

  tags = merge(var.tags, {
    AlertSeverity = "info"
  })
}

# Email subscriptions (configure via AWS Console or add variables)
# Example subscription (uncomment and configure):
# resource "aws_sns_topic_subscription" "critical_email" {
#   topic_arn = aws_sns_topic.critical_alerts.arn
#   protocol  = "email"
#   endpoint  = var.alert_email
# }
