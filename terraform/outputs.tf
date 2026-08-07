output "bucket_name" {
  description = "Name of the example S3 bucket"
  value       = aws_s3_bucket.example.bucket
}

output "account_id" {
  description = "AWS account ID Terraform is operating in"
  value       = data.aws_caller_identity.current.account_id
}

output "test_security_group_id" {
  description = "ID of the locked-down test security group (no ingress/egress rules)"
  value       = aws_security_group.test_no_rules.id
}
