# Monorepo Structure

**Stack:** uv workspaces · just · ruff · pyright · sqlfluff · pre-commit · GitHub Actions · Dagster+ Serverless

---

## Layout

```
xdata/
├── pyproject.toml              # root workspace + dev tooling config
├── uv.lock                     # single lockfile across all members
├── .python-version             # 3.13
├── justfile
├── .pre-commit-config.yaml
├── .env.example
├── .gitignore
├── CLAUDE.md
├── README.md
│
├── .github/workflows/
│   ├── ci.yml                  # PR: lint + typecheck + test + sqlmesh plan + soda
│   ├── deploy.yml              # main: sqlmesh apply + dagster-plus deploy
│   └── branch-deployment.yml   # PR: Dagster+ branch deployment
│
├── shared/                     # config, connections, logging, types
│   ├── src/xdata_shared/
│   └── tests/
│
├── ingestion/                  # dlt pipelines
│   ├── src/xdata_ingestion/««
│   │   ├── sources/            # one file per source (stripe, hubspot, …)
│   │   ├── schemas/            # <source>.yaml — dlt schema overrides
│   │   └── helpers/
│   └── tests/
│
├── transform/                  # SQLMesh project — non-packaged workspace member (deps only, no src/)
│   ├── config.yaml
│   ├── models/
│   │   ├── staging/
│   │   ├── intermediate/
│   │   └── marts/
│   ├── audits/
│   ├── macros/
│   ├── seeds/
│   └── tests/                  # SQLMesh tests
│
├── quality/                    # Soda
│   ├── soda_config.yaml
│   ├── checks/
│   │   ├── raw/
│   │   ├── staging/
│   │   └── marts/
│   ├── src/xdata_quality/      # programmatic Soda runner
│   └── tests/
│
├── orchestration/              # Dagster user code
│   ├── dagster_cloud.yaml      # Dagster+ code-location definition
│   ├── src/xdata_orchestration/
│   │   ├── definitions.py
│   │   ├── assets/             # ingestion.py, transformation.py, quality.py
│   │   ├── resources.py
│   │   ├── schedules.py
│   │   ├── sensors.py
│   │   └── partitions.py
│   └── tests/
│
├── semantic/                   # Cube.dev (Node — outside uv workspace)
│   ├── package.json
│   ├── cube.js
│   └── schema/*.js
│
├── infra/                      # see docs/opentofu_project_guide.md
│   └── opentofu/
│       ├── modules/app/
│       ├── live/
│       └── config/
│
├── scripts/                    # PEP 723 inline-metadata one-offs (ad-hoc backfills, migrations) — empty until needed
│
└── docs/
    ├── data_stack.md
    ├── monorepo_structure.md
    ├── opentofu_project_guide.md
    └── adr/
```

Dependency graph: `orchestration → {ingestion, transform, quality} → shared`. `semantic/` is JS and excluded from the uv workspace. `scripts/` declare deps inline and are not workspace members.

---

## Root pyproject.toml

```toml
[project]
name = "xdata"
version = "0.1.0"
requires-python = ">=3.13"

[tool.uv.workspace]
members = ["shared", "ingestion", "transform", "quality", "orchestration"]

[dependency-groups]                                    # PEP 735
dev = ["pytest>=8", "ruff>=0.9", "pyright>=1.1", "sqlfluff>=3", "pre-commit>=4"]

[tool.ruff]
target-version = "py313"
line-length = 120

[tool.ruff.lint]
select = ["E", "F", "I", "UP", "B", "SIM", "TCH", "RUF", "N", "PTH", "ASYNC", "S", "ARG"]

[tool.pyright]
pythonVersion = "3.13"
typeCheckingMode = "strict"
```

---

## Workspace member (pattern)

Every **packaged** member follows this shape. Example: `ingestion/pyproject.toml`.

```toml
[project]
name = "xdata-ingestion"
version = "0.1.0"
requires-python = ">=3.13"
dependencies = ["xdata-shared", "dlt[duckdb]>=1.0"]

[tool.uv.sources]
xdata-shared = { workspace = true }                    # resolve from workspace, not PyPI

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

`orchestration/` depends on `xdata-shared`, `xdata-ingestion`, `xdata-transform`, `xdata-quality`, and `dagster>=1.10` (+ `dagster-dlt`, `dagster-sqlmesh`). `dagster-webserver` goes in its `[dependency-groups] dev` — Dagster+ hosts the webserver in production.

`transform/` is a **non-packaged** workspace member: its `pyproject.toml` declares SQLMesh deps and sets `[tool.uv] package = false` (no `src/`, no build backend — there's no Python module to import, just SQL and deps).

---

## justfile

```just
set dotenv-load

