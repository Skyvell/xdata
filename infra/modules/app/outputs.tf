output "catalog_endpoint" {
  value = aws_db_instance.catalog.endpoint
}

output "lake_bucket_name" {
  value = aws_s3_bucket.lake.bucket
}

output "catalog_secret_arn" {
  value = aws_secretsmanager_secret.catalog.arn
}

