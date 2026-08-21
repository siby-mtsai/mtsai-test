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
  description = "Password for the RDS Postgres instance."
  type        = string
  sensitive   = true
}

variable "allowed_ssh_cidr" {
  default = "0.0.0.0/0"
}