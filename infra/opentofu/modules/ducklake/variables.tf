variable "vpc_id" {
  type        = string
  description = "VPC the catalog security group is attached to."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets used by the RDS catalog subnet group."
}

variable "allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed inbound on the catalog Postgres port."
  default     = []
}

variable "catalog_instance_class" {
  type        = string
  description = "RDS instance class for the catalog database."
  default     = "db.t4g.micro"
}

variable "catalog_multi_az" {
  type        = bool
  description = "Enable Multi-AZ for the catalog RDS instance."
  default     = false
}

variable "catalog_backup_retention_period" {
  type        = number
  description = "Number of days to retain automated RDS backups. 0 disables backups."
  default     = 0
}

variable "catalog_skip_final_snapshot" {
  type        = bool
  description = "Skip final snapshot when the catalog RDS instance is destroyed."
  default     = true
}

variable "catalog_deletion_protection" {
  type        = bool
  description = "Enable deletion protection on the catalog RDS instance."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources in this module."
  default     = {}
}
