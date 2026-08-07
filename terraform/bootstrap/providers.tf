terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Intentionally local backend: this config bootstraps the S3 bucket and
  # DynamoDB table that the main terraform/ config uses as its remote
  # backend, so it can't depend on that backend existing yet. Run this
  # once via the "Bootstrap Terraform State Backend" workflow.
}

provider "aws" {
  region = "us-west-2"

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "test-github-repo-bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}
