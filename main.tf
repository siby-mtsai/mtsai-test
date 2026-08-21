# =====================================================
# PROVIDER
# =====================================================
provider "aws" {
  region = var.aws_region
}

# =====================================================
# VARIABLES
# =====================================================
variable "aws_region" {
  default = "ap-south-1"
}

variable "project_name" {
  default = "blogcms"
}

variable "key_name" {
  description = "Name of an EXISTING EC2 key pair you created manually in the AWS console"
  type        = string
}

variable "db_username" {
  default = "payloadadmin"
}

variable "db_password" {
  description = "Password for the RDS Postgres instance. Pass via terraform.tfvars or -var, do not hardcode."
  type        = string
  sensitive   = true
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH/HTTP into the CMS instance. Restrict this to your own IP (e.g. 1.2.3.4/32) for better security."
  default     = "0.0.0.0/0"
}

# =====================================================
# VPC + SUBNETS
# =====================================================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${var.project_name}-private-subnet-2"
  }
}

# =====================================================
# INTERNET GATEWAY + PUBLIC ROUTING
# =====================================================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# =====================================================
# NAT GATEWAY (so the CMS instance can reach the internet for updates)
# =====================================================
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${var.project_name}-nat"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}

# =====================================================
# SECURITY GROUPS
# =====================================================
resource "aws_security_group" "cms_sg" {
  name        = "${var.project_name}-cms-sg"
  description = "Allow SSH, HTTP, HTTPS, and Payload's default port to the CMS instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Payload CMS dev/app port"
    from_port   = 3000
    to_port     = 3000
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
    Name = "${var.project_name}-cms-sg"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow Postgres access only from the CMS instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Postgres from CMS instance"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.cms_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# =====================================================
# RDS SUBNET GROUP + POSTGRES DATABASE
# =====================================================
resource "aws_db_subnet_group" "db_subnets" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "payload_db" {
  identifier             = "${var.project_name}-db"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "payloadcms"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Name = "${var.project_name}-db"
  }
}

# =====================================================
# S3 BUCKET - MEDIA/IMAGES (used by Payload CMS uploads)
# =====================================================
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "media_bucket" {
  bucket = "${var.project_name}-media-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-media-bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "media_bucket_block" {
  bucket = aws_s3_bucket.media_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =====================================================
# IAM ROLE - lets the CMS instance read/write/delete objects in the media bucket
# =====================================================
resource "aws_iam_role" "cms_role" {
  name = "${var.project_name}-cms-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-cms-role"
  }
}

resource "aws_iam_role_policy" "cms_s3_policy" {
  name = "${var.project_name}-cms-s3-policy"
  role = aws_iam_role.cms_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.media_bucket.arn,
          "${aws_s3_bucket.media_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "cms_profile" {
  name = "${var.project_name}-cms-profile"
  role = aws_iam_role.cms_role.name
}

# =====================================================
# EC2 - PAYLOAD CMS INSTANCE
# =====================================================
resource "aws_instance" "cms" {
  ami                    = "ami-0ac7b260cf76d8865"
  instance_type          = "t3.small"
  key_name               = var.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.cms_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.cms_profile.name

  tags = {
    Name = "${var.project_name}-cms"
  }

  timeouts {
    create = "15m"
  }
}

# =====================================================
# S3 BUCKET - STATIC NEXT.JS FRONTEND (blog site)
# =====================================================
resource "aws_s3_bucket" "static_site" {
  bucket = "${var.project_name}-web-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-static-site"
  }
}

resource "aws_s3_bucket_website_configuration" "static_site_config" {
  bucket = aws_s3_bucket.static_site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

resource "aws_s3_bucket_public_access_block" "static_site_block" {
  bucket = aws_s3_bucket.static_site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "static_site_policy" {
  bucket = aws_s3_bucket.static_site.id
  depends_on = [aws_s3_bucket_public_access_block.static_site_block]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.static_site.arn}/*"
      }
    ]
  })
}

# =====================================================
# OUTPUTS
# =====================================================
output "cms_public_ip" {
  value = aws_instance.cms.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.payload_db.endpoint
}

output "media_bucket_name" {
  value = aws_s3_bucket.media_bucket.bucket
}

output "static_site_endpoint" {
  value = aws_s3_bucket_website_configuration.static_site_config.website_endpoint
}
