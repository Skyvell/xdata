# Bleeding edge data stack
Agent-friendly lakehouse. Chat as primary UI. Everything as code.

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

      Analysts use chat + notebooks  ·  Stakeholders use chat + reports
```

## Components

### Ingestion
- dlt

### Storage
- DuckLake
- S3 + RDS (PostgreSQL)

### Compute
- DuckDB

### Transformation
- SQLMesh

### Quality
- SQLMesh audits
- Soda if needed

### Orchestration
- EventBridge + Fargate
- Dagster/Prefect if future need

### Consumer interfaces
- MCP server exposing the semantic layer, freshness, and lineage. Start with the semantic layer.
- Primary surface for every consumer — chat agents, Marimo, Evidence, and any future custom UI all attach here.

### Chat surface
- Claude Desktop

Future:
- Custom chat UI

### Notebooks
- Marimo

### Static reports
- Evidence
