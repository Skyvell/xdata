# Monorepo Structure

uv workspace covering ingestion, transformation, quality, orchestration, and shared utilities. Cube.dev (Node) lives outside the Python workspace; infra (OpenTofu) lives in `infra/`.

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
│   ├── src/xdata_ingestion/
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

Dependency graph: `orchestration → {ingestion, transform, quality} → shared`. `semantic/` is JS and excluded from the uv workspace. `scripts/` declare deps inline (PEP 723) and are not workspace members.

---

## Workspace wiring

Root `pyproject.toml` lists members; packaged members resolve shared deps from the workspace, not PyPI.

```toml
# pyproject.toml
[tool.uv.workspace]
members = ["shared", "ingestion", "transform", "quality", "orchestration"]
```

```toml
# ingestion/pyproject.toml
[project]
name = "xdata-ingestion"
requires-python = ">=3.13"
dependencies = ["xdata-shared", "dlt[ducklake]>=1.0"]

[tool.uv.sources]
xdata-shared = { workspace = true }

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

`orchestration/` depends on `xdata-shared`, `xdata-ingestion`, `xdata-transform`, `xdata-quality`, and `dagster>=1.10` (+ `dagster-dlt`, `dagster-sqlmesh`). `dagster-webserver` goes in `[dependency-groups] dev` — Dagster+ hosts the webserver in production.

`transform/` is a **non-packaged** workspace member: declares SQLMesh deps and sets `[tool.uv] package = false` (no `src/`, no build backend — there's no Python module to import, just SQL and deps).
