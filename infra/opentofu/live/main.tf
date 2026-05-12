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

module "scheduled_runner" {
  source = "../modules/scheduled-runner"

  region     = var.region
  vpc_id     = module.networking.vpc_id
  subnet_ids = module.networking.subnet_ids

  catalog_sg_id             = module.ducklake.catalog_sg_id
  catalog_resource_id       = module.ducklake.catalog_resource_id
  catalog_arn               = module.ducklake.catalog_arn
  catalog_host              = module.ducklake.catalog_address
  catalog_port              = module.ducklake.catalog_port
  catalog_db_name           = module.ducklake.catalog_db_name
  catalog_master_secret_arn = module.ducklake.catalog_master_secret_arn
  lake_data_path            = module.ducklake.lake_data_path
  lake_bucket_arn           = module.ducklake.lake_bucket_arn

  image_tag = var.runner_image_tag

  schedules = {
    coingecko = {
      schedule_expression = "rate(1 day)"
      command             = ["python", "-m", "xdata_ingestion.pipeline"]
    }
  }

  tags = local.tags
}
