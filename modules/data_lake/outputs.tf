output "bucket_names" {
  description = "Map of tier names to S3 bucket names"
  value       = { for k, b in aws_s3_bucket.dl : k => b.bucket }
}
