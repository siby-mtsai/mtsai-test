provider "aws" {
  region = var.region
}

resource "aws_instance" "my_ec2" {
  ami           = "ami-0c55b159cbfafe1f0" # Update with latest Amazon Linux AMI
  instance_type = "t2.micro"
  key_name      = "your-key-pair-name"

  tags = {
    Name = "MyFirstInstance"
  }
}