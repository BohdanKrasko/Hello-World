terraform {
	backend "s3" {
		bucket = "terraform-bucket-krasko"
		key = "terraform.tfstate"
		region = "eu-west-2"
		dynamodb_table = "terraform-state-lock-dynamo"
	}
}


provider "aws" {
  region = "eu-west-2"
}

resource "aws_vpc" "friday-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "friday-vpc"
  }
}

resource "aws_subnet" "friday-subnet" {
  cidr_block              = cidrsubnet(aws_vpc.friday-vpc.cidr_block, 3, 1)
  vpc_id                  = aws_vpc.friday-vpc.id
  map_public_ip_on_launch = true
}

resource "aws_route_table" "route-table" {
  vpc_id = aws_vpc.friday-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "route-table"
  }
}

resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.friday-subnet.id
  route_table_id = aws_route_table.route-table.id
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.friday-vpc.id
  tags = {
    Name = "gw"
  }
}


resource "aws_security_group" "sg" {
  name   = "sg"
  vpc_id = aws_vpc.friday-vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "key" {
  key_name   = "ubuntu"
  public_key = file(var.key)
}

resource "aws_instance" "ec2" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.sg.id]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(pr_key)
    host        = self.public_ip
  }
  tags = {
    Name = var.ec2_name
  }
  subnet_id = aws_subnet.friday-subnet.id
}

output "vpc_id" {
	value = aws_vpc.friday-vpc.id
}
