# Data stack — 2026

```
dlt → DuckLake (S3 + PostgreSQL) → DuckDB → SQLMesh → MCP server → {chat agent, Marimo}
```

The MCP server is the primary consumer interface. Chat agents (Claude.ai, Claude Desktop, Cursor today; a custom UI later) and Marimo notebooks are clients of it.

## Design principles

- **Code-only authoring surfaces.** Every layer is configured by files in git. No GUI-driven config, no console clicks.
- **Agent-coherent format per surface.** Python where the surface is logic; Markdown + SQL where the surface is reports; never bespoke JS business logic.
- **One AWS account = one environment.** Account boundary IS the environment; the same module deploys to dev and prod unchanged.
- **MCP as the primary consumer interface.** Ad-hoc analytics flows through chat agents over MCP, not through a dashboard tool.
- **Defer complexity until justified.** Each deferred layer has a falsifiable graduation criterion (see § Deferred layers).

## Layers

### 1. Ingestion — dlt

Python-native ELT. Resources are decorated Python generators; dlt handles pagination, retries, incremental cursors, schema inference and schema evolution on write. Configured by pyproject extras (`dlt[ducklake]`) and a destination set to `ducklake`. Earned its place because ingestion logic lives as Python in the same workspace as the rest of the stack — no separate connector platform, no GUI definitions.

### 2. Storage — DuckLake on S3 + PostgreSQL

Catalog metadata (schemas, snapshots, file locations, column statistics) in PostgreSQL on RDS; data files as Parquet on S3. Replaces Iceberg + Glue: queries that would require multiple S3 round-trips for manifest resolution become a single SQL query against the catalog. Small writes are held in the catalog and compacted to Parquet on threshold, avoiding the small-file problem. ACID, schema evolution, time travel, and multi-table atomic commits are catalog transactions. Bidirectional Iceberg import/export keeps the exit path open.

### 3. Compute — DuckDB

Single-process query engine. Reads DuckLake natively via the `ducklake` extension; attaches with a libpq DSN so postgres credentials come from `PGHOST` / `PGPORT` / `PGDATABASE` / `PGUSER` / `PGPASSWORD` rather than being embedded in the SQL literal. S3 access uses the AWS credential chain. Earned its place because in-process compute fits the working set: one node, no cluster.

### 4. Transformation — SQLMesh

Models are SQL files annotated with `MODEL()` blocks declaring kind, grain, and inline audits. SQLMesh parses SQL for column-level lineage and categorizes changes as breaking or forward-only; non-breaking changes apply without reprocessing history. Virtual environments test changes against production data without copying tables. Plan / apply workflow is analogous to OpenTofu. Earned its place over dbt because virtual envs and column-level lineage are first-class, not bolted on.

### 5. Quality — SQLMesh audits

Audits (`not_null`, `unique_values`, `accepted_range`, custom) are declared inline on models and run on `plan` / `apply`, blocking deploys on failure. Sufficient at this stage; freshness anomaly detection and schema-drift monitoring on upstream tables remain a deferred concern.

### 6. Orchestration — ECS scheduled task

A single Fargate task (`ducklake-runner`) runs dlt then SQLMesh sequentially, scheduled by EventBridge. Container image is built and pushed by CI. Environment variables (libpq `PG*` from the RDS-managed secret, `DUCKLAKE_*` and `AWS_REGION` from task definition) are injected at start. Sufficient for one source on one schedule; deliberately not Dagster yet.

### 7. Consumer interface — MCP server (planned)

A Python MCP server exposing four classes of tool to LLM agents: schema introspection over DuckLake catalogs, SQL execution against SQLMesh marts, freshness and lineage metadata pulled from SQLMesh state, and model documentation pulled from `MODEL()` descriptions. Connection params follow the same libpq convention as the runner. Earned its place as the primary consumer interface because ad-hoc analytics is moving from dashboard navigation to chat-driven querying; MCP is the emerging standard for that interface.

### 8. Exploration — Marimo (planned)

