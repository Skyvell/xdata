# Secrets & runtime env

## Where secrets live

The RDS instance is created with `manage_master_user_password = true`, so the
master password is stored in an AWS-managed Secrets Manager secret. Nothing
about the password is in code, OpenTofu state, or env at rest — it's pulled at
container start time by the ECS execution role.

```text
RDS-managed secret
└── { "username": "metadata_admin", "password": "<random>" }
```

## How env vars are exposed to the runner

The runner ECS task definition reads two JSON keys out of the secret and
exposes them, along with a handful of plain values, as container env vars.
Postgres connection params follow libpq's standard names so any pg-aware
tool (psql, psycopg2, dlt, DuckDB's postgres extension) works without
translation; DuckLake-specific values keep their own prefix.

```text
PGHOST                      RDS endpoint
PGPORT                      5432
PGDATABASE                  metadata
PGUSER                      metadata_admin            (from secret)
PGPASSWORD                  <random>                  (from secret)

DUCKLAKE_METADATA_SCHEMA    ducklake
DUCKLAKE_DATA_PATH          s3://ducklake-<account-id>/

AWS_REGION                  eu-north-1
```

S3 access uses the AWS credential chain via the Fargate task role — no AWS
keys in env or code.

## What that lets the code do

dlt and SQLMesh both compose the DuckLake catalog connection from those env
vars (see `ingestion/src/xdata_ingestion/ducklake.py` and
`transform/config.py`). DuckDB's `ATTACH 'ducklake:postgres:sslmode=require'`
relies on libpq picking up the rest from `PG*`, keeping credentials out of
the SQL literal entirely.
