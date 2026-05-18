# Lightweight, Code-Only, Agent-Native Lakehouse — Product Plan

## Context

The existing `xdata` repo is a personal data platform: dlt → DuckLake (S3 + RDS Postgres) → DuckDB → SQLMesh → MCP, deployed via OpenTofu on AWS. The opinionated stack works, but assembling it from scratch takes a serious engineer about a week.

The product hypothesis: **package this stack as a pip-installable runtime so any small engineering team can go from `pip install` to a working analytics stack in 5 minutes and from there to production on their AWS account in 1 hour.** No SaaS control plane, no vendor runtime, no managed catalog. All code, all in the customer's cloud.

Target buyer (Year 1): seed-to-Series-A AI-native startups, 5–25 engineers, building agent or LLM products that need to query company data. They already have AWS, already pay for AI tokens, and will not buy Databricks/Snowflake. Distribution is demo-driven (Show HN, Twitter video, GitHub stars), not sales-led.

## Positioning (three pillars)

1. **One project, local → your cloud, unchanged.** pip install, running in 5 minutes locally; deploys to your AWS in 1 hour, same code.
2. **Agents get bounded tools, not raw SQL.** First-class metric, freshness, lineage tools via MCP. Human approval gates on destructive operations.
3. **No SaaS in the loop.** Your code, your AWS account, your data. No vendor control plane required.

Explicitly **not**: "open-source Databricks." Not multi-cloud at launch. Not Spark/EMR/Athena. Not real-time streaming.

## Competitive frame

- **Bauplan**: managed serverless lakehouse. Their lock-in is their lock-out — we win the buyer who refuses SaaS for production data.
- **dltHub**: owns ingestion, moving up-stack with dlt+. Risk: they ship the full bundle next year. Our defense: ship faster, own the runtime contract.
- **MotherDuck**: managed control plane. Not our buyer; perceptual competitor only.
- **DIY**: the actual competitor. The buyer can compose dlt + DuckLake + SQLMesh themselves in a week. We win by making the compressed bundle radically better than their half-built version.

## Product shape

Single pip package (name TBD). One project layout, one config file, environments as runtime targets:

```yaml
# lakehouse.yml
environments:
  local:
    catalog: sqlite:./lakehouse/catalog.db
    storage: file://./lakehouse/data
  dev:
    cloud: aws
    region: eu-west-1
    catalog: postgres        # resolved from AWS Secrets Manager
    storage: s3              # bucket name derived from account ID
  prod:
    cloud: aws
    region: eu-west-1
```

CLI:

```bash
xdata init                   # scaffold a project
xdata up                     # local environment (default)
xdata up --env dev           # local CLI, AWS catalog + storage
xdata ingest                 # run dlt sources
xdata build                  # run SQLMesh plan/apply
xdata chat                   # local MCP-bound agent
xdata deploy aws --env dev   # one-command AWS provision
```

`xdata deploy aws` runs end-to-end in under an hour from `aws sso login`: state bucket bootstrap → `tofu apply` → ECR image push → Secrets Manager seed → EventBridge schedule → IAM role for Fargate task → idempotent on re-run.

## Architecture

Cloud-pluggable from day one, only AWS implemented at launch:

```
xdata_runtime/                 # pip package
  cloud/
    base.py                    # interface: Catalog, Storage, Schedule, Secrets, Compute
    aws.py                     # the real implementation
    # gcp.py, azure.py           later
  catalog/                     # DuckLake protocol wrapper (SQLite + Postgres)
  ingest/                      # dlt wrapper
  transform/                   # SQLMesh wrapper
  mcp/                         # bounded agent tools
  cli/                         # entry point
  config.py                    # lakehouse.yml loader, env resolution

infra/opentofu/
  modules/
    cloud_aws/
      networking/              # existing modules/networking
      catalog/                 # existing modules/metadata
      lake/                    # existing modules/lake
      runner/                  # existing modules/runner
    cloud_gcp/                 # empty scaffold
    cloud_azure/               # empty scaffold
  live/                        # generated per-project, picks a cloud_<x>
```

DuckLake's catalog-pluggable design (SQLite ↔ Postgres) and URI-pluggable storage (`file://` ↔ `s3://`) make the local ↔ cloud swap protocol-level, not a translation. Same SQL, same DuckDB engine, same SQLMesh models — only the catalog backend and storage URI change between environments.

## What ships in v0 (90-day MVP)