Reactive notebooks stored as plain `.py` files (not JSON), so they diff cleanly and agents can author them directly. Used for code-heavy investigations the agent and human iterate on together via Cursor or Claude Desktop. Replaces Jupyter; the file format is the load-bearing improvement.

## Agent usage patterns

| Usage | Path |
|---|---|
| Ad-hoc question ("how did X trend last quarter?") | Chat agent → MCP `query` against `marts.*` → answer with cited mart and inline chart spec. |
| Definition lookup ("what's our churn definition?") | Chat agent → MCP `describe_model` → SQLMesh model description and lineage. |
| Freshness check ("is the orders feed current?") | Chat agent → MCP `freshness` → SQLMesh last-run timestamp + upstream dlt pipeline metadata. |
| Iterative investigation | Analyst opens Marimo; agent scaffolds queries in the same file; human iterates on the resulting Python. |
| Recurring canonical view | Out of scope today; chat agent rerun covers the same need until graduation criteria for Evidence are met. |

## Deferred layers

| Layer | Role when graduated | Graduation criterion |
|---|---|---|
| Dagster | Asset-based orchestration | ≥2 sources on different schedules, cross-system dependencies, per-asset freshness SLAs, or event-driven triggers. IAM scaffolding already in place. |
| Soda | Data quality observability | SQLMesh audits insufficient — need freshness anomaly detection on the landing zone or schema-drift monitoring on tables the team doesn't own. |
| Evidence.dev | Code-defined static dashboards | The same stakeholder asks the same question on a recurring schedule. Markdown + SQL remains the right authoring surface. |
| Custom chat UI | Stakeholder-facing analytics UI | Outgrowing Claude.ai / Cursor / Desktop — embedding in a product, custom auth, or org-controlled chat history. |
| Reverse ETL (Census / Hightouch) | Push curated marts back to ops systems | A downstream operational system requires curated marts as an input. |
| Dedicated semantic layer | Metric definition governance | Metric drift across multiple consumers becomes a real problem. Evaluate SQLMesh metrics, MetricFlow, or BSL — not Cube. |

## Non-choices

- **Cube** — semantic layer with JS as the *business-logic* surface. Rejected: violates the agent-coherent-surface principle, semantic-layer field is still settling, zero current consumers justify the complexity. MCP over SQLMesh marts covers the agent interface today.
- **Iceberg + Glue** — more mature ecosystem than DuckLake but trades bleeding-edge ergonomics for breadth that this project doesn't need. DuckLake already deployed; Iceberg export remains the documented exit path.
- **dbt / dbt Fusion** — larger community than SQLMesh but lacks first-class virtual environments and column-level lineage; loses against SQLMesh on the dimensions that matter for an agent-driven future.
- **Streamlit / Plotly Dash** — Python dashboards, but reactive Python is a worse authoring surface for stakeholder reports than Markdown + SQL would be. Evidence wins that role when it graduates.
- **Observable Framework** — strongest dataviz of the code-defined options but requires writing JS for custom charts; reconsider only if dataviz quality becomes a differentiator.
- **Rill Data** — DuckDB-native YAML BI, promising; less mature than Evidence at the point this decision is made.
- **Sling** — Go-based ELT; loses Python-native coherence vs. dlt.
- **Prefect** — viable Dagster alternative; sticking with Dagster because its IAM is already scaffolded in this project.

## Ceiling and exit

DuckDB is a single process: degrades past roughly 10 TB working set or tens of concurrent heavy queries. Exit path is to export the DuckLake catalog to Iceberg and run Trino or Spark against the same S3 data — Parquet files do not move.

## Cost floor (current reality)

| Item | Cost | Notes |
|---|---|---|
| S3 | ~$23 / TB / month | Parquet only; no metadata files. |
| RDS PostgreSQL | ~$15 / month | DuckLake catalog, `db.t4g.micro`, one instance per account. |
| ECS / Fargate runner | <$5 / month | One scheduled task per day, sub-hour duration. |
| dlt, DuckDB, SQLMesh, Marimo, MCP server | Free | Open source. |

Under 1 TB on a single account: ~$25–40/month floor. Each additional environment is another account with the same module deployed and another ~$15/month RDS.
