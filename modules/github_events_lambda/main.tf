data "archive_file" "zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/package.zip"
}

resource "aws_iam_role" "lambda" {
  name = "${var.name_prefix}-github-events-lambda-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*" },
      { Effect = "Allow", Action = ["s3:PutObject", "s3:PutObjectAcl"], Resource = "arn:aws:s3:::${var.s3_bucket}/*" },
      { Effect = "Allow", Action = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"], Resource = var.kms_key_arn }
    ]
  })
}

resource "aws_lambda_function" "fn" {
  function_name = "${var.name_prefix}-github-events-ingestor"
  role          = aws_iam_role.lambda.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"
  filename      = data.archive_file.zip.output_path
  timeout       = 30
  memory_size   = 256
  tags          = var.tags
  environment {
    variables = {
      S3_BUCKET = var.s3_bucket
      S3_PREFIX = var.s3_prefix
      LOG_LEVEL = var.log_level
      GH_TOKEN  = var.gh_token
    }
  }
}

# Run every 5 minutes (adjust later)
resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${var.name_prefix}-gh-events-5min"
  schedule_expression = "rate(5 minutes)"
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "invoke" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "lambda"
  arn       = aws_lambda_function.fn.arn
}

resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}
