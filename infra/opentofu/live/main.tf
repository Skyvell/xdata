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

module "metadata" {
  source = "../modules/metadata"

  vpc_id     = module.networking.vpc_id
  subnet_ids = module.networking.subnet_ids

  allowed_cidrs           = var.metadata_allowed_cidrs
  instance_class          = var.metadata_instance_class
  multi_az                = var.metadata_multi_az
  backup_retention_period = var.metadata_backup_retention_period
  skip_final_snapshot     = var.metadata_skip_final_snapshot
  deletion_protection     = var.metadata_deletion_protection

  tags = local.tags
}

module "lake" {
  source = "../modules/lake"

  tags = local.tags
}

module "runner" {
  source = "../modules/runner"

  region     = var.region
  vpc_id     = module.networking.vpc_id
  subnet_ids = module.networking.subnet_ids

  catalog_sg_id             = module.metadata.sg_id
  catalog_resource_id       = module.metadata.resource_id
  catalog_arn               = module.metadata.arn
  catalog_host              = module.metadata.host
  catalog_port              = module.metadata.port
  catalog_db_name           = module.metadata.db_name
  catalog_master_secret_arn = module.metadata.master_secret_arn
  lake_data_path            = module.lake.data_path
  lake_bucket_arn           = module.lake.bucket_arn

  image_tag = var.runner_image_tag

  schedules = {
    daily = {
      schedule_expression = "rate(1 day)"
      command = ["sh", "-c",
        "python -m xdata_ingestion.pipeline && sqlmesh -p transform plan --auto-apply --no-prompts"
      ]
    }
  }

  tags = local.tags
}
