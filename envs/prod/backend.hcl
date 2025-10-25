bucket         = "tf-state-<ACCOUNT_ID>-eu-west-1"
key            = "envs/prod/terraform.tfstate"
region         = "eu-west-3"
dynamodb_table = "tf-locks"
encrypt        = true
