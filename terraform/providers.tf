terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local backend for now (state file stored in terraform/terraform.tfstate,
  # which is gitignored and lost at the end of each CI run). Once the
  # bootstrap workflow has created the state bucket, switch back to:
  #
  # backend "s3" {
  #   bucket       = "test-github-tf-state-250251693220"
  #   key          = "test-github-repo/terraform.tfstate"
  #   region       = "us-west-2"
  #   use_lockfile = true
  #   encrypt      = true
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
