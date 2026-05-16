# Xdata

A lightweight, modern and agentfriendly data engineering stack.

## Overview

Xdata is a lightweight lakehouse built around an agent-friendly access layer. A scheduled AWS job ingests with dlt, lands data in DuckLake (S3 Parquet + RDS Postgres catalog), and transforms it with SQLMesh on DuckDB. An MCP server fronts the lake so every client — chat agents, notebooks, reports — attaches to the same semantic layer rather than the database directly. One AWS account = one environment; only `dev` exists today, and prod will deploy the same modules unchanged.

## Architecture

```
                ┌──────────────────────────────────────┐
                │      External APIs · files · DBs     │
                └──────────────────┬───────────────────┘
                                   │
                                   ▼
  ┌───────────────────────────────────────────────────────────────────┐
  │  Pipeline · scheduled by EventBridge → ECS Fargate                │
  │                                                                   │
  │      ┌─────────┐                         ┌────────────────────┐   │
  │      │   dlt   │                         │      SQLMesh       │   │
  │      │  ingest │                         │ transform + audits │   │
  │      └─────────┘                         └────────────────────┘   │
  └────────────────────────────────┬──────────────────────────────────┘
                                   │ writes raw + marts
                                   ▼
                ┌──────────────────────────────────────┐
                │              DuckLake                │
                │     S3 Parquet · Postgres catalog    │
                └──────────────────┬───────────────────┘
                                   │ queried via
                                   ▼
                ┌──────────────────────────────────────┐
                │         DuckDB · query engine        │
                └──────────────────┬───────────────────┘
                                   │
                                   ▼
                ┌──────────────────────────────────────┐
                │             MCP server               │
                └──────┬───────────────┬───────────┬───┘
                       │               │           │
                       ▼               ▼           ▼
              ┌────────────────┐ ┌───────────┐ ┌──────────────────┐
              │ Claude Desktop │ │  Marimo   │ │     Evidence     │
              │ chat — primary │ │ notebooks │ │ static reports   │
              │                │ │           │ │    (future)      │
              └────────────────┘ └───────────┘ └──────────────────┘
```

## Repository layout

```
.
├── ingestion/        dlt pipelines (uv workspace: xdata-ingestion)
├── transform/        SQLMesh project (uv workspace: xdata-transform)
├── infra/
│   ├── opentofu/     modules, live/ root, per-account config/
│   └── docker/       runner image
├── migrations/       one-shot SQL migrations for the catalog DB
├── scripts/          admin scripts (bootstrap_state.sh, load_env.sh)
├── docs/             reference architecture
├── justfile          task runner entry points
└── CLAUDE.md         repo conventions for Claude Code
```

## Pre-requisites

Install pre-requisites:
```bash
brew install opentofu just uv awscli jq
```

## Infrastructure

Create opentofu state bucket:
```bash
just bootstrap-state eu-north-1 tofu-state-$(aws sts get-caller-identity --query Account --output text)
```

## Local development


## Deployment


## Documentation

Link tree only — don't duplicate content.
- `docs/data_stack.md` — reference architecture
- `CLAUDE.md` — repo conventions
