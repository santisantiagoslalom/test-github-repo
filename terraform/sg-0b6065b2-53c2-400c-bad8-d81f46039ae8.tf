            # Auto-generated from CSV approval request 0b6065b2-53c2-400c-bad8-d81f46039ae8. Do not edit by hand.
            resource "aws_security_group" "sg_request_0b6065b2_53c2_400c_bad8_d81f46039ae8" {
              name        = "sg-request-0b6065b2-53c2-400c-bad8-d81f46039ae8"
              description = "Approved via CSV upload workflow (request 0b6065b2-53c2-400c-bad8-d81f46039ae8)"
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
                Name      = "sg-request-0b6065b2-53c2-400c-bad8-d81f46039ae8"
                RequestId = "0b6065b2-53c2-400c-bad8-d81f46039ae8"
              }
            }
