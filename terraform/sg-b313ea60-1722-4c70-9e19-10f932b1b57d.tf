            # Auto-generated from CSV approval request b313ea60-1722-4c70-9e19-10f932b1b57d. Do not edit by hand.
            resource "aws_security_group" "sg_request_b313ea60_1722_4c70_9e19_10f932b1b57d" {
              name        = "sg-request-b313ea60-1722-4c70-9e19-10f932b1b57d"
              description = "Approved via CSV upload workflow (request b313ea60-1722-4c70-9e19-10f932b1b57d)"
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
                Name      = "sg-request-b313ea60-1722-4c70-9e19-10f932b1b57d"
                RequestId = "b313ea60-1722-4c70-9e19-10f932b1b57d"
              }
            }
