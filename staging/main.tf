# Define provider block for AWS
provider "aws" {
  region = "ap-northeast-1"
}

# Provision EC2 instance
resource "aws_instance" "staging" {
  ami           = "ami-05375ba8414409b07"
  instance_type = "t2.small"
  tags = {
    Name = "staging"
  }

  # Allow HTTP, HTTPS and SSH traffic
  vpc_security_group_ids = [aws_security_group.staging-sg.id]
}

# Create security group for EC2 instance
resource "aws_security_group" "staging-sg" {
  name_prefix = "staging"
  tags = {
    Name = "staging"
  }

  # Allow HTTP, HTTPS, and SSH traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  }

  # enable postgres port
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
    description = "office"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Provision an Elastic IP address
resource "aws_eip" "staging" {
  vpc = true

  tags = {
    Name = "staging"
  }
}

# Associate Elastic IP address with the EC2 instance
resource "aws_eip_association" "staging" {
  instance_id   = aws_instance.staging.id
  allocation_id = aws_eip.staging.id
}

data "http" "myip" {
  url = "http://checkip.amazonaws.com/"
}