module "app" {
  source = "../modules/app"

  env    = var.env
  region = var.region

  catalog_instance_class = var.catalog_instance_class
  features               = var.features
}

output "catalog_endpoint" { value = module.app.catalog_endpoint }
output "lake_bucket_name" { value = module.app.lake_bucket_name }
output "compute_role_arn" { value = module.app.compute_role_arn }
