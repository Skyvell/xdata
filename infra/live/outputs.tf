output "catalog_endpoint" {
  value = module.ducklake.catalog_endpoint
}

output "catalog_master_secret_arn" {
  value = module.ducklake.catalog_master_secret_arn
}

output "lake_bucket_name" {
  value = module.ducklake.lake_bucket_name
}

output "dagster_cluster_name" {
  value = module.dagster.dagster_cluster_name
}

output "dagster_agent_role_arn" {
  value = module.dagster.dagster_agent_role_arn
}

output "dagster_run_role_arn" {
  value = module.dagster.dagster_run_role_arn
}

output "compute_role_arn" {
  value = module.dagster.compute_role_arn
}

output "dagster_url" {
  value = module.dagster.dagster_url
}

output "orchestration_image_repo" {
  value = module.dagster.orchestration_image_repo
}
