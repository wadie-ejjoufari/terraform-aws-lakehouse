module "catalog_athena" {
  source                = "../../modules/catalog_athena"
  name_prefix           = "dp-dev"
  raw_bucket            = module.data_lake.bucket_names["raw"]
  silver_bucket         = module.data_lake.bucket_names["silver"]
  athena_results_bucket = module.logs.log_bucket_name
  kms_key_arn           = aws_kms_key.s3.arn
  tags                  = local.tags
}

# Optional: create an output S3 prefix for CTAS (not required; Athena will create)
