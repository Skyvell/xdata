variable "env" {
  type = string
}

variable "region" {
  type = string
}

variable "catalog_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "features" {
  type    = object({})
  default = {}
}
