resource "aws_db_subnet_group" "catalog" {
  name       = "${local.prefix}-catalog"
  subnet_ids = data.aws_subnets.default.ids
  tags       = local.tags
}

resource "aws_db_instance" "catalog" {
  identifier     = "${local.prefix}-catalog"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.catalog_instance_class

  db_name                     = "ducklake"
  username                    = "ducklake"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.catalog.name
  vpc_security_group_ids = [aws_security_group.catalog.id]

  storage_type      = "gp3"
  allocated_storage = 20

  skip_final_snapshot = true
  deletion_protection = false

  tags = local.tags
}
