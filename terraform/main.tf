# A minimal, safe-to-destroy resource so you can validate the full
# init -> plan -> apply -> destroy pipeline end to end.
resource "aws_s3_bucket" "example" {
  bucket = "test-github-repo-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "example" {
  bucket = aws_s3_bucket.example.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Locked-down test security group — no ingress or egress rules defined,
# so it denies all inbound traffic and all outbound traffic (Terraform
# removes AWS's default "allow all egress" rule since it isn't declared here).
resource "aws_security_group" "test_no_rules" {
  name        = "test-github-sg"
  description = "test-github-sg"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "test-github-sg"
    Environment = var.environment
  }
}
