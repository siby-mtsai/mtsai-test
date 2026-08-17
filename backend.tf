terraform {
  backend "s3" {
    bucket = "siby-tf-state"
    key    = "terraform.tfstate"
    region = "ap-south-1"
  }
}