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
