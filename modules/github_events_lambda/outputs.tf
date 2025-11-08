output "lambda_name" {
  value       = aws_lambda_function.fn.function_name
  description = "Name of the GitHub events Lambda function"
}
