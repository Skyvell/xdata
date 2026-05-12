output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "subnet_ids" {
  value = data.aws_subnets.default.ids
}

output "route_table_ids" {
  value = data.aws_route_tables.default.ids
}
