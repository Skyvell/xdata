resource "random_password" "app" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "catalog" {
  name        = "/xdata/${var.env}/ducklake/catalog"
  description = "DuckLake catalog connection for the app user."

  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "catalog" {
  secret_id = aws_secretsmanager_secret.catalog.id
  secret_string = jsonencode({
    host     = aws_db_instance.catalog.address
    port     = aws_db_instance.catalog.port
    database = aws_db_instance.catalog.db_name
    username = "app"
    password = random_password.app.result
  })
}
