# xdata

Modern data engineering stack: `dlt → DuckLake (S3 + PostgreSQL) → SQLMesh on DuckDB → Cube.dev → LLM agents`. Orchestrated by Dagster, quality enforced by SQLMesh audits and Soda.

See [docs/data_stack.md](docs/data_stack.md) for the full reference architecture.

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

AWS — eu-north-1. Each environment (dev/int/prod) has its own S3 lake bucket and RDS PostgreSQL catalog.

**One-time bootstrap** (run from laptop with SSO credentials):

```bash
just bootstrap-state eu-north-1 xdata-tofu-state
```

**Deploy infra:**

Merges to `main` that touch `infra/` deploy automatically via GitHub Actions (OIDC, no stored credentials). To preview changes locally first:

```bash
just tofu-plan prod
```

See [docs/opentofu_project_guide.md](docs/opentofu_project_guide.md).

## TODO

- [ ] Deploy infra (`tofu apply` prod)
- [ ] CI/CD — `tofu plan` on PR
