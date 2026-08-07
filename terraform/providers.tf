terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote backend: state is stored in S3 (bucket created by
  # terraform/bootstrap/) with DynamoDB-based locking so CI runs share
  # state safely instead of losing it every run.
  backend "s3" {
    bucket         = "test-github-tf-state-250251693220"
    key            = "test-github-repo/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
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
