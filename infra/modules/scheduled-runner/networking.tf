resource "aws_security_group" "runner" {
  name        = "ducklake-runner"
  description = "Short-lived DuckLake runner tasks"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_vpc_security_group_egress_rule" "runner_all" {
  security_group_id = aws_security_group.runner.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "All egress"
}

resource "aws_vpc_security_group_ingress_rule" "catalog_from_runner" {
  security_group_id            = var.catalog_sg_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.runner.id
  description                  = "Postgres from scheduled runner tasks"
}
