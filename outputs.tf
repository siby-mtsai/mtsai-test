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