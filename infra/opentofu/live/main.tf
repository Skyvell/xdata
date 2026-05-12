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

module "dagster" {
  source = "../modules/dagster"

  region              = var.region
  vpc_id              = module.networking.vpc_id
  subnet_ids          = module.networking.subnet_ids
  catalog_sg_id       = module.ducklake.catalog_sg_id
  catalog_resource_id = module.ducklake.catalog_resource_id
  catalog_arn         = module.ducklake.catalog_arn
  lake_bucket_arn     = module.ducklake.lake_bucket_arn

  dagster_org_slug                = var.dagster_org_slug
  dagster_deployment              = var.dagster_deployment
  dagster_agent_image             = var.dagster_agent_image
  dagster_agent_token_secret_name = var.dagster_agent_token_secret_name
  dagster_agent_cpu               = var.dagster_agent_cpu
  dagster_agent_memory            = var.dagster_agent_memory
  dagster_agent_replicas          = var.dagster_agent_replicas
  dagster_server_cpu              = var.dagster_server_cpu
  dagster_server_memory           = var.dagster_server_memory
  dagster_run_cpu                 = var.dagster_run_cpu
  dagster_run_memory              = var.dagster_run_memory

  tags = local.tags
}
