resource "aws_db_subnet_group" "catalog" {
  name       = "ducklake-catalog"
  subnet_ids = data.aws_subnets.default.ids
  tags       = local.tags
}

resource "aws_db_instance" "catalog" {
  identifier     = "ducklake"
  engine         = "postgres"
  engine_version = "16.13"
  instance_class = var.catalog_instance_class

  db_name                     = "metadata"
  username                    = "ducklake_admin"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.catalog.name
  vpc_security_group_ids = [aws_security_group.catalog.id]

  storage_type      = "gp3"
  allocated_storage = 20

  # TODO: harden once we move to private RDS + SSM tunnel / VPC-only access.
  publicly_accessible = true
  multi_az            = var.catalog_multi_az

  backup_retention_period   = var.catalog_backup_retention_period
  skip_final_snapshot       = var.catalog_skip_final_snapshot
  final_snapshot_identifier = "ducklake-final"
  deletion_protection       = var.catalog_deletion_protection

  tags = local.tags
}
