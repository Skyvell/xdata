output "metadata_endpoint" {
  value = module.metadata.endpoint
}

output "metadata_master_secret_arn" {
  value = module.metadata.master_secret_arn
}

output "lake_bucket_name" {
  value = module.lake.bucket_name
}

output "runner_repository_url" {
  value = module.runner.runner_repository_url
}
