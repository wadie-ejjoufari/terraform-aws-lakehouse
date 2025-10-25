terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

# Create the GitHub OIDC provider if it doesn't exist
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name        = "github-actions-oidc"
    Description = "OIDC provider for GitHub Actions"
  }
}

resource "aws_iam_role" "gh_actions" {
  name = var.role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRoleWithWebIdentity",
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn },
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" },
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:${var.repo}:*" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "inline" {
  role   = aws_iam_role.gh_actions.id
  policy = var.policy_json
}
