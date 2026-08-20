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
# PUBLIC SUBNET (for bastion)
# ---------------------------------------------------
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.mtsai_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# ---------------------------------------------------
# INTERNET GATEWAY + ROUTING (for public subnet)
# ---------------------------------------------------
resource "aws_internet_gateway" "mtsai_igw" {
  vpc_id = aws_vpc.mtsai_vpc.id

  tags = {
    Name = "mtsai-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.mtsai_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mtsai_igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
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

  # NEW: allow SSH from the bastion specifically
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
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

# NEW: bastion security group
resource "aws_security_group" "bastion_sg" {
  name        = "mtsai-bastion-sg"
  description = "Allow SSH from internet to bastion"
  vpc_id      = aws_vpc.mtsai_vpc.id

  ingress {
    description = "SSH"
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

  tags = {
    Name = "mtsai-bastion-sg"
  }
}

# ---------------------------------------------------
# IAM ROLE - S3 READ ONLY ACCESS FOR EC2 (mtsai-cms)
# ---------------------------------------------------

# 1. The role itself - defines WHO can use it (EC2 service)
resource "aws_iam_role" "s3_readonly_access_ec2" {
  name = "S3ReadOnlyAccessEC2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "S3ReadOnlyAccessEC2"
  }
}

# 2. Attach AWS's built-in "S3 read-only" managed policy to the role
resource "aws_iam_role_policy_attachment" "s3_readonly_attach" {
  role       = aws_iam_role.s3_readonly_access_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# 3. Instance profile - the actual "container" EC2 uses to hold the role
resource "aws_iam_instance_profile" "s3_readonly_profile" {
  name = "S3ReadOnlyAccessEC2-profile"
  role = aws_iam_role.s3_readonly_access_ec2.name
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
  iam_instance_profile   = aws_iam_instance_profile.s3_readonly_profile.name

  tags = {
    Name = "mtsai-cms"
  }
}

# ---------------------------------------------------
# S3 BUCKET - for mtsai-cms
# ---------------------------------------------------
resource "aws_s3_bucket" "mtsai_cms_bucket" {
  bucket = "mtsai-cms-bucket-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "mtsai-cms-bucket"
  }
}

data "aws_caller_identity" "current" {}

output "cms_bucket_name" {
  value = aws_s3_bucket.mtsai_cms_bucket.bucket
}

# ---------------------------------------------------
# EC2 - BASTION INSTANCE (NEW)
# ---------------------------------------------------
resource "aws_instance" "bastion" {
  ami                    = "ami-0ac7b260cf76d8865"
  instance_type          = "t2.micro"
  key_name               = "siby-ec2-key-pair"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "mtsai-bastion"
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

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

# ---------------------------------------------------
# NAT GATEWAY (lets private subnets reach the internet)
# ---------------------------------------------------
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "mtsai-nat-eip"
  }
}

resource "aws_nat_gateway" "mtsai_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "mtsai-nat"
  }

  depends_on = [aws_internet_gateway.mtsai_igw]
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.mtsai_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.mtsai_nat.id
  }

  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "private_rt_assoc_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_rt_assoc_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}