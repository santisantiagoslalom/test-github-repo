            # Auto-generated from CSV approval request 561dc66a-2a6f-47fd-8fe3-9219af793486. Do not edit by hand.
            resource "aws_security_group" "sg_request_561dc66a_2a6f_47fd_8fe3_9219af793486" {
              name        = "3-test-sg-request"
              description = "Approved via CSV upload workflow (request 561dc66a-2a6f-47fd-8fe3-9219af793486)"
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
                Name      = "3-test-sg-request"
                RequestId = "561dc66a-2a6f-47fd-8fe3-9219af793486"
              }
            }
