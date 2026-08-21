terraform {
  backend "s3" {
    bucket = "siby-tf-state-2026"
    key    = "terraform.tfstate"
    region = "ap-south-1"
  }
}