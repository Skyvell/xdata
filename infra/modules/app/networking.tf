data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "catalog" {
  name   = "${local.prefix}-catalog"
  vpc_id = data.aws_vpc.default.id
  tags   = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "catalog_postgres" {
  security_group_id = aws_security_group.catalog.id
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
  cidr_ipv4         = data.aws_vpc.default.cidr_block
}
