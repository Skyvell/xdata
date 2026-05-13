resource "aws_security_group" "dagster" {
  name        = "ducklake-dagster"
  description = "Dagster agent and run tasks (egress only)"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_vpc_security_group_egress_rule" "dagster_all" {
  security_group_id = aws_security_group.dagster.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "All egress"
}

resource "aws_vpc_security_group_ingress_rule" "dagster_self_grpc" {
  security_group_id            = aws_security_group.dagster.id
  ip_protocol                  = "tcp"
  from_port                    = 4000
  to_port                      = 4000
  referenced_security_group_id = aws_security_group.dagster.id
  description                  = "Agent to code-location server gRPC"
}

resource "aws_vpc_security_group_ingress_rule" "catalog_from_dagster" {
  security_group_id            = var.catalog_sg_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.dagster.id
  description                  = "Postgres from Dagster runs"
}
