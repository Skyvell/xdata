# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a reference implementation for a modern data engineering stack. The architecture is documented in `docs/` and the codebase will be built following those specs. The guiding principle is "bleeding edge" — favor the fastest, most capable tools over incumbents.

## Architecture

The data stack has 8 layers (see `docs/data_stack.md` for full rationale):

1. **Ingestion** — dlt (Python-native ELT)
2. **Storage** — S3 (files) + PostgreSQL (DuckLake catalog)
3. **Table Format** — DuckLake (replaces Iceberg + Glue; SQL-based catalog, 926x faster than Iceberg)
4. **Compute** — DuckDB (local and production, via DuckLake on S3)
5. **Transform** — SQLMesh (replaces dbt; column-level lineage, virtual envs, 9x faster CI)
6. **Orchestration** — Dagster (asset-based, first-class dlt/SQLMesh integration)
7. **Data Quality** — SQLMesh audits (blocking) + Soda (ML anomaly detection)
8. **Semantic Layer** — Cube.dev (pre-aggregations, REST/GraphQL/SQL APIs, LLM-friendly)

**Primary consumption**: LLM agents via Cube.dev's SQL API. BI dashboards are secondary.

## Planned Monorepo Structure

From `docs/monorepo_structure.md` — the repo will be organized as a uv workspace:

```
data-platform/
├── packages/shared/      # Shared config, connections, utils, logging
├── ingestion/            # dlt pipelines (sources → DuckLake)
├── transform/            # SQLMesh models, audits, macros
├── quality/              # Soda checks
├── orchestration/        # Dagster assets, jobs, schedules, sensors
├── semantic/             # Cube.dev schemas (JS/Node)
├── infra/                # OpenTofu (multi-env: dev/int/prod) + Docker
├── scripts/              # Utility scripts with PEP 723 inline deps
└── docs/                 # Architecture docs, runbooks, ADRs
```

## Tooling Stack

| Tool | Role | Notes |
|------|------|-------|
| **uv** | Package manager + Python version | Replaces pip/poetry/pyenv; workspace support |
| **just** | Task runner | Replaces Makefile |
| **ruff** | Linting + formatting | Single Rust binary, replaces flake8/black/isort |
| **pyright** | Type checking | Strict mode |
| Python 3.13 | Runtime | Managed by uv |

## Commands (once implemented)

```bash
just setup       # Install Python 3.13, deps, pre-commit hooks, local DuckLake
just dev         # Start Dagster UI + local Postgres
just plan        # Preview SQLMesh model changes
just apply       # Apply SQLMesh changes
just test        # Run all tests
just lint        # ruff check + pyright
just fix         # Auto-fix lint/format issues
just quality     # Run Soda data quality scans
just deploy      # Full deploy (transforms + Dagster Cloud)
```

Individual package tests: `uv run --package <pkg> pytest tests/path/to/test.py`

## Infrastructure

OpenTofu manages multi-environment infrastructure (dev/int/prod) in `infra/opentofu/`. State is stored in S3 with native S3 locking (`use_lockfile = true`). See `docs/opentofu_project_guide.md` for structure and CI/CD pipeline details (plan on PR, apply on merge/manual with approval gates for int/prod).

## Key Technology Choices

When implementing, prefer these over common alternatives:
- **DuckLake over Iceberg** — no JVM, SQL-managed catalog, dramatically faster metadata ops
- **SQLMesh over dbt** — virtual environments mean CI runs without touching prod; built-in column-level lineage
- **uv over pip/poetry** — workspace support; use `uv add --package <pkg>` not `pip install`
- **just over Makefile** — cleaner syntax, better cross-platform behavior
- **Dagster over Airflow/Prefect** — asset-based model aligns naturally with data layers; first-class dlt and SQLMesh integrations
- **OpenTofu over Terraform** — MPL 2.0 licensed, CNCF-governed, native state encryption, no BSL licensing risk
