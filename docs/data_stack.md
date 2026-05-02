# Modern Data Engineering Stack — April 2026

Reference architecture:

```
dlt → DuckLake (S3 + PostgreSQL) → SQLMesh on DuckDB → Cube.dev → LLM agents
```

Orchestrated by Dagster. Quality enforced by SQLMesh audits and Soda.

---

## 1. Ingestion — dlt

dlt is a Python-native ELT library that extracts from APIs, databases, and files and loads into DuckLake. It handles pagination, retries, incremental cursors, and schema inference and evolution on write. A pipeline is a Python file checked into Git — no separate connector infrastructure to host.

```python
import dlt

@dlt.resource(write_disposition="merge", primary_key="id")
def orders():
    yield from paginated_api_call("/orders")

pipeline = dlt.pipeline(
    pipeline_name="my_pipeline",
    destination="ducklake",
    dataset_name="raw",
)
pipeline.run(orders())
```

| Setting | Value |
|---|---|
| Destination | `ducklake` — `pip install "dlt[ducklake]"` |
| Write Disposition | `append`, `replace`, `merge` (Type 1), `scd2` (Type 2) |
| Incremental | Cursor-based and merge-based |
| File Format | Parquet |
| Schema Contracts | Enforce or evolve on write |
| Sources | 200+ verified connectors |

---

## 2. Storage & Table Format — DuckLake on S3 + PostgreSQL

DuckLake stores Parquet data files on S3 and all table metadata — schemas, column statistics, file locations, snapshots — in PostgreSQL. This replaces both Apache Iceberg and the Glue Catalog: the catalog *is* the metadata, so there are no manifest files or snapshot JSONs on object storage. Queries that would need multiple S3 round-trips under Iceberg become a single SQL query against PostgreSQL.

ACID transactions, schema evolution, time travel, and multi-table atomic commits are all expressed as catalog transactions. Small writes are held in the catalog and compacted to Parquet on a threshold-based flush, which avoids the small-file problem common to streaming workloads. DuckLake can import from and export to Iceberg for interop with engines that lack a native connector.

```sql
INSTALL ducklake;
LOAD ducklake;

ATTACH 'postgres:dbname=ducklake_catalog host=my-rds.amazonaws.com'
  AS my_lake (TYPE ducklake, DATA_PATH 's3://my-datalake/warehouse/');

SELECT * FROM my_lake.raw.orders AT (TIMESTAMP => '2026-03-01');
```

S3 layout — data files only, no metadata:

```
s3://my-datalake/warehouse/
  ├── raw/orders/       → Parquet
  ├── staging/stg_*     → Parquet
  └── marts/fct_*       → Parquet
```

| Setting | Value |
|---|---|
| Catalog Backend | PostgreSQL on RDS (~$15/month for db.t4g.micro) |
| Data Storage | S3 Standard (~$0.023/GB/month) |
| Data Format | Parquet with Snappy/Zstd compression |
| Data Inlining | Small writes held in PostgreSQL, compacted to S3 on threshold |
| Iceberg Interop | Bidirectional import/export |

---

## 3. Compute — DuckDB

DuckDB is the only query engine, in every environment. It runs in-process, reads DuckLake natively via the `ducklake` extension, and spills to disk when memory is exhausted.

There is no separate local data stack: every environment is on AWS, with its own RDS Postgres catalog and its own S3 bucket. Blast radius stays contained per env and IAM stays clean.

| Env | Compute | Catalog | Files |
|---|---|---|---|
| Dev | DuckDB + DuckLake | RDS Postgres (dev) | `s3://lake-dev/` |
| Int | DuckDB + DuckLake | RDS Postgres (int) | `s3://lake-int/` |
| Prod | DuckDB + DuckLake | RDS Postgres (prod) | `s3://lake-prod/` |

The DuckDB *process* runs wherever convenient — a laptop or Codespace for `sqlmesh plan dev` iteration, a CI runner for cross-env promotions, and AWS compute (Dagster Cloud or ECS, same region as RDS + S3) for scheduled production runs. Heavy ad-hoc queries should also run on AWS compute, not laptops, to avoid S3 egress.

SQLMesh virtual environments give cheap previews *within* a single env — only changed models are materialized, no data duplication. Promotion *across* envs happens via Git → CI running `sqlmesh plan <env> --apply` against the target's catalog and bucket. The SQLMesh state DB lives in a separate schema on the same per-env RDS instance.

Single-node scale has practical limits: a working set beyond roughly 10 TB, or concurrency beyond tens of heavy queries, is a signal to export the catalog to Iceberg and run Trino or Spark against the same S3 data.

