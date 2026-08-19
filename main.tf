provider "aws" {
  region = "ap-south-1"
}

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

resource "aws_db_subnet_group" "mtsai_db_subnets" {
  name       = "mtsai-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "mtsai-db-subnet-group"
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

resource "aws_db_instance" "mtsai_db" {
  identifier             = "mtsai-db"
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "mtsaidb-cms"
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
