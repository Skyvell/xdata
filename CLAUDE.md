# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A modern data engineering platform on AWS. Currently infrastructure-only (OpenTofu), with planned Python data pipeline layers (dlt, DuckLake/DuckDB, SQLMesh, Dagster, Soda, Cube.dev).

One AWS account = one environment. Today: dev account only. Prod account is planned and will deploy the same module unchanged.

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
- `live/` — deployment root that invokes the module. Backend config is injected at `tofu init` via `-backend-config`, not hardcoded (backend.tf is intentionally empty)
- `config/` — per-account variable files (`dev.tfvars`) and backend configs (`dev.s3.tfbackend`)

**Resource names** (no env prefix — the AWS account is the env):
- RDS instance: `ducklake`
- Database: `catalog`
- Master user: `ducklake_admin` (RDS-managed master secret has all credentials)
- S3 bucket: `ducklake-<aws-account-id>` (account ID provides global uniqueness)
- State bucket: `tofu-state-<aws-account-id>`

**Planned data flow** (see `docs/data_stack.md`):
dlt → DuckLake (S3 + PostgreSQL) → DuckDB → SQLMesh → Cube.dev → consumers

**CI/CD**: GitHub Actions with OIDC federation (no stored AWS credentials). Push to `main` with changes in `infra/**` triggers `tofu apply dev`. Release events will deploy to prod once that account exists.

## Conventions

- **Resource naming**: function-based, no env prefix. Uniqueness via account ID where needed (e.g., S3 buckets).
- **Tags**: All resources get `{project = "ducklake", managed = "opentofu"}`.
- **OpenTofu version**: v1.11.0
- **Git**: Trunk-based development on `main`, imperative commit messages
