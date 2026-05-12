locals {
  tags = {
    project = "ducklake"
    managed = "opentofu"
  }
}

module "networking" {
  source = "../modules/networking"

  region = var.region
  tags   = local.tags
}

module "ducklake" {
  source = "../modules/ducklake"

  vpc_id     = module.networking.vpc_id
  subnet_ids = module.networking.subnet_ids

  allowed_cidrs                   = var.catalog_allowed_cidrs
  catalog_instance_class          = var.catalog_instance_class
  catalog_multi_az                = var.catalog_multi_az
  catalog_backup_retention_period = var.catalog_backup_retention_period
  catalog_skip_final_snapshot     = var.catalog_skip_final_snapshot
  catalog_deletion_protection     = var.catalog_deletion_protection

  tags = local.tags
}
