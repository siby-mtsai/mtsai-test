provider "aws" {
  region = "ap-south-1"
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow-ssh"
  description = "Allow SSH inbound"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # or your IP: ["YOUR_IP/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-ssh"
  }
}

resource "aws_instance" "my_ec2" {
  ami           = "ami-0ac7b260cf76d8865"
  instance_type = "t2.micro"
  key_name      = "siby-ec2-key-pair"

  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "MyFirstInstance"
  }
}