bucket         = "tf-state-<ACCOUNT_ID>-eu-west-1"
key            = "envs/stage/terraform.tfstate"
region         = "eu-west-1"
dynamodb_table = "tf-locks"
encrypt        = true