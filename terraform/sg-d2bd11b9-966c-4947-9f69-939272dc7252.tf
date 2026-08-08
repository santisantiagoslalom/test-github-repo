            # Auto-generated from CSV approval request d2bd11b9-966c-4947-9f69-939272dc7252. Do not edit by hand.
            resource "aws_security_group" "sg_request_d2bd11b9_966c_4947_9f69_939272dc7252" {
              name        = "1-test-sg-request"
              description = "Approved via CSV upload workflow (request d2bd11b9-966c-4947-9f69-939272dc7252)"
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
                RequestId = "d2bd11b9-966c-4947-9f69-939272dc7252"
              }
            }
