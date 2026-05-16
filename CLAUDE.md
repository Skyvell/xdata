# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A modern data engineering platform on AWS: dlt ingestion → DuckLake (S3 + RDS PostgreSQL) → DuckDB → SQLMesh → MCP server → chat/notebook consumers. Infrastructure is OpenTofu; pipelines run on a scheduled Fargate task. See [docs/data_stack.md](docs/data_stack.md).

One AWS account = one environment. Today: dev account only. Prod account is planned and will deploy the same modules unchanged.

## Repo layout

- [ingestion/](ingestion/) — dlt pipelines (uv workspace member `xdata-ingestion`)
- [transform/](transform/) — SQLMesh project (uv workspace member `xdata-transform`)
- [infra/opentofu/](infra/opentofu/) — modules, `live/` deployment root, per-account `config/`
- [infra/docker/](infra/docker/) — runner image (Python 3.14 + uv, builds both workspaces)
- [migrations/](migrations/) — one-shot SQL migrations applied manually to the catalog DB
- [scripts/](scripts/) — admin scripts; `load_env.sh` is sourced to export `PG*` and `DUCKLAKE_*` from the active AWS profile
- [docs/](docs/) — reference architecture

## Commands

`just` is the entry point:

```bash
just tofu-init <env>       # tofu init with backend config from infra/opentofu/config/<env>.s3.tfbackend
just tofu-plan <env>       # plan
just tofu-apply <env>      # apply -auto-approve
just tofu-destroy <env>    # destroy
just bootstrap-state <region> <bucket>  # one-time state bucket setup

just sqlmesh <args...>     # sources scripts/load_env.sh then runs sqlmesh from transform/
just patch-sqlmesh         # re-applies the Python 3.14 argparse fix after `uv sync`
```

`scripts/load_env.sh` must be sourced (not executed) and reads the RDS endpoint + master secret from the active AWS profile. The Fargate runner gets the same env vars injected by the `runner` module.

Linting and security:
```bash
tflint --chdir=infra/opentofu/live    # config at infra/.tflint.hcl
trivy fs --config infra/opentofu/trivy.yaml infra/
```

## Architecture

**Infrastructure** ([infra/opentofu/](infra/opentofu/)):
- `modules/networking` — VPC, subnets
- `modules/metadata` — RDS PostgreSQL (the DuckLake catalog + SQLMesh state)
- `modules/lake` — S3 bucket for Parquet data
- `modules/runner` — ECR repo, ECS Fargate task, EventBridge scheduler, IAM, alarms
- `modules/dagster` — present but not wired into `live/main.tf` (future work)
- `live/` — invokes the modules above. `backend.tf` is intentionally empty; backend config is injected at `tofu init` via `-backend-config`

**Resource names** (no env prefix — the AWS account is the env):
- RDS instance + database: `metadata`
- Master user: `metadata_admin` (RDS-managed master secret holds the credentials)
- S3 data bucket: `ducklake-<aws-account-id>`
- State bucket: `tofu-state-<aws-account-id>`
- ECR repo: `ducklake-runner`

**Runtime data flow**:
EventBridge (daily) → Fargate task running `python -m xdata_ingestion.pipeline && sqlmesh -p transform plan --auto-apply --no-prompts` → writes Parquet to S3 and registers files in the Postgres catalog.

**Env var convention**: Postgres connection uses libpq's standard names (`PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`); DuckLake-specific values keep the `DUCKLAKE_` prefix. SQLMesh state lives in the same Postgres instance under schema `sqlmesh`.

**CI/CD** ([.github/workflows/](.github/workflows/)): on push to `main`, `deploy.yml` runs `tofu apply dev`, then builds and pushes the runner image to ECR (`:latest`). OIDC federation; no stored AWS credentials. A release event will deploy to prod once that account exists.

## Conventions

- **Python**: 3.14, bleeding-edge dependencies, no `from __future__` shims
- **Resource naming**: function-based, no env prefix; uniqueness via account ID where needed
- **Tags**: all resources get `{project = "ducklake", managed = "opentofu"}`
- **OpenTofu**: v1.11.0
- **Git**: trunk-based on `main`, one-line imperative commit subjects, no Claude co-author trailer
