provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "nextjs_site" {
  bucket = "siby-nextjs-site-2026"   # pick your own unique suffix

  tags = {
    Name    = "siby-nextjs-site"
    Purpose = "learning-nextjs-hosting"
  }
}

resource "aws_s3_bucket_public_access_block" "nextjs_access" {
  bucket = aws_s3_bucket.nextjs_site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "nextjs_website" {
  bucket = aws_s3_bucket.nextjs_site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

resource "aws_s3_bucket_policy" "nextjs_public_read" {
  bucket = aws_s3_bucket.nextjs_site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.nextjs_site.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.nextjs_access]
}