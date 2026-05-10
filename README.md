# DuckLake

Modern data engineering stack: `dlt → DuckLake (S3 + PostgreSQL) → SQLMesh on DuckDB → Cube.dev → LLM agents`. Orchestrated by Dagster, quality enforced by SQLMesh audits and Soda.

See [docs/data_stack.md](docs/data_stack.md) for the full reference architecture and [docs/mental_model.md](docs/mental_model.md) for the naming and resource model.

## Stack

| Layer | Tool |
|---|---|
| Ingestion | dlt |
| Storage | DuckLake (S3 + RDS PostgreSQL) |
| Compute | DuckDB |
| Transformation | SQLMesh |
| Orchestration | Dagster |
| Quality | SQLMesh audits + Soda |
| Semantic layer | Cube.dev |
| Consumers | LLM agents, BI dashboards |

## Repo layout

```
ingestion/      dlt pipelines
transform/      SQLMesh models
quality/        Soda checks
orchestration/  Dagster assets and jobs
semantic/       Cube.dev schema
shared/         shared Python utilities
infra/          OpenTofu infrastructure (modules/app + live/ + config/)
scripts/        one-shot admin scripts (PEP 723)
docs/           reference architecture docs
```

See [docs/monorepo_structure.md](docs/monorepo_structure.md) for workspace wiring.

## Infrastructure

AWS — eu-north-1. One AWS account = one environment. Today: dev account only. Prod account is planned and will deploy the same module unchanged.

**One-time bootstrap** (run from laptop with SSO credentials, once per AWS account):

```bash
just bootstrap-state eu-north-1 tofu-state-<aws-account-id>
```

**Deploy infra:**

Merges to `main` that touch `infra/` deploy automatically via GitHub Actions (OIDC, no stored credentials). To preview changes locally first:

```bash
just tofu-plan dev
```

See [docs/opentofu_project_guide.md](docs/opentofu_project_guide.md).
