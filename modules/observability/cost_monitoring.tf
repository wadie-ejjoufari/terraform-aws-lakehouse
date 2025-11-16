# AWS Budgets for cost control
resource "aws_budgets_budget" "monthly_cost" {
  count = var.enable_cost_monitoring ? 1 : 0

  name              = "${var.name_prefix}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2025-11-01_00:00"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_alert_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  cost_filter {
    name   = "TagKeyValue"
    values = ["Project$DataPlatform"]
  }
}

# Cost anomaly detection (requires AWS Cost Anomaly Detection service)
# Note: This is configured via AWS Console as Terraform support is limited
# Documentation: https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/manage-ad.html
