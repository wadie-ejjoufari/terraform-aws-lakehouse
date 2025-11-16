resource "aws_cloudwatch_dashboard" "main" {
  count          = var.enable_dashboard ? 1 : 0
  dashboard_name = "${var.name_prefix}-lakehouse"

  dashboard_body = jsonencode({
    widgets = [
      # Lambda Invocations
      {
        type = "metric"
        properties = {
          metrics = var.lambda_function_names != null ? [
            for fn_name in var.lambda_function_names : [
              "AWS/Lambda",
              "Invocations",
              "FunctionName", fn_name,
              { stat = "Sum", label = fn_name }
            ]
          ] : []
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "Lambda Invocations"
        }
      },

      # Lambda Errors
      {
        type = "metric"
        properties = {
          metrics = var.lambda_function_names != null ? [
            for fn_name in var.lambda_function_names : [
              "AWS/Lambda",
              "Errors",
              "FunctionName", fn_name,
              { stat = "Sum", label = fn_name }
            ]
          ] : []
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "Lambda Errors"
        }
      },

      # S3 bucket metrics
      {
        type = "metric"
        properties = {
          metrics = var.bucket_names != null ? [
            for bucket_name in var.bucket_names : [
              "AWS/S3",
              "BucketSizeBytes",
              "BucketName", bucket_name,
              "StorageType", "StandardStorage",
              { stat = "Average", label = bucket_name }
            ]
          ] : []
          period = 86400
          stat   = "Average"
          region = var.region
          title  = "S3 Bucket Sizes"
        }
      },

      # Custom metrics (these were already almost correct)
      {
        type = "metric"
        properties = {
          metrics = [
            ["CustomMetrics/DataLake", "GitHubAPIRateLimitErrors", { stat = "Sum" }],
            [".", "AthenaQueryFailures", { stat = "Sum" }],
            [".", "AthenaDataScannedBytes", { stat = "Sum" }]
          ]
          period = 3600
          stat   = "Sum"
          region = var.region
          title  = "Custom Data Lake Metrics"
        }
      }
    ]
  })
}
