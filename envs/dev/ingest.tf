# Direct S3 ingestion (no Firehose - free tier compatible)
module "gh_lambda" {
  source      = "../../modules/github_events_lambda"
  name_prefix = "dp-dev"
  s3_bucket   = "dp-dev-637768123548-raw" # Using the raw bucket from data_lake module
  s3_prefix   = "github/events"
  kms_key_arn = aws_kms_key.s3.arn
  log_level   = "INFO"
  gh_token    = var.gh_token # provide via tfvars or leave empty
  tags        = local.tags
}