# ── Setup ──
setup:
    uv python install 3.13
    uv sync --all-packages
    uv run pre-commit install

# ── Dev ──  (Dagster UI locally, pointed at dev AWS via .env)
dev:
    uv run --package orchestration dagster dev

# ── Transforms ──
[working-directory: 'transform']
plan env="dev":
    uv run sqlmesh plan {{env}}

[working-directory: 'transform']
apply env="dev":
    uv run sqlmesh plan {{env}} --auto-apply

# ── Quality / Test / Lint ──
quality:
    uv run --package quality soda scan -d duckdb -c quality/soda_config.yaml quality/checks/

test:
    uv run pytest
    uv run --directory transform sqlmesh test

lint:
    uv run ruff check .
    uv run ruff format --check .
    uv run pyright
    uv run sqlfluff lint transform/models/

fix:
    uv run ruff check --fix .
    uv run ruff format .
    uv run sqlfluff fix transform/models/

# ── Deploy ──
deploy:
    uv run --directory transform sqlmesh plan prod --auto-apply
    uv run dagster-plus ci deploy
```

There is no local data stack. `dagster dev` runs the UI on the developer's machine but connects to the **dev** AWS environment (RDS Postgres catalog + S3 dev bucket) via `.env`. DuckDB is an in-process library — the engine runs wherever the code runs, including inside Dagster+.

---

## pre-commit

```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.9.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
  - repo: https://github.com/sqlfluff/sqlfluff
    rev: 3.3.0
    hooks:
      - id: sqlfluff-lint
        files: ^transform/models/
  - repo: local
    hooks:
      - id: pyright
        name: pyright
        entry: uv run pyright
        language: system
        types: [python]
        pass_filenames: false
```

---

## CI (ci.yml, sketch)

```yaml
name: CI
on:
  pull_request:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

env:
  UV_CACHE_DIR: .uv-cache

jobs:
  lint:                    # ruff check + format + pyright + sqlfluff
  test:                    # pytest + sqlmesh test     (needs: lint)
  sqlmesh-plan:            # plan against ephemeral PR env, not unbound (needs: test)
  soda-scan:               # scan the materialized ephemeral env         (needs: sqlmesh-plan)
  branch-deployment:       # dagster-cloud-action → Dagster+ per-PR env  (needs: test)
```

On merge to main, `deploy.yml` runs `sqlmesh plan prod --auto-apply` then `dagster-plus ci deploy`.

---

## Scripts (PEP 723)

Utility scripts declare deps inline and run via `uv run scripts/<name>.py` — no install step, not part of the workspace:

```python
# /// script
# requires-python = ">=3.13"
# dependencies = ["duckdb>=1.4"]
# ///
```

---

## Per-layer installs

```
uv sync --package ingestion       # dlt + shared only
uv sync --package transform       # sqlmesh + shared only
uv sync --package orchestration   # everything (transitive)
uv sync --all-packages            # dev: whole workspace
```

CI jobs install only what they need; the root `uv.lock` keeps versions consistent across members.

---

## Environments

| Env | Compute | Catalog | Files |
|---|---|---|---|
| Dev  | DuckDB + DuckLake | RDS Postgres (dev)  | S3 dev  |
| Int  | DuckDB + DuckLake | RDS Postgres (int)  | S3 int  |
| Prod | DuckDB + DuckLake | RDS Postgres (prod) | S3 prod |

All three environments are AWS — there is no local data stack. SQLMesh virtual environments eliminate data duplication *within* each AWS env: `just plan dev` previews, `just apply prod` deploys.

---

## Tooling rationale

- **uv** — 100× faster than pip; native workspace support; replaces pip/poetry/pyenv.
- **just** — arguments, `[working-directory]`, dotenv loading; replaces Make.
- **ruff** — single Rust binary; replaces black/isort/flake8.
- **pyright** — strict type checking.
- **sqlfluff** — SQL is the product; lint it too.
- **Dagster+ Serverless** — hosted webserver/daemon, branch deployments per PR, no user-code Dockerfile required.
- **PEP 723 scripts** — dep-declaring one-offs without workspace overhead.
- **PEP 735 dependency groups** — tool-agnostic dev deps.
