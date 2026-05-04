module "app" {
  source = "../modules/app"

  env    = var.env
  region = var.region

  catalog_instance_class          = var.catalog_instance_class
  catalog_multi_az                = var.catalog_multi_az
  catalog_backup_retention_period = var.catalog_backup_retention_period
  catalog_skip_final_snapshot     = var.catalog_skip_final_snapshot
  catalog_deletion_protection     = var.catalog_deletion_protection
}

output "catalog_endpoint" { value = module.app.catalog_endpoint }
output "lake_bucket_name" { value = module.app.lake_bucket_name }
output "compute_role_arn" { value = module.app.compute_role_arn }
