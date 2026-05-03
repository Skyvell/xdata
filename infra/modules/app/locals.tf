locals {
  prefix = "xdata-${var.env}"
  tags = {
    env     = var.env
    project = "xdata"
    managed = "opentofu"
  }
}
