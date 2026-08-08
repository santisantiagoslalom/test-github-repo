terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # Remote S3 backend so state persists across CI runs (the bootstrap
  # workflow creates this bucket; requires S3 native object-lock locking,
  # supported since Terraform 1.10+).
  backend "s3" {
    bucket       = "test-github-tf-state-250251693220"
    key          = "test-github-repo/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
    encrypt      = true
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