| Setting | Value |
|---|---|
| Engine | DuckDB (Dev, Int, Prod) |
| Region | Single AWS region for catalog, files, and compute |
| Networking | VPC endpoint for S3; RDS via SG-scoped access or RDS Proxy |
| Memory | Spills to disk when RAM exhausted |
| Practical Ceiling | ~10 TB working set, tens of concurrent heavy queries |
| Migration Path | DuckLake → Iceberg export → Trino/Spark |

---

## 4. Transformation — SQLMesh

SQLMesh is the transformation framework. Models are declared with a `MODEL()` block that names kind (full refresh, incremental by time, etc.), grain, and inline audits. SQLMesh parses SQL to compute column-level lineage and categorize changes as breaking or non-breaking — non-breaking changes can be applied forward-only without reprocessing history. Virtual environments let model changes be tested against production data without copying tables or recomputing downstream.

The CLI follows a plan/apply workflow analogous to OpenTofu. DuckDB is natively supported, and existing dbt projects can be imported with `sqlmesh init --dbt`.

```sql
-- models/marts/fct_revenue.sql
MODEL (
  name marts.fct_revenue,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column order_date,
    batch_size 7,  -- backfill 7 days per batch
  ),
  grain (order_id),
  audits (
    accepted_range(column=revenue, min_v=0),
    not_null(columns=[order_id, customer_id]),
  ),
);

SELECT
    o.order_id,
    o.order_date,
    c.customer_segment,
    SUM(o.amount) AS revenue
FROM staging.stg_orders AS o
JOIN staging.stg_customers AS c USING (customer_id)
WHERE o.order_date BETWEEN @start_date AND @end_date
GROUP BY 1, 2, 3;
```

```bash
sqlmesh plan           # show column-level diff
sqlmesh apply          # execute
sqlmesh plan dev       # apply to virtual environment
sqlmesh diff prod dev  # compare environments
```

| Setting | Value |
|---|---|
| Engine | DuckDB (native) |
| Virtual Environments | Test changes without duplicating data |
| Column-Level Lineage | Auto-detected from SQL |
| Change Categorization | Breaking vs forward-only |
| Migration from dbt | `sqlmesh init --dbt` |
| Scheduler | Built-in cron, or driven from Dagster |
| Audits | Inline model checks, run on plan/apply |

---

## 5. Orchestration — Dagster

Dagster is the asset-based orchestrator. Each dlt source and each SQLMesh model surfaces as a data asset with dependencies, freshness policies, and materialization history. `dagster-dlt` is maintained by Dagster Labs; `dagster-sqlmesh` is a community-maintained package.

For a small team with a single pipeline, SQLMesh's built-in scheduler is sufficient. Dagster earns its place when there are multiple sources on different schedules, cross-system dependencies (dlt → SQLMesh → Cube refresh), per-asset freshness SLAs, or event-driven triggers such as S3 object creation.

```python
from dagster_dlt import DagsterDltResource, dlt_assets
from dagster_sqlmesh import sqlmesh_assets

@dlt_assets(
    dlt_source=my_api(),
    dlt_pipeline=pipeline,
    name="raw_data",
)
def raw_assets(context, dlt: DagsterDltResource):
    yield from dlt.run(context=context)

@sqlmesh_assets(config=sqlmesh_config)
def transform_assets(context): ...
```

| Setting | Value |
|---|---|
| Deployment | Dagster Cloud or self-hosted |
| Integrations | `dagster-dlt`, `dagster-sqlmesh` |
| Freshness Policies | Per-asset SLAs |
| Auto-Materialization | Trigger downstream on upstream refresh |
| Event Triggers | S3 events, webhooks |

---

## 6. Data Quality — SQLMesh Audits + Soda

Quality is enforced in two layers. SQLMesh audits are declared on models and block `apply` on failure — they catch structural violations (nulls, duplicates, out-of-range values) before bad data reaches downstream. Soda runs separately as a data observability layer: it monitors freshness, row-count anomalies, and schema drift, emitting alerts rather than blocking runs.

```sql
MODEL (
  name marts.fct_revenue,
  audits (
    not_null(columns=[order_id, revenue, order_date]),
    unique_values(columns=[order_id]),
    accepted_range(column=revenue, min_v=0, max_v=1000000),
  ),
);
```

```yaml
# soda/checks.yml
checks for raw.orders:
  - freshness(updated_at) < 6h
  - row_count > 0
  - anomaly detection for row_count   # requires Soda Cloud
  - schema:
      fail:
        when forbidden column present: [ssn, credit_card]

checks for marts.fct_revenue:
  - anomaly detection for avg(revenue)   # requires Soda Cloud
  - duplicate_count(order_id) = 0
  - failed rows:
      fail condition: revenue < 0
```

