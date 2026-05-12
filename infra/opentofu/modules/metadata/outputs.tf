output "endpoint" {
  value = aws_db_instance.metadata.endpoint
}

output "host" {
  value = aws_db_instance.metadata.address
}

output "port" {
  value = aws_db_instance.metadata.port
}

output "db_name" {
  value = aws_db_instance.metadata.db_name
}

output "master_secret_arn" {
  value = aws_db_instance.metadata.master_user_secret[0].secret_arn
}

output "identifier" {
  value       = aws_db_instance.metadata.identifier
  description = "RDS instance identifier; used by consumers to scope rds-db:connect IAM policies."
}

output "resource_id" {
  value       = aws_db_instance.metadata.resource_id
  description = "RDS resource id; used in rds-db:connect ARNs."
}

output "arn" {
  value = aws_db_instance.metadata.arn
}

output "sg_id" {
  value = aws_security_group.metadata.id
}
