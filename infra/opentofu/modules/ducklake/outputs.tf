output "catalog_endpoint" {
  value = aws_db_instance.catalog.endpoint
}

output "catalog_address" {
  value = aws_db_instance.catalog.address
}

output "catalog_port" {
  value = aws_db_instance.catalog.port
}

output "catalog_db_name" {
  value = aws_db_instance.catalog.db_name
}

output "catalog_master_secret_arn" {
  value = aws_db_instance.catalog.master_user_secret[0].secret_arn
}

output "catalog_identifier" {
  value       = aws_db_instance.catalog.identifier
  description = "RDS instance identifier; used by consumers to scope rds-db:connect IAM policies."
}

output "catalog_resource_id" {
  value       = aws_db_instance.catalog.resource_id
  description = "RDS resource id; used in rds-db:connect ARNs."
}

output "catalog_arn" {
  value = aws_db_instance.catalog.arn
}

output "catalog_sg_id" {
  value = aws_security_group.catalog.id
}

output "lake_bucket_name" {
  value = aws_s3_bucket.lake.bucket
}

output "lake_bucket_arn" {
  value = aws_s3_bucket.lake.arn
}

output "lake_data_path" {
  value       = "s3://${aws_s3_bucket.lake.bucket}/"
  description = "S3 URI for the DuckLake data layer. Exposed to consumers as DUCKLAKE_DATA_PATH."
}
