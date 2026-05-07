# Bootstrap `ducklake_app`

Create the `ducklake_app` role with permissions to initialize and manage the
DuckLake catalog. Required once per environment after `tofu apply`.

DuckLake stores its metadata in the `public` schema by default, so no extra
schema is created.

## Prerequisites

- `aws` CLI authenticated against the target account.
- [TablePlus](https://tableplus.com/) (or any PostgreSQL client).
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

### 3. Connect as master

In TablePlus: new connection → PostgreSQL.

- Host, Port, Database: from step 2
- User, Password: from step 1
- SSL Mode: **Require**

### 4. Run the SQL

```sql
CREATE USER ducklake_app WITH PASSWORD '<app_password>';
GRANT CREATE ON DATABASE ducklake TO ducklake_app;
GRANT CREATE, USAGE ON SCHEMA public TO ducklake_app;
```

To rotate the password later (after `tofu taint random_password.ducklake_app` + `tofu apply`):

```sql
ALTER USER ducklake_app WITH PASSWORD '<new_password>';
```

## Verification

```sql
SELECT rolname FROM pg_roles WHERE rolname = 'ducklake_app';

SELECT has_database_privilege('ducklake_app', 'ducklake', 'CREATE') AS db_create,
       has_schema_privilege('ducklake_app', 'public', 'CREATE')     AS public_create,
       has_schema_privilege('ducklake_app', 'public', 'USAGE')      AS public_usage;
```

Expected: role exists; all three privilege columns return `true`.

## End-to-end check (optional)

Confirm DuckLake initializes against the catalog. Requires DuckDB CLI
(`brew install duckdb`).

```bash
duckdb -ui
```

```sql
INSTALL ducklake;
LOAD ducklake;

ATTACH 'postgres:dbname=<database> host=<host> port=<port>
        user=ducklake_app password=<app_password> sslmode=require'
  AS lake (TYPE ducklake, DATA_PATH 's3://xdata-<env>-lake/');

USE lake;
SHOW SCHEMAS;
```

Expected: attach succeeds; default schemas listed.
