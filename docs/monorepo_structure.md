# Monorepo Structure

## Layout

```
xdata/
├── pyproject.toml
├── uv.lock
├── .python-version
├── justfile
├── .pre-commit-config.yaml
├── .env.example
├── .gitignore
├── README.md
│
├── .github/workflows/
│   ├── ci.yml
│   ├── deploy.yml
│   └── branch-deployment.yml
│
├── shared/
│   ├── src/xdata_shared/
│   └── tests/
│
├── ingestion/
│   ├── src/xdata_ingestion/
│   │   ├── sources/
│   │   ├── schemas/
│   │   └── helpers/
│   └── tests/
│
├── transform/
│   ├── config.yaml
│   ├── models/
│   │   ├── staging/
│   │   ├── intermediate/
│   │   └── marts/
│   ├── audits/
│   ├── macros/
│   ├── seeds/
│   └── tests/
│
├── quality/
│   ├── soda_config.yaml
│   ├── checks/
│   │   ├── raw/
│   │   ├── staging/
│   │   └── marts/
│   ├── src/xdata_quality/
│   └── tests/
│
├── orchestration/
│   ├── dagster_cloud.yaml
│   ├── src/xdata_orchestration/
│   │   ├── definitions.py
│   │   ├── assets/
│   │   ├── resources.py
│   │   ├── schedules.py
│   │   ├── sensors.py
│   │   └── partitions.py
│   └── tests/
│
├── semantic/
│   ├── package.json
│   ├── cube.js
│   └── schema/*.js
│
├── infra/
│   └── opentofu/
│       ├── modules/app/
│       ├── live/
│       └── config/
│
├── scripts/
│
└── docs/
    ├── data_stack.md
    ├── monorepo_structure.md
    ├── opentofu_project_guide.md
    └── adr/
```

Dependency graph: `orchestration → {ingestion, transform, quality} → shared`. `semantic/` is JS and excluded from the uv workspace. `scripts/` declare deps inline (PEP 723) and are not workspace members.
