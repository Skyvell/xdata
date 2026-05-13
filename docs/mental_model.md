# DuckLake AWS Naming

Keep the first setup simple:

```text
one AWS account = one DuckLake deployment
```

Multiple environments (dev, prod, ...) live in **separate AWS accounts**, each
running this same module. The account boundary IS the environment.

## Resources

```text
RDS instance:
  metadata

PostgreSQL database:
  metadata

PostgreSQL user:
  metadata_admin   (RDS-managed master; password in Secrets Manager)

S3 bucket:
  ducklake-<aws-account-id>

State bucket:
  tofu-state-<aws-account-id>
```

## Mental model

DuckLake has two parts:

```text
Catalogue metadata:
  RDS/PostgreSQL  (database `metadata`)

Table data:
  S3 Parquet files  (bucket `ducklake-<account-id>`)
```

Per AWS account:

```text
DuckLake (this account)
├── Catalogue
│   └── RDS instance: metadata
│       └── PostgreSQL database: metadata
└── Data
    └── S3 bucket: ducklake-<aws-account-id>
```

## Access model

Start with one PostgreSQL user:

```text
metadata_admin
```

RDS auto-creates this user as the master at instance creation. The password is
stored in the RDS-managed Secrets Manager secret. Everything (dlt, SQLMesh,
DuckDB UI, future Dagster/ECS) connects as this user.

No bootstrap SQL needed — the database is auto-created and owned by
`metadata_admin` on first apply.

## Python attach

```python
import duckdb

con = duckdb.connect()

con.sql("INSTALL ducklake")
con.sql("INSTALL postgres")
con.sql("INSTALL httpfs")

con.sql("LOAD ducklake")
con.sql("LOAD postgres")
con.sql("LOAD httpfs")

con.sql("""
    CREATE OR REPLACE SECRET s3_ducklake (
        TYPE s3,
        PROVIDER credential_chain,
        REGION 'eu-north-1'
    );
""")

con.sql("""
    ATTACH 'ducklake:postgres:sslmode=require'
    AS lake
    (DATA_PATH 's3://ducklake-<aws-account-id>/', METADATA_SCHEMA 'ducklake');
""")

con.sql("USE lake")
```

The DSN omits host/db/user/password — libpq reads them from standard env vars
(`PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`), which the runner's
task definition injects from the RDS-managed master secret. Keeping creds out
of the SQL literal also dodges a SQLMesh quoting bug where the ATTACH path
isn't escaped before being embedded in a single-quoted string literal.

## DuckLake schemas

Use DuckLake schemas for data organization:

```text
raw
staging
marts
```

Example:

```sql
CREATE SCHEMA raw;
CREATE SCHEMA staging;
CREATE SCHEMA marts;
```

## Future developer sandboxes

If multiple developers write their own data inside the same dev account, add
sandbox schemas:

```text
sandbox_ted
sandbox_anna
sandbox_ci
```

Layout:

```text
metadata
├── raw
├── staging
├── marts
├── sandbox_ted
├── sandbox_anna
└── sandbox_ci
```

Corresponding S3 layout:

```text
s3://ducklake-<aws-account-id>/
├── raw/
├── staging/
├── marts/
├── sandbox_ted/
├── sandbox_anna/
└── sandbox_ci/
```

## Later environments

Add a new AWS account when you need a new environment:

```text
prod account → its own RDS `ducklake`, its own bucket `ducklake-<prod-account-id>`
```

Same module, same names. Account ID provides global S3 uniqueness. Tofu
deploys identically across accounts.

## Later role split

Start with:

```text
metadata_admin
```

Split only when needed:

```text
metadata_admin
ducklake_writer
ducklake_reader
```
