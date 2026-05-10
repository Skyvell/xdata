module "app" {
  source = "../modules/app"

  region = var.region

  catalog_instance_class          = var.catalog_instance_class
  catalog_multi_az                = var.catalog_multi_az
  catalog_backup_retention_period = var.catalog_backup_retention_period
  catalog_skip_final_snapshot     = var.catalog_skip_final_snapshot
  catalog_deletion_protection     = var.catalog_deletion_protection
  catalog_allowed_cidrs           = var.catalog_allowed_cidrs
}

output "catalog_endpoint" { value = module.app.catalog_endpoint }
output "catalog_master_secret_arn" { value = module.app.catalog_master_secret_arn }
output "lake_bucket_name" { value = module.app.lake_bucket_name }
