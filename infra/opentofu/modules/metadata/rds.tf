resource "aws_db_subnet_group" "metadata" {
  name       = "metadata"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_db_instance" "metadata" {
  # TODO: rename to the chosen app name once decided. This instance hosts
  # both the DuckLake catalog and (planned) SQLMesh state, so "metadata" is
  # the function-based interim name.
  identifier     = "metadata"
  engine         = "postgres"
  engine_version = "16.13"
  instance_class = var.instance_class

  db_name                     = "metadata"
  username                    = "metadata_admin"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.metadata.name
  vpc_security_group_ids = [aws_security_group.metadata.id]

  storage_type      = "gp3"
  allocated_storage = 20

  # TODO: harden once we move to private RDS + SSM tunnel / VPC-only access.
  publicly_accessible                 = true
  multi_az                            = var.multi_az
  iam_database_authentication_enabled = true
  apply_immediately                   = true

  backup_retention_period   = var.backup_retention_period
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = "metadata-final"
  deletion_protection       = var.deletion_protection

  tags = var.tags
}
