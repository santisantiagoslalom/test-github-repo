terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local backend for now (state file stored in terraform/terraform.tfstate,
  # which is gitignored). Once you're comfortable, migrate to a remote
  # backend (S3 bucket + DynamoDB lock table) so CI runs share state safely:
  #
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "test-github-repo/terraform.tfstate"
  #   region         = "us-west-2"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "test-github-repo"
    }
  }
}

data "aws_caller_identity" "current" {}
