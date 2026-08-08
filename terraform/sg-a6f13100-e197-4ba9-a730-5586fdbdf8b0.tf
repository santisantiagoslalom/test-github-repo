            # Auto-generated from CSV approval request a6f13100-e197-4ba9-a730-5586fdbdf8b0. Do not edit by hand.
            resource "aws_security_group" "sg_request_a6f13100_e197_4ba9_a730_5586fdbdf8b0" {
              name        = "5-test-sg-request"
              description = "Approved via CSV upload workflow (request a6f13100-e197-4ba9-a730-5586fdbdf8b0)"
              vpc_id      = var.vpc_id

              ingress {
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["10.5.0.0/24"]
  description = "Allow SSH"
}

              tags = {
                Name      = "5-test-sg-request"
                RequestId = "a6f13100-e197-4ba9-a730-5586fdbdf8b0"
              }
            }
