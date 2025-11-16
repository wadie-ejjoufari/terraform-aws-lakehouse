# Direct S3 ingestion (no Firehose - free tier compatible)
module "gh_lambda" {
  source      = "../../modules/github_events_lambda"
  name_prefix = "dp-prod"
  s3_bucket   = module.data_lake.bucket_names["raw"]
  s3_prefix   = "github/events"
  kms_key_arn = aws_kms_key.s3.arn
  log_level   = "INFO"
  gh_token    = var.gh_token
  tags        = local.tags

  # Monitoring
  enable_monitoring = true
  alarm_topic_arn   = module.logs.warning_alerts_topic_arn
}
