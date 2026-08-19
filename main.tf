# ---------------------------------------------------
# PROVIDER
# ---------------------------------------------------
provider "aws" {
  region = "ap-south-1"
}

# ---------------------------------------------------
# VPC + SUBNETS
# ---------------------------------------------------
resource "aws_vpc" "mtsai_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "mtsai-vpc"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.mtsai_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.mtsai_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "private-subnet-2"
  }
}

# ---------------------------------------------------
# RDS SUBNET GROUP
# ---------------------------------------------------
resource "aws_db_subnet_group" "mtsai_db_subnets" {
  name       = "mtsai-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "mtsai-db-subnet-group"
  }
}

# ---------------------------------------------------
# SECURITY GROUPS
# ---------------------------------------------------
resource "aws_security_group" "cms_sg" {
  name        = "mtsai-cms-sg"
  description = "Allow access to CMS EC2 instance"
  vpc_id      = aws_vpc.mtsai_vpc.id

  ingress {
    description = "SSH from within VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mtsai-cms-sg"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "mtsai-rds-sg"
  description = "Allow database access"
  vpc_id      = aws_vpc.mtsai_vpc.id

  ingress {
    description = "Postgres from within VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mtsai-rds-sg"
  }
}

# ---------------------------------------------------
# EC2 - CMS INSTANCE
# ---------------------------------------------------
resource "aws_instance" "mtsai_cms" {
  ami                    = "ami-0ac7b260cf76d8865"
  instance_type          = "t2.micro"
  key_name               = "siby-ec2-key-pair"
  subnet_id              = aws_subnet.private_subnet_2.id
  vpc_security_group_ids = [aws_security_group.cms_sg.id]

  tags = {
    Name = "mtsai-cms"
  }
}

# ---------------------------------------------------
# RDS - DATABASE
# ---------------------------------------------------
resource "aws_db_instance" "mtsai_db" {
  identifier             = "mtsai-db"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "mtsaidb"
  username               = "mtsaiadmin"
  password               = "ChangeMe123!"
  db_subnet_group_name   = aws_db_subnet_group.mtsai_db_subnets.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Name = "mtsai-db"
  }
}

# ---------------------------------------------------
# OUTPUTS
# ---------------------------------------------------
output "db_endpoint" {
  value = aws_db_instance.mtsai_db.endpoint
}