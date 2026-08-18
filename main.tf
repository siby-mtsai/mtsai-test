provider "aws" {
  region = "ap-south-1"
}

resource "aws_instance" "my_ec2" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"
  key_name      = "siby-ec2-key-pair"

  tags = {
    Name = "MyFirstInstance"
  }
}