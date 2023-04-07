provider "aws" {
  region = "ap-northeast-1"
}

locals {
  common_tags = {
    Terraform   = "true"
    Environment = "beta"
  }
}

resource "aws_vpc" "beta_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = merge(
    local.common_tags,
    {
      Name = "beta-vpc"
    }
  )
}

resource "aws_internet_gateway" "beta_igw" {
  vpc_id = aws_vpc.beta_vpc.id

  tags = merge(
    local.common_tags,
    {
      Name = "beta-igw"
    }
  )
}

resource "aws_subnet" "beta_subnet_1" {
  cidr_block              = "10.0.1.0/24"
  vpc_id                  = aws_vpc.beta_vpc.id
  availability_zone       = "ap-northeast-1a"

  tags = merge(
    local.common_tags,
    {
      Name = "beta-subnet-1"
    }
  )
}

resource "aws_subnet" "beta_subnet_2" {
  cidr_block        = "10.0.4.0/24"
  vpc_id            = aws_vpc.beta_vpc.id
  availability_zone = "ap-northeast-1c"

  tags = merge(
    local.common_tags,
    {
      Name = "beta-subnet-2"
    }
  )
}

resource "aws_subnet" "beta_private_subnet" {
  cidr_block        = "10.0.2.0/24"
  vpc_id            = aws_vpc.beta_vpc.id
  availability_zone = "ap-northeast-1a"

  tags = merge(
    local.common_tags,
    {
      Name = "beta-private-subnet"
    }
  )
}

resource "aws_route_table" "beta_route_table" {
  vpc_id = aws_vpc.beta_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.beta_igw.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "beta-route-table"
    }
  )
}

resource "aws_route_table_association" "beta_route_table_association_1" {
  subnet_id      = aws_subnet.beta_subnet_1.id
  route_table_id = aws_route_table.beta_route_table.id
}

resource "aws_route_table_association" "beta_route_table_association_2" {
  subnet_id      = aws_subnet.beta_subnet_2.id
  route_table_id = aws_route_table.beta_route_table.id
}

resource "aws_route_table_association" "private_route_table_association" {
  subnet_id      = aws_subnet.beta_private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}


resource "aws_security_group" "lb_sg" {
  name        = "lb_sg"
  description = "Allow HTTP and HTTPS traffic to the load balancer"
  vpc_id      = aws_vpc.beta_vpc.id

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "lb_sg"
    }
  )
}

# Security groups and security group rules for frontend, backend, and database
resource "aws_security_group" "frontend_sg" {
  name        = "frontend_sg"
  description = "Allow web traffic for all and SSH from bastion"
  vpc_id      = aws_vpc.beta_vpc.id

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
    cidr_blocks = ["${aws_instance.bastion.private_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "frontend_sg"
    }
  )
}

resource "aws_security_group" "backend_sg" {
  name        = "backend_sg"
  description = "Allow traffic from the bastion and frontend"
  vpc_id      = aws_vpc.beta_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.bastion.private_ip}/32"]
  }
  
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.frontend.private_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "backend_sg"
    }
  )
}

resource "aws_security_group" "db_sg" {
  name        = "db_sg"
  description = "Allow traffic from the bastion and backend"
  vpc_id      = aws_vpc.beta_vpc.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.backend.private_ip}/32"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.bastion.private_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "db_sg"
    }
  )
}

# Frontend instance
resource "aws_instance" "frontend" {
  ami           = "ami-05375ba8414409b07"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.beta_private_subnet.id

  vpc_security_group_ids = [
    aws_security_group.frontend_sg.id
  ]

  user_data = <<-EOF
              #!/bin/bash
              echo '${file("./id_rsa.pub")}' >> /home/ubuntu/.ssh/authorized_keys
              sudo apt-get update
              sudo apt-get install ca-certificates curl gnupg lsb-release
              sudo mkdir -m 0755 -p /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              sudo apt-get update
              sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              EOF

  tags = merge(
    local.common_tags,
    {
      Name = "frontend-instance"
    }
  )
}

# Backend instance
resource "aws_instance" "backend" {
  ami           = "ami-05375ba8414409b07"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.beta_private_subnet.id

  vpc_security_group_ids = [
    aws_security_group.backend_sg.id
  ]

  user_data = <<-EOF
              #!/bin/bash
              echo '${file("./id_rsa.pub")}' >> /home/ubuntu/.ssh/authorized_keys
              sudo apt-get update
              sudo apt-get install ca-certificates curl gnupg lsb-release
              sudo mkdir -m 0755 -p /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              sudo apt-get update
              sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              EOF

  tags = merge(
    local.common_tags,
    {
      Name = "backend-instance"
    }
  )
}


