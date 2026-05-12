variable "vpc_id" {
  type        = string
  description = "VPC the security group is attached to."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets used by the RDS subnet group."
}

variable "allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed inbound on the Postgres port."
  default     = []
}

variable "instance_class" {
  type        = string
  description = "RDS instance class."
  default     = "db.t4g.micro"
}

variable "multi_az" {
  type        = bool
  description = "Enable Multi-AZ for the RDS instance."
  default     = false
}

variable "backup_retention_period" {
  type        = number
  description = "Number of days to retain automated RDS backups. 0 disables backups."
  default     = 0
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Skip final snapshot when the RDS instance is destroyed."
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection on the RDS instance."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources in this module."
  default     = {}
}
