module "app" {
  source = "../modules/app"

  region = var.region

  catalog_instance_class          = var.catalog_instance_class
  catalog_multi_az                = var.catalog_multi_az
  catalog_backup_retention_period = var.catalog_backup_retention_period
  catalog_skip_final_snapshot     = var.catalog_skip_final_snapshot
  catalog_deletion_protection     = var.catalog_deletion_protection
  catalog_allowed_cidrs           = var.catalog_allowed_cidrs

  dagster_org_slug                = var.dagster_org_slug
  dagster_deployment              = var.dagster_deployment
  dagster_agent_image             = var.dagster_agent_image
  dagster_agent_token_secret_name = var.dagster_agent_token_secret_name
  dagster_agent_cpu               = var.dagster_agent_cpu
  dagster_agent_memory            = var.dagster_agent_memory
  dagster_agent_replicas          = var.dagster_agent_replicas
}

output "catalog_endpoint" { value = module.app.catalog_endpoint }
output "catalog_master_secret_arn" { value = module.app.catalog_master_secret_arn }
output "lake_bucket_name" { value = module.app.lake_bucket_name }
output "dagster_cluster_name" { value = module.app.dagster_cluster_name }
output "dagster_agent_role_arn" { value = module.app.dagster_agent_role_arn }
output "dagster_run_role_arn" { value = module.app.dagster_run_role_arn }
output "compute_role_arn" { value = module.app.compute_role_arn }
output "dagster_url" { value = module.app.dagster_url }
