output "catalog_endpoint" {
  value = module.ducklake.catalog_endpoint
}

output "catalog_master_secret_arn" {
  value = module.ducklake.catalog_master_secret_arn
}

output "lake_bucket_name" {
  value = module.ducklake.lake_bucket_name
}

output "runner_repository_url" {
  value = module.scheduled_runner.runner_repository_url
}
