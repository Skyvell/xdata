# OpenTofu project structure

Reference for structuring an OpenTofu project that deploys the xdata AWS foundation (VPC, DuckLake catalog on RDS Postgres, DuckLake data bucket on S3, IAM) to dev, int, and prod with isolated state and no duplicated HCL across environments.

---

## Layout

```
infra/
├── modules/app/
│   ├── variables.tf
│   ├── outputs.tf
│   ├── locals.tf
│   ├── networking.tf          # VPC, subnets, security groups
│   ├── catalog.tf             # RDS Postgres — DuckLake catalog
│   ├── lake.tf                # S3 bucket — DuckLake data files
│   ├── iam.tf                 # roles for Dagster Cloud + CI
│   └── tests/basic.tftest.hcl
├── live/
│   ├── main.tf                # single module call
│   ├── variables.tf           # pass-through declarations
│   ├── providers.tf
│   └── backend.tf             # empty; filled at init
├── config/
│   ├── {dev,int,prod}.tfvars
│   └── {dev,int,prod}.s3.tfbackend
├── .tflint.hcl
└── trivy.yaml
```

OpenTofu merges every `.tf` in a directory, so splitting the module by concern keeps files focused without spawning separate state. `live/` is the only directory `tofu` runs in; `config/` is pure data — adding an environment means adding two files. Commit `.terraform.lock.hcl` for reproducible `init`. Per-account foundation (state bucket, OIDC provider, deploy roles) is set up once, out-of-band.

---

## Environments as data

Environments differ only through `.tfvars` values and backend configuration. Resist `env == "prod"` branches inside the module — add a variable or a field on a `features` object instead.

```hcl
# config/dev.tfvars
environment            = "dev"
catalog_instance_class = "db.t4g.micro"
vpc_cidr               = "10.0.0.0/16"
features = {
  catalog_multi_az            = false
  catalog_deletion_protection = false
  lake_bucket_versioning      = true
}
```

```hcl
# config/dev.s3.tfbackend
bucket       = "xdata-tofu-state"
key          = "dev/opentofu.tfstate"
region       = "eu-north-1"
kms_key_id   = "arn:aws:kms:eu-north-1:000000000000:key/…"
use_lockfile = true
encrypt      = true
```

Only `key` varies across environments (`<env>/opentofu.tfstate`). `use_lockfile = true` replaces the deprecated DynamoDB lock table with S3 conditional writes; it requires bucket versioning.

---

## Root configuration

### live/backend.tf

Empty; `-backend-config=<env>.s3.tfbackend` fills it at init time, so no environment identifier appears in HCL.

```hcl
terraform {
  backend "s3" {}
}
```

### live/providers.tf

```hcl
terraform {
  required_version = "~> 1.11"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"

  default_tags {
    tags = {
      Project     = "xdata"
      Environment = var.environment
      ManagedBy   = "opentofu"
    }
  }
}
```

No `assume_role` block: GitHub Actions OIDC sets credentials before OpenTofu runs, with one deploy role per environment. `default_tags` covers every resource, so individual resources only declare tags unique to them (e.g. `Name`).

### live/main.tf

```hcl
module "app" {
  source = "../modules/app"

  environment            = var.environment
  catalog_instance_class = var.catalog_instance_class
  vpc_cidr               = var.vpc_cidr
  features               = var.features
}
```

---

## Module

One file per concern (networking, catalog, lake, iam). Resources reference each other through plain resource addresses; a module-level `name_prefix = "xdata-${var.environment}"` keeps resource names consistent (`xdata-dev-catalog`, `xdata-prod-lake`, etc.).

```hcl
# modules/app/variables.tf
variable "environment"            { type = string }
variable "catalog_instance_class" { type = string }
variable "vpc_cidr"               { type = string }
```

For optional per-environment behaviour, pass a single `features` object rather than scattering `environment == "prod"` checks across the module:

```hcl
variable "features" {
  type = object({
    catalog_multi_az            = bool
    catalog_deletion_protection = bool
    lake_bucket_versioning      = bool
  })
}
```

Outputs are the module's public surface — expose only what a caller needs to wire up the rest of the stack: `catalog_endpoint` (consumed by Dagster as the DuckLake `ATTACH` target), `lake_bucket_name` (DuckLake `DATA_PATH`), and `compute_role_arn` (the role Dagster Cloud assumes via OIDC). Nothing more.

Tests live in `modules/app/tests/*.tftest.hcl` and run with `tofu -chdir=infra/modules/app test`; use `mock_provider "aws" {}` so they require no credentials.
