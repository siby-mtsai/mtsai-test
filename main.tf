provider "aws" {
  region = var.region
}

resource "aws_instance" "siby_instance" {
  ami = "ami-0f58b397bc5c1f2e8"
  instance_type = "t2.micro"

  tags = {
    Name = "text-siby-ec2-instance"
  }
}