| Setting | Value |
|---|---|
| SQLMesh Audits | Blocking — run on plan/apply |
| Soda Core | Open source (`pip install soda-core-duckdb`) |
| Soda Cloud | Paid — dashboards, anomaly detection, alerts |
| Integration | Dagster sensor triggers Soda after each run |

---

## 7. Semantic Layer — Cube.dev

Cube defines business metrics once — measures, dimensions, joins — and exposes them via REST, GraphQL, and SQL APIs. Pre-aggregations (materialized rollups on a refresh schedule) serve most queries from cache without touching DuckDB. For LLM consumers this is load-bearing: a constrained semantic API prevents the model from fabricating metric definitions or writing invalid SQL.

```javascript
// cube/schema/Revenue.js
// `lake` is the DuckLake catalog attached in Cube's DuckDB driver config
cube('Revenue', {
  sql_table: 'lake.marts.fct_revenue',

  measures: {
    total_revenue: { type: 'sum', sql: 'revenue', format: 'currency' },
    order_count: { type: 'count' },
    avg_order_value: {
      type: 'number',
      sql: `${total_revenue} / NULLIF(${order_count}, 0)`,
    },
  },

  dimensions: {
    order_date: { type: 'time', sql: 'order_date' },
    customer_segment: { type: 'string', sql: 'customer_segment' },
  },
});
```

Pre-aggregations are declared in the same schema with a refresh interval. Cube materializes them to **Cube Store** (Parquet files on blob storage such as S3) and routes matching queries automatically.

| Setting | Value |
|---|---|
| Data Source | DuckDB via DuckLake |
| Caching | In-memory + pre-aggregations |
| APIs | REST, GraphQL, SQL |
| Deployment | Cube Cloud or self-hosted |
| Auth | JWT with role-based access control |

---

## 8. Consumers

The primary consumer is LLM agents querying Cube's API. Secondary consumers include BI dashboards, notebooks for ad-hoc analysis, and reverse ETL for operational use cases.

| Consumer | Interface |
|---|---|
| LLM agents | Cube REST/SQL API |
| BI dashboards | Evidence.dev (code-first) or Preset |
| Ad-hoc analysis | DuckDB CLI, Jupyter |
| Data science | Polars on DuckDB |
| Reverse ETL | Census, Hightouch |
| Alerting | Soda + Cube thresholds → Slack/PagerDuty |

---

## Monthly Cost Estimate

| Service | Cost | Notes |
|---|---|---|
| S3 storage | ~$23/TB/month | Parquet data only |
| RDS PostgreSQL | ~$15/month | DuckLake catalog (db.t4g.micro) |
| dlt | Free | Open source |
| SQLMesh | Free | Open source (Tobiko Cloud is paid) |
| Dagster | Free / $$$ | OSS or Dagster Cloud |
| Cube.dev | Free / $$$ | OSS or Cube Cloud |
| Soda Core | Free | OSS (Soda Cloud is paid) |

For a team with under 5 TB of data, the AWS floor is roughly $40–100/month (S3 + RDS), with Dagster Cloud and Cube Cloud free tiers covering orchestration and the semantic layer.

---

## Risks & Mitigations

| Risk | Detail | Mitigation |
|---|---|---|
| DuckLake ecosystem breadth | Fewer engine integrations than Iceberg. Spark and Trino connectors are still maturing. | DuckLake exports to Iceberg as an escape route; data on S3 remains Parquet either way. |
| SQLMesh maturity | Smaller community than dbt; fewer third-party tutorials and Stack Overflow answers. | `sqlmesh init --dbt` imports existing dbt projects; migration in either direction is feasible. |
| Single-node compute ceiling | DuckDB is a single process. Working sets beyond ~10 TB or tens of concurrent heavy users will degrade. | Export DuckLake to Iceberg and run Trino or Spark at the ceiling. |
| LLM hallucination | Agents can fabricate metric names or misinterpret questions. | Cube's semantic layer constrains the LLM to defined measures and dimensions — it cannot invent metrics. |
| Catalog single point of failure | All metadata lives in one PostgreSQL instance. | Standard RDS HA: multi-AZ, automated backups, point-in-time recovery. |

---

## Implementation Order

1. S3 bucket and RDS PostgreSQL — DuckLake foundation.
2. dlt — one source loaded into DuckLake.
3. SQLMesh + DuckDB — staging and mart models.
4. Soda — data quality checks.
5. Dagster — when scheduling needs exceed SQLMesh's built-in scheduler.
6. Cube.dev — when a semantic layer is needed.
7. LLM agents and BI — consumers last.

Each layer is independent. Add them one at a time; ship value early.
