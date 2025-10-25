terraform {
  required_version = ">= 1.0"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 5.0" } }
}

provider "aws" { region = var.region }

# Minimal, plan-only privileges (read access to commonly used services).
# We will tighten/expand later per module.
locals {
  plan_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["sts:GetCallerIdentity"], Resource = "*" },
      # Terraform state backend access
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = [
          "arn:aws:s3:::tf-state-*",
          "arn:aws:s3:::tf-state-*/*"
        ]
      },
      # DynamoDB state locking
      {
        Effect = "Allow",
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ],
        Resource = "arn:aws:dynamodb:*:*:table/tf-locks"
      },
      # Read-only access for planning
      { Effect = "Allow", Action = [
        "kms:List*", "kms:Describe*",
        "ec2:Describe*",
        "logs:Describe*", "logs:List*", "cloudwatch:Describe*",
        "glue:Get*", "glue:List*", "athena:Get*", "athena:List*",
        "iam:List*", "iam:Get*"
      ], Resource = "*" }
    ]
  })
}

module "iam_gh_oidc" {
  source      = "../../modules/iam_gh_oidc"
  repo        = var.repo
  role_name   = var.role_name
  policy_json = local.plan_policy
}
