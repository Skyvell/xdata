data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_caller_identity" "current" {}

resource "aws_security_group" "catalog" {
  name   = "ducklake-catalog"
  vpc_id = data.aws_vpc.default.id
  tags   = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "catalog_postgres" {
  for_each = toset(var.catalog_allowed_cidrs)

  security_group_id = aws_security_group.catalog.id
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
  cidr_ipv4         = each.value
  description       = "Postgres from allowed CIDR"
}

resource "aws_security_group" "dagster" {
  name        = "ducklake-dagster"
  description = "Dagster agent and run tasks (egress only)"
  vpc_id      = data.aws_vpc.default.id
  tags        = local.tags
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
  description                  = "Agent -> code-location server gRPC"
}

resource "aws_vpc_security_group_ingress_rule" "catalog_from_dagster" {
  security_group_id            = aws_security_group.catalog.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.dagster.id
  description                  = "Postgres from Dagster runs"
}

data "aws_route_tables" "default" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.default.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.default.ids
  tags              = local.tags
}
