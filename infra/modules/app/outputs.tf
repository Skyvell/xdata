output "catalog_endpoint" {
  value = aws_db_instance.catalog.endpoint
}

output "catalog_master_secret_arn" {
  value = aws_db_instance.catalog.master_user_secret[0].secret_arn
}

output "lake_bucket_name" {
  value = aws_s3_bucket.lake.bucket
}
