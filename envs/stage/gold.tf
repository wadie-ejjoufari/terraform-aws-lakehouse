# Compose the INSERT query for Gold layer aggregation
locals {
  gold_insert_sql = <<-SQL
    INSERT INTO github_events_gold_daily
    SELECT
      ingest_dt,
      type        AS event_type,
      repo_name,
      COUNT(*)    AS events_count
    FROM github_events_silver
    WHERE ingest_dt = date_format(current_date, '%Y-%m-%d')
    GROUP BY ingest_dt, type, repo_name
  SQL
}

# Deploy Gold scheduler module
module "gold_scheduler" {
  source = "../../modules/athena_scheduler"

  name_prefix     = "dp-stage"
  job_name        = "gold"
  database        = module.catalog_athena.database_name
  workgroup       = module.catalog_athena.workgroup_name
  query_sql       = local.gold_insert_sql
  schedule        = "rate(1 day)"
  output_location = "s3://dp-stage-athena-results/gold-scheduler/"
  kms_key_arn     = aws_kms_key.s3.arn
  tags            = local.tags

  # Monitoring
  enable_monitoring = true
  alarm_topic_arn   = module.logs.critical_alerts_topic_arn
}

# Outputs for monitoring
output "gold_scheduler_lambda" {
  description = "Gold scheduler Lambda function name"
  value       = module.gold_scheduler.lambda_name
}

output "gold_scheduler_rule" {
  description = "Gold scheduler EventBridge rule"
  value       = module.gold_scheduler.rule_name
}

output "gold_scheduler_logs" {
  description = "Gold scheduler CloudWatch log group"
  value       = module.gold_scheduler.log_group
}
