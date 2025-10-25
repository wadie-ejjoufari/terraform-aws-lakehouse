bucket         = "tf-state-<ACCOUNT_ID>-eu-west-3"
key            = "envs/stage/terraform.tfstate"
region         = "eu-west-3"
dynamodb_table = "tf-locks"
encrypt        = true
