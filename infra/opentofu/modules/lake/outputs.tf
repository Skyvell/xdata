output "bucket_name" {
  value = aws_s3_bucket.lake.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.lake.arn
}

output "data_path" {
  value       = "s3://${aws_s3_bucket.lake.bucket}/"
  description = "S3 URI for the DuckLake data layer. Exposed to consumers as DUCKLAKE_DATA_PATH."
}
