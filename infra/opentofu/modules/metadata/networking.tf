resource "aws_security_group" "metadata" {
  name   = "metadata"
  vpc_id = var.vpc_id
  tags   = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "metadata_postgres" {
  for_each = toset(var.allowed_cidrs)

  security_group_id = aws_security_group.metadata.id
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
  cidr_ipv4         = each.value
  description       = "Postgres from allowed CIDR"
}
