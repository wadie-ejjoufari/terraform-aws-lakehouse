# Compose the INSERT query for Silver layer transformation
locals {
  silver_insert_sql = <<-SQL
    INSERT INTO github_events_silver
      (event_id, event_type, event_date, repo_name, actor_login, ingest_dt, year, month)
    SELECT
      CAST(id AS varchar) AS event_id,
      CAST(type AS varchar) AS event_type,
      DATE(from_iso8601_timestamp(created_at)) AS event_date,
      CAST(repo_name AS varchar) AS repo_name,
      CAST(actor_login AS varchar) AS actor_login,
      DATE(from_iso8601_timestamp(created_at)) AS ingest_dt,
      CAST(date_format(from_iso8601_timestamp(created_at), '%Y') AS varchar) AS year,
      CAST(date_format(from_iso8601_timestamp(created_at), '%m') AS varchar) AS month
    FROM github_events_bronze
    WHERE ingest_dt = date_format(current_date, '%Y-%m-%d')
  SQL
}

# Deploy Silver scheduler module
module "silver_scheduler" {
  source = "../../modules/athena_scheduler"

  name_prefix     = "dp-prod"
  database        = module.catalog_athena.database_name
  workgroup       = module.catalog_athena.workgroup_name
  query_sql       = local.silver_insert_sql
  schedule        = "rate(1 hour)"
  output_location = "s3://dp-prod-athena-results/silver-scheduler/"
  kms_key_arn     = aws_kms_key.s3.arn
  tags            = local.tags

  # Monitoring
  enable_monitoring = true
  alarm_topic_arn   = module.logs.critical_alerts_topic_arn
}

# Outputs for monitoring
output "silver_scheduler_lambda" {
  description = "Silver scheduler Lambda function name"
  value       = module.silver_scheduler.lambda_name
}

output "silver_scheduler_rule" {
  description = "Silver scheduler EventBridge rule"
  value       = module.silver_scheduler.rule_name
}

output "silver_scheduler_logs" {
  description = "Silver scheduler CloudWatch log group"
  value       = module.silver_scheduler.log_group
}
