variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "VPC ID to create the test security group in"
  type        = string
  default     = "vpc-dad992a2"
}

# --- Security group approval workflow ---

variable "approver_email" {
  description = "Email address that receives security group approval requests (must verify in SES)"
  type        = string
}

variable "sender_email" {
  description = "Verified SES sender identity used to send approval request emails"
  type        = string
}

variable "github_owner" {
  description = "GitHub org/user that owns the repository the approval Lambda opens PRs against"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name the approval Lambda opens PRs against"
  type        = string
  default     = "test-github-repo"
}

variable "github_base_branch" {
  description = "Base branch the approval Lambda opens pull requests against"
  type        = string
  default     = "main"
}
