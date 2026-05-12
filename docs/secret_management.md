````markdown
# Final Secrets Plan

## Shared Naming Convention

```text
DUCKLAKE_*   shared by dlt + SQLMesh
SQLMESH_*    SQLMesh-only state/config
DLT_*        dlt-only pipeline/source config
AWS_*        AWS runtime/credential-chain config
````

---

# Secrets Manager

```text
ducklake/catalog
```

Secret contents:

```json
{
  "DUCKLAKE_HOST": "your-rds-host",
  "DUCKLAKE_PORT": "5432",
  "DUCKLAKE_DB": "metadata",
  "DUCKLAKE_USER": "ducklake_admin",
  "DUCKLAKE_PASSWORD": "your-password",
  "DUCKLAKE_METADATA_SCHEMA": "ducklake",
  "DUCKLAKE_DATA_PATH": "s3://your-bucket/ducklake/",
  "AWS_REGION": "eu-north-1"
}
```

---

# Runtime Approach

```text
1. Store Postgres password in AWS Secrets Manager.
2. Inject the secret values as env vars into the runtime.
3. Do not store/export one full connection URI.
4. Let dlt and SQLMesh compose the DuckLake catalog connection internally.
5. Use IAM role / credential_chain for S3 access.
6. Restrict debug/config logging because SQLMesh still builds a password-bearing connection string at runtime.
```

---

# SQLMesh

```yaml
catalogs:
  lake:
    type: ducklake

    path: "postgres:host={{ env_var('DUCKLAKE_HOST') }} port={{ env_var('DUCKLAKE_PORT') }} dbname={{ env_var('DUCKLAKE_DB') }} user={{ env_var('DUCKLAKE_USER') }} password={{ env_var('DUCKLAKE_PASSWORD') }} sslmode=require"

    data_path: "{{ env_var('DUCKLAKE_DATA_PATH') }}"

    metadata_schema: "{{ env_var('DUCKLAKE_METADATA_SCHEMA') }}"
```

---

# dlt

```python
catalog = (
    f"postgres:host={os.environ['DUCKLAKE_HOST']} "
    f"port={os.environ.get('DUCKLAKE_PORT', '5432')} "
    f"dbname={os.environ['DUCKLAKE_DB']} "
    f"user={os.environ['DUCKLAKE_USER']} "
    f"password={os.environ['DUCKLAKE_PASSWORD']} "
    f"sslmode=require"
)
```

---

# Production Choice

```text
Postgres auth: Secrets Manager password
S3 auth: IAM role / AWS credential chain
IAM token: only for dev or short CI jobs
```

```
```
