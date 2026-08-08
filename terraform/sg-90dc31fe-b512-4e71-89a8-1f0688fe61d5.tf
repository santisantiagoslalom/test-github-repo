            # Auto-generated from CSV approval request 90dc31fe-b512-4e71-89a8-1f0688fe61d5. Do not edit by hand.
            resource "aws_security_group" "sg_request_90dc31fe_b512_4e71_89a8_1f0688fe61d5" {
              name        = "6-test-sg-request"
              description = "Approved via CSV upload workflow (request 90dc31fe-b512-4e71-89a8-1f0688fe61d5)"
              vpc_id      = var.vpc_id

              ingress {
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["10.5.0.0/24"]
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
                Name      = "6-test-sg-request"
                RequestId = "90dc31fe-b512-4e71-89a8-1f0688fe61d5"
              }
            }
