provider "aws" {
  region = "ap-south-1"
}

resource "aws_instance" "my_ec2" {
  ami           = "ami-0ac7b260cf76d8865"
  instance_type = "t2.micro"
  key_name      = "siby-ec2-key-pair"

  tags = {
    Name = "MyFirstInstance"
  }
}