Goal: a 90-second demo video that shows pip install → working stack → deploy to AWS → same query.

- [ ] `xdata init` scaffolds project (lakehouse.yml, sources/, models/, audits/)
- [ ] Local DuckLake (SQLite catalog + filesystem Parquet)
- [ ] `xdata ingest` runs dlt sources
- [ ] `xdata build` runs SQLMesh plan/apply
- [ ] MCP server with 5 bounded tools: `list_datasets`, `describe_dataset`, `get_freshness`, `query_metric` (basic), `get_lineage`
- [ ] `xdata deploy aws --env dev` end-to-end (state bootstrap → tofu apply → ECR push → secrets → schedule)
- [ ] `xdata up --env dev` runs local CLI against AWS RDS catalog + S3 storage
- [ ] One sample source (Postgres or Stripe), one sample model, one sample audit
- [ ] README, demo GIF, Show HN post

Explicitly NOT in v0: semantic layer with full metric DSL, RBAC, lineage graph beyond simple upstream/downstream, hosted control plane, GCP/Azure, Iceberg adapter, dbt compatibility.

## Phase 1 (post-MVP, demand-driven)

- Semantic layer (metrics in YAML, resolution via MCP `query_metric`)
- Multi-tenancy in catalog (per-engineer schemas in shared dev env)
- Lineage graph beyond direct edges
- Audit log of MCP tool invocations
- `xdata check --env aws` for catalog parity validation in CI

## Phase 2+ (only if demand signals)

- GCP and Azure cloud implementations (fill in the empty scaffold)
- RBAC + SSO (enterprise tier)
- Optional hosted control plane for orchestration only — data never goes through it (consistent with "no SaaS in the loop")

## Open questions to resolve before v0 build

1. **Package name.** `xdata` is the repo name; the product name needs a decision.
2. **Business model commitment.** Open-source-only and decide later, vs open-core (free OSS, paid enterprise tier from day one), vs paid license with free trial. Affects everything from contribution policy to GTM.
3. **Local mode principle update.** The existing "no local DuckDB fallback" principle was about personal dev discipline. Local DuckLake as a *product feature* for end users is a different scope. Worth documenting the revised stance.
4. **Semantic layer in v0 or Phase 1.** Earlier drafts had it in scope; the 90-day v0 above pushes it to Phase 1. Confirm the cut.
5. **First three design partners.** Specific named companies to approach pre-launch.

## Critical files (existing xdata repo) to evolve

| Current | Becomes |
|---|---|
| [ingestion/xdata_ingestion/pipeline.py](../ingestion/xdata_ingestion/pipeline.py) | Sample project source; runtime moves into package |
| [transform/](../transform/) | Sample project models; SQLMesh wrapper into package |
| [infra/opentofu/modules/](../infra/opentofu/modules/) | Reorganized under `modules/cloud_aws/` |
| [scripts/load_env.sh](../scripts/load_env.sh) | Replaced by env-aware Python config loader |
| [infra/docker/](../infra/docker/) | Becomes the default runner image baked into deploy |
| [justfile](../justfile) | Replaced by `xdata` CLI |

The current `xdata` repo essentially becomes the **AWS reference implementation** of the future product. Extraction work is mechanical: identify what's project-code (sample) vs runtime-code (package).

## Verification (how to know v0 works)

1. **Local time-to-first-query**: on a fresh macOS or Linux machine with Python 3.14, `pip install xdata && xdata init demo && cd demo && xdata ingest && xdata up` returns a working DuckDB query in under 5 minutes.
2. **AWS time-to-production**: with `aws sso login --profile X` already done, `xdata deploy aws --env dev` completes in under 1 hour, including state bucket bootstrap, infra apply, image push, and a first scheduled run.
3. **Code parity**: the `sources/`, `models/`, `audits/` directories are byte-identical between local and AWS runs. Only `lakehouse.yml` differs by environment.
4. **Agent flow**: an MCP client (e.g. Claude Desktop) connects to `xdata chat` and can answer "what's the freshness of the customers dataset?" and "what's MRR for last month?" via bounded tools, with no raw SQL access.
5. **Demo video**: 90 seconds from `pip install` to a working query in AWS, suitable for Show HN. If the demo doesn't fit in 90 seconds, v0 isn't done.

---

*Status: future product plan. Current focus is experimenting with the underlying stack in this repo before extracting it into a productized package.*
