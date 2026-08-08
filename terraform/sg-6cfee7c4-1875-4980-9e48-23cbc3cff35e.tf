            # Auto-generated from CSV approval request 6cfee7c4-1875-4980-9e48-23cbc3cff35e. Do not edit by hand.
            resource "aws_security_group" "sg_request_6cfee7c4_1875_4980_9e48_23cbc3cff35e" {
              name        = "4-test-sg-request"
              description = "Approved via CSV upload workflow (request 6cfee7c4-1875-4980-9e48-23cbc3cff35e)"
              vpc_id      = var.vpc_id

              ingress {
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow SSH"
}

              tags = {
                Name      = "4-test-sg-request"
                RequestId = "6cfee7c4-1875-4980-9e48-23cbc3cff35e"
              }
            }
