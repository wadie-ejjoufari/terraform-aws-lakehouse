# Architecture Decisions (ADRs)
- Use S3 remote state (SSE-S3) and DynamoDB locking in eu-west-1 to avoid CMK cost.
- Start without VPC/NAT to minimize cost; add later.
- Use Firehose DirectPut from Lambda to avoid Kinesis Streams cost.
- Skip Glue Crawler; define schemas manually in Terraform.