# DB instance
resource "aws_instance" "db" {
  ami           = "ami-05375ba8414409b07"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.beta_private_subnet.id

  vpc_security_group_ids = [
    aws_security_group.db_sg.id
  ]

  user_data = <<-EOF
              #!/bin/bash
              echo '${file("./id_rsa.pub")}' >> /home/ubuntu/.ssh/authorized_keys
              sudo apt-get update
              sudo apt-get install ca-certificates curl gnupg lsb-release
              sudo mkdir -m 0755 -p /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              sudo apt-get update
              sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              sudo apt-get install --assume-yes awscli
              EOF

  tags = merge(
    local.common_tags,
    {
      Name = "db-instance"
    }
  )
}

resource "aws_lb" "beta_lb" {
  name               = "main-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.beta_subnet_1.id, aws_subnet.beta_subnet_2.id]

  tags = merge(
    local.common_tags,
    {
      Name = "main-lb"
    }
  )
}

resource "aws_lb_target_group" "frontend" {
  name     = "frontend-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.beta_vpc.id
}

resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.beta_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.beta_certificate.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.beta_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}


resource "aws_route53_record" "cert_validation" {
  zone_id = "Z0512891W8E15FDN4EWB"
  name    = element(aws_acm_certificate.beta_certificate.domain_validation_options.*.resource_record_name, 0)
  type    = element(aws_acm_certificate.beta_certificate.domain_validation_options.*.resource_record_type, 0)
  records = [element(aws_acm_certificate.beta_certificate.domain_validation_options.*.resource_record_value, 0)]
  ttl     = 60
}

resource "aws_acm_certificate" "beta_certificate" {
  domain_name       = "beta.beprayed.com"
  validation_method = "DNS"

  tags = merge(
    local.common_tags,
    {
      Name = "certificate"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.beta_certificate.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
}

resource "aws_lb_target_group_attachment" "frontend" {
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.frontend.id
  port             = 80
}

### Bastion Setup ###
resource "aws_key_pair" "ssh_key" {
  key_name   = "jim-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# Add this block to create a new security group for the bastion host
resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Allow SSH access to the bastion host"
  vpc_id      = aws_vpc.beta_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${local.my_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "bastion_sg",
    }
  )
}

resource "aws_instance" "bastion" {
  ami           = "ami-05375ba8414409b07"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.beta_subnet_1.id
  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.bastion_sg.id
  ]

  user_data = <<-EOF
              #!/bin/bash
              mkdir -p /home/ubuntu/.ssh
              touch /home/ubuntu/.ssh/authorized_keys
              echo '${file("~/.ssh/id_rsa.pub")}' >> /home/ubuntu/.ssh/authorized_keys
              echo '${file("./id_rsa")}' >> /home/ubuntu/.ssh/id_rsa
              echo '${file("./id_rsa.pub")}' >> /home/ubuntu/.ssh/id_rsa.pub
              chown -R ubuntu:ubuntu /home/ubuntu/.ssh
              chmod 700 /home/ubuntu/.ssh
              chmod 600 /home/ubuntu/.ssh/authorized_keys
              EOF

  tags = merge(
    local.common_tags,
    {
      Name = "bastion-host"
    }
  )
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  value = aws_instance.bastion.private_ip
}

output "backend_private_ip" {
  value = aws_instance.backend.private_ip
}

resource "aws_route53_record" "beta" {
  zone_id = "Z0512891W8E15FDN4EWB"
  name    = "beta.beprayed.com"
  type    = "A"

  alias {
    name                   = aws_lb.beta_lb.dns_name
    zone_id                = aws_lb.beta_lb.zone_id
    evaluate_target_health = false
  }

  depends_on = [aws_acm_certificate_validation.cert]
}

resource "local_file" "public_key" {
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = "${path.module}/id_rsa.pub"
}

resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "${path.module}/id_rsa"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
}

data "http" "my_ip" {
  url = "https://api.ipify.org?format=text"
}

locals {
  my_ip = chomp(data.http.my_ip.body)
}

resource "aws_eip" "nat_eip" {
  vpc = true

  tags = merge(
    local.common_tags,
    {
      Name = "nat-eip"
    }
  )
}

resource "aws_nat_gateway" "nat_gw" {
  subnet_id     = aws_subnet.beta_subnet_1.id
  allocation_id = aws_eip.nat_eip.id

  tags = merge(
    local.common_tags,
    {
      Name = "nat-gw"
    }
  )
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.beta_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "private-route-table"
    }
  )
}
