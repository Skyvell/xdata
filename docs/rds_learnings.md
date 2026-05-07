# Final plan: simple, secure data platform

## Stack

- Dagster+ Hybrid on AWS ECS Fargate
- dlt for API ingestion
- SQLMesh for transformations
- DuckDB + DuckLake
- RDS PostgreSQL as DuckLake catalog
- S3 as DuckLake data storage
- AWS Secrets Manager for production secrets
- SSM tunnel for local database access
- CloudWatch Logs
- OpenTofu

## Architecture

```text
External APIs
  -> dlt ingestion
  -> DuckLake raw tables
  -> SQLMesh transformations
  -> DuckLake staging/marts tables
```

```text
Dagster+ control plane
  -> ECS Fargate Dagster+ Hybrid agent
  -> ECS Fargate run task
      -> runs dlt
      -> runs SQLMesh
      -> uses DuckDB + DuckLake
      -> connects to private RDS PostgreSQL
      -> reads/writes S3
      -> reads prod secrets from Secrets Manager
      -> logs to CloudWatch
```

## AWS resources

Use:

* One AWS account
* One VPC
* One ECS Fargate cluster
* One Dagster+ Hybrid deployment
* One ECR repo
* One private RDS PostgreSQL instance
* One S3 bucket
* One small EC2 instance for SSM tunnel
* AWS Secrets Manager
* CloudWatch Logs
* OpenTofu

Avoid:

* Public RDS
* EKS / Kubernetes
* Airflow
* Multiple AWS accounts
* Separate staging infrastructure
* NAT Gateway unless truly needed
* RDS master user for app jobs

## Storage layout

```text
RDS PostgreSQL:
  database: ducklake
  publicly_accessible: false

S3:
  s3://my-ducklake/prod/raw/
  s3://my-ducklake/prod/staging/
  s3://my-ducklake/prod/marts/

  s3://my-ducklake/dev/ted/raw/
  s3://my-ducklake/dev/ted/staging/
  s3://my-ducklake/dev/ted/marts/
```

SQLMesh environments:

```text
prod      -> production data
dev_ted   -> local development data
```

## Database users

```text
ducklake_app
  Used by Dagster/ECS production jobs, local development, and inspection
  dlt, SQLMesh, TablePlus, and DuckDB UI all connect as this user
  Prod vs dev isolation comes from DATA_PATH (S3 prefix), not DB grants
```

The RDS master user (managed by Secrets Manager) is for admin/migrations only.

## Network access

RDS stays private:

```text
RDS publicly_accessible = false
```

RDS security group allows inbound `5432` only from:

```text
- ECS task security group
- SSM tunnel EC2 security group
```

Local access:

```text
Laptop
  -> SSM tunnel
  -> private RDS PostgreSQL
```

## Secrets

### Local

Keep local access simple with `.env.dev`. Use dlt's native env var conventions so dlt picks them up automatically — no bridge code:

```bash
# dlt DuckLake destination (dlt resolves these automatically)
DESTINATION__DUCKLAKE__CREDENTIALS__CATALOG=postgres://ducklake_app:<password>@127.0.0.1:5432/ducklake
DESTINATION__DUCKLAKE__CREDENTIALS__STORAGE=s3://my-ducklake/dev/ted/

SQLMESH_ENVIRONMENT=dev_ted

AWS_PROFILE=xdata-dev
AWS_REGION=eu-north-1
```

`.gitignore`:

```gitignore
.env
.env.*
!.env.example
```

Commit only `.env.example`.

### Production

Use AWS Secrets Manager for:

```text
/xdata/prod/ducklake/catalog
/xdata/prod/apis/github
/xdata/prod/apis/stripe
/xdata/prod/apis/vendor_x
```

Example DuckLake secret:

```json
{
  "host": "my-rds.xxxxxx.eu-north-1.rds.amazonaws.com",
  "port": "5432",
  "database": "ducklake",
  "username": "ducklake_app",
  "password": "..."
}
```

Use Parameter Store later only for non-secret config if needed.

## Authentication model

### Local dlt

```text
API auth: .env.dev / local test token
DuckLake catalog auth: .env.dev + SSM tunnel
S3 auth: local AWS profile
Writes to: s3://my-ducklake/dev/ted/
DB user: ducklake_app
```

### Production dlt

```text
API auth: AWS Secrets Manager
DuckLake/RDS auth: AWS Secrets Manager
S3 auth: ECS task IAM role
Writes to: s3://my-ducklake/prod/raw/
DB user: ducklake_app
```

### Local SQLMesh

```bash
sqlmesh --dotenv .env.dev plan dev_ted --select my_model
```

### Production SQLMesh

```text
Runs through Dagster/ECS
SQLMESH_ENVIRONMENT=prod
DESTINATION__DUCKLAKE__CREDENTIALS__STORAGE=s3://my-ducklake/prod/
DuckLake catalog credentials from Secrets Manager
S3 permissions from ECS task IAM role
```

## Dagster job shape

```text
daily_pipeline
  -> dlt_ingest_apis
  -> sqlmesh_run_prod
  -> quality_checks
  -> notify_on_failure
```

Responsibility split:

```text
dlt      = API extraction/loading
SQLMesh  = SQL transformations, plans, environments, audits
Dagster  = scheduling, orchestration, retries, observability
DuckLake = catalog/table layer over S3
DuckDB   = execution engine
AWS      = runtime, storage, secrets, networking
```

## Local workflow

```bash
just tunnel
cd ingestion && uv run python -m xdata_ingestion.pipeline
sqlmesh --dotenv .env.dev plan dev_ted --select my_model
```

For inspection:

```text
TablePlus:
  Host: 127.0.0.1
  Port: 5432
  User: ducklake_app

DuckDB Local UI:
  duckdb -ui
```

## Docker image

Include:

```text
dagster
dagster-cloud
dlt
sqlmesh
duckdb
boto3
api-specific dependencies
```

Use immutable image tags:

```text
data-platform:<git-sha>
```

## Deployment flow

```text
Git push
  -> CI builds Docker image
  -> push image to ECR
  -> Dagster+ Hybrid uses image on ECS Fargate
  -> Dagster schedule runs dlt + SQLMesh + checks
```

## Security rules

```text
RDS is never public.
Local writes go to dev prefix via DATA_PATH.
Production writes run only through Dagster/ECS.
Production DB/API secrets live in Secrets Manager.
Local .env.dev is never committed.
Do not use the RDS master user for app jobs.
Use IAM roles for S3 access in ECS.
Do not use static AWS keys in ECS.
```

## Final summary

```text
One AWS account
One Dagster+ Hybrid deployment
One ECS Fargate cluster
One ECR repo
One private RDS PostgreSQL instance
One S3 bucket with prod/dev prefixes
One small SSM-accessible EC2 instance for local tunnel
AWS Secrets Manager for prod DB/API secrets
Local .env.dev with dlt-native env vars for dev access
dlt for API ingestion
SQLMesh for transformations
DuckDB + DuckLake for storage/querying
CloudWatch for logs
OpenTofu for infrastructure
```