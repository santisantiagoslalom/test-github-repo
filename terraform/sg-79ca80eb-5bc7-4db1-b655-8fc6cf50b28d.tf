            # Auto-generated from CSV approval request 79ca80eb-5bc7-4db1-b655-8fc6cf50b28d. Do not edit by hand.
            resource "aws_security_group" "sg_request_79ca80eb_5bc7_4db1_b655_8fc6cf50b28d" {
              name        = "1-test-sg-request"
              description = "Approved via CSV upload workflow (request 79ca80eb-5bc7-4db1-b655-8fc6cf50b28d)"
              vpc_id      = var.vpc_id

              ingress {
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow SSH"
}

  egress {
  protocol    = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow HTTPS outbound"
}

              tags = {
                Name      = "1-test-sg-request"
                RequestId = "79ca80eb-5bc7-4db1-b655-8fc6cf50b28d"
              }
            }
