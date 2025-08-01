terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.62.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Terra-VPC"
  }
}

# Public Subnets
resource "aws_subnet" "web-subnet-1" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = { Name = "Web-1a" }
}

resource "aws_subnet" "web-subnet-2" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = { Name = "Web-lb" }
}

# Application Private Subnets
resource "aws_subnet" "application-subnet-1" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = false
  tags = { Name = "Application-1a" }
}

resource "aws_subnet" "application-subnet-2" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "ap-south-1b"
  tags = { Name = "Application-lb" }
}

# Database Subnets
resource "aws_subnet" "database-subnet-1" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "ap-south-1a"
  tags = { Name = "Database-1a" }
}

resource "aws_subnet" "database-subnet-2" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = "10.0.22.0/24"
  availability_zone = "ap-south-1b"
  tags = { Name = "Database-lb" }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my-vpc.id
  tags = { Name = "Terra-IGW" }
}

# Web Route Table
resource "aws_route_table" "web-rt" {
  vpc_id = aws_vpc.my-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "WebRT" }
}

# Subnet associations
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.web-subnet-1.id
  route_table_id = aws_route_table.web-rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.web-subnet-2.id
  route_table_id = aws_route_table.web-rt.id
}

# EC2 Web Instances
resource "aws_instance" "webserver1" {
  ami                    = "ami-0492447090ced6eb5"
  instance_type          = "t2.micro"
  availability_zone      = "ap-south-1a"
  key_name               = "saichinnu"
  vpc_security_group_ids = [aws_security_group.webserver-sg.id]
  subnet_id              = aws_subnet.web-subnet-1.id
  user_data              = file("apache.sh")
  tags = { Name = "Web Server-1" }
}

resource "aws_instance" "webserver2" {
  ami                    = "ami-0492447090ced6eb5"
  instance_type          = "t2.micro"
  availability_zone      = "ap-south-1b"
  key_name               = "saichinnu"
  vpc_security_group_ids = [aws_security_group.webserver-sg.id]
  subnet_id              = aws_subnet.web-subnet-2.id
  user_data              = file("apache.sh")
  tags = { Name = "Web Server-2" }
}

# EC2 App Instances
resource "aws_instance" "appserver1" {
  ami                    = "ami-0492447090ced6eb5"
  instance_type          = "t2.micro"
  availability_zone      = "ap-south-1a"
  key_name               = "saichinnu"
  vpc_security_group_ids = [aws_security_group.appserver-sg.id]
  subnet_id              = aws_subnet.application-subnet-1.id
  tags = { Name = "app Server-1" }
}

resource "aws_instance" "appserver2" {
  ami                    = "ami-0492447090ced6eb5"
  instance_type          = "t2.micro"
  availability_zone      = "ap-south-1b"
  key_name               = "saichinnu"
  vpc_security_group_ids = [aws_security_group.appserver-sg.id]
  subnet_id              = aws_subnet.application-subnet-2.id
  tags = { Name = "app Server-2" }
}

# RDS
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "terra-db-subnet-group"
  subnet_ids = [aws_subnet.database-subnet-1.id, aws_subnet.database-subnet-2.id]
  tags = { Name = "Terra DB Subnet Group" }
}

resource "aws_db_instance" "default" {
  allocated_storage      = 10
  db_name                = "mydb"
  engine                 = "mysql"
  engine_version         = "8.0.41"
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = "Root123456"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.database-sg.id]
  skip_final_snapshot    = true
  tags = { Name = "MySQL-DB" }
}

# Security Groups
resource "aws_security_group" "webserver-sg" {
  name        = "webserver-sg"
  vpc_id      = aws_vpc.my-vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "Web-SG" }
}

resource "aws_security_group" "appserver-sg" {
  name        = "appserver-SG"
  vpc_id      = aws_vpc.my-vpc.id
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "appserver-SG" }
}

resource "aws_security_group" "database-sg" {
  name        = "Database-SG"
  vpc_id      = aws_vpc.my-vpc.id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 32768
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "Database-SG" }
}

# ALB Setup
resource "aws_lb" "external-elb" {
  name               = "External-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.webserver-sg.id]
  subnets            = [aws_subnet.web-subnet-1.id, aws_subnet.web-subnet-2.id]
}

resource "aws_lb_target_group" "external-elb" {
  name     = "ALB-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my-vpc.id
}

resource "aws_lb_target_group_attachment" "external-elb1" {
  target_group_arn = aws_lb_target_group.external-elb.arn
  target_id        = aws_instance.webserver1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "external-elb2" {
  target_group_arn = aws_lb_target_group.external-elb.arn
  target_id        = aws_instance.webserver2.id
  port             = 80
}

resource "aws_lb_listener" "external-elb" {
  load_balancer_arn = aws_lb.external-elb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external-elb.arn
  }
}

output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.external-elb.dns_name
}

resource "aws_s3_bucket" "example" {
  bucket = "ckbkt2001"
  tags = {
    Name        = "ckbkt2001"
    Environment = "Dev"
  }
}

resource "aws_iam_user" "one" {
  for_each = var.iam_users
  name     = each.value
}

variable "iam_users" {
  type    = set(string)
  default = ["userone", "usertwo", "userthree", "userfour"]
}

resource "aws_iam_group" "two" {
  name = "DevOpsGrp"
}
