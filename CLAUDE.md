# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

xdata is a modern data engineering platform on AWS. Currently infrastructure-only (OpenTofu), with planned Python data pipeline layers (dlt, DuckLake/DuckDB, SQLMesh, Dagster, Soda, Cube.dev).

## Commands

All commands use the `just` task runner:

```bash
just tofu-init <env>       # Initialize OpenTofu for an environment
just tofu-plan <env>       # Plan infrastructure changes
just tofu-apply <env>      # Apply infrastructure changes
just tofu-destroy <env>    # Destroy infrastructure
just bootstrap-state <region> <bucket>  # One-time state bucket setup
```

Linting and security scanning:
```bash
tflint --chdir=infra/live  # Terraform linting (AWS plugin)
trivy fs --config infra/trivy.yaml infra/  # Security scan (HIGH/CRITICAL)
```

OpenTofu tests: `infra/modules/app/tests/basic.tftest.hcl`

## Architecture

**Infrastructure (`infra/`)**:
- `modules/app/` — reusable module defining all AWS resources (RDS PostgreSQL catalog, S3 lake, VPC/security groups)
- `live/` — environment deployment root that invokes the module. Backend config is injected at `tofu init` via `-backend-config`, not hardcoded (backend.tf is intentionally empty)
- `config/` — per-environment variable files (`prod.tfvars`) and backend configs (`prod.s3.tfbackend`)

**Planned data flow** (see `docs/data_stack.md`):
dlt → DuckLake (S3 + PostgreSQL) → DuckDB → SQLMesh → Cube.dev → consumers

**CI/CD**: GitHub Actions with OIDC federation (no stored AWS credentials). Push to `main` with changes in `infra/**` triggers `tofu apply prod`.

## Conventions

- **Resource naming**: `xdata-<env>-<resource>` (e.g., `xdata-prod-lake`)
- **Tags**: All resources get `{env, project, managed}` tags
- **Per-env behavior**: Use the `features` variable object, not `env == "prod"` conditionals
- **OpenTofu version**: v1.11.0
- **Git**: Trunk-based development on `main`, imperative commit messages
