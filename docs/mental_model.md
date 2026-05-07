````markdown
# DuckLake AWS Naming

## Resources

```text
RDS instance:
  ducklake-catalog

PostgreSQL database:
  ducklake_catalog

PostgreSQL schemas:
  dev_ted
  ci
  prod

S3 bucket:
  ducklake-data-<aws-account-id>

S3 prefixes:
  dev/ted/
  ci/
  prod/
````

## Terraform names

```hcl
data "aws_caller_identity" "current" {}

resource "aws_db_instance" "ducklake_catalog" {
  identifier = "ducklake-catalog"
  db_name    = "ducklake_catalog"
}

resource "aws_s3_bucket" "ducklake_data" {
  bucket = "ducklake-data-${data.aws_caller_identity.current.account_id}"
}
```

## Mental model

```text
DuckLake
├── ducklake-catalog  = RDS/PostgreSQL catalog
└── ducklake-data     = S3 Parquet data
```

## Isolation model

Use one AWS account for now, with isolation by:

```text
PostgreSQL schema
S3 prefix
```

Example:

```text
Ted local dev:
  PostgreSQL schema: dev_ted
  S3 prefix: dev/ted/

CI:
  PostgreSQL schema: ci
  S3 prefix: ci/

Production:
  PostgreSQL schema: prod
  S3 prefix: prod/
```

```
```
