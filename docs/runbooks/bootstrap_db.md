# Bootstrap `ducklake_app`

Create the `ducklake_app` role and the `ducklake` schema in the catalog
database. Required once per environment after `tofu apply`. Required again
after rotating `random_password.ducklake_app`.

## Prerequisites

- `aws` CLI authenticated against the target account.
- DuckDB CLI: `brew install duckdb`.
- Caller IP present in `catalog_allowed_cidrs` (`infra/config/<env>.tfvars`).

## Procedure

Substitute `<env>` and `<region>` throughout.

### 1. Master credentials

```bash
master_secret_arn=$(aws rds describe-db-instances \
  --db-instance-identifier "xdata-<env>-catalog" \
  --region <region> \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text)

aws secretsmanager get-secret-value \
  --secret-id "$master_secret_arn" \
  --region <region> --query SecretString --output text | jq .
```

Yields `username`, `password`.

### 2. Application credentials

```bash
aws secretsmanager get-secret-value \
  --secret-id "/xdata/<env>/ducklake/catalog" \
  --region <region> --query SecretString --output text | jq .
```

Yields `host`, `port`, `database`, `username`, `password`.

### 3. DDL via DuckDB

`duckdb -ui`, then:

```sql
INSTALL postgres;
LOAD postgres;

ATTACH 'host=<host> port=<port> dbname=<database>
        user=<master_username> password=<master_password> sslmode=require'
  AS pg (TYPE postgres);

CALL postgres_execute('pg', $$
DO $do$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'ducklake_app') THEN
    CREATE USER ducklake_app WITH PASSWORD '<app_password>';
  ELSE
    ALTER USER ducklake_app WITH PASSWORD '<app_password>';
  END IF;
END$do$;
$$);

CALL postgres_execute('pg', 'GRANT CONNECT ON DATABASE ducklake TO ducklake_app');
CALL postgres_execute('pg', 'CREATE SCHEMA IF NOT EXISTS ducklake AUTHORIZATION ducklake_app');
```

Statements are idempotent.

## Verification

```sql
SELECT * FROM postgres_query('pg', $$
  SELECT rolname FROM pg_roles WHERE rolname = 'ducklake_app'
$$);

SELECT * FROM postgres_query('pg', $$
  SELECT nspname, nspowner::regrole AS owner
  FROM pg_namespace WHERE nspname = 'ducklake'
$$);
```

Expected: one row from each query; schema owner equals `ducklake_app`.

End-to-end via DuckLake:

```sql
DETACH pg;
INSTALL ducklake;
LOAD ducklake;

ATTACH 'postgres:dbname=<database> host=<host> port=<port>
        user=ducklake_app password=<app_password> sslmode=require'
  AS lake (TYPE ducklake, DATA_PATH 's3://xdata-<env>-lake/');

USE lake;
SHOW SCHEMAS;
```

Expected: `ducklake` listed.
