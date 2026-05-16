# Xdata

> Modern, lightweight and agent friendly lakehouse.

## Prerequisites

- AWS SSO access to the target account. One AWS account = one environment; today only `dev` exists.
- `tofu` v1.11.0, `just`, `uv`, Docker, `aws` CLI, `jq` on `PATH`.
- `AWS_PROFILE` exported and pointing at the target account.

## 1. Bootstrap state

One-time per AWS account. Creates the S3 bucket that holds OpenTofu state.

```bash
just bootstrap-state eu-north-1 tofu-state-$(aws sts get-caller-identity --query Account --output text)
```

## 2. Deploy infrastructure

Per-account knobs live in [infra/opentofu/config/dev.tfvars](infra/opentofu/config/dev.tfvars). To run `dlt`/SQLMesh from your laptop in step 4 or 5, add your egress IP to `metadata_allowed_cidrs` so RDS will accept the connection.

```bash
just tofu-plan dev
just tofu-apply dev
```

## 3. Build & push the runner image

The Fargate runner runs `ducklake-runner:latest` from ECR. On every push to `main`, [.github/workflows/_deploy-runner.yml](.github/workflows/_deploy-runner.yml) builds and pushes it. For a first deploy (before the first merge) or an out-of-band rebuild:

```bash
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region eu-north-1 \
  | docker login --username AWS --password-stdin "$ACCOUNT.dkr.ecr.eu-north-1.amazonaws.com"

docker buildx build --platform linux/amd64 --push \
  -f infra/docker/Dockerfile \
  -t "$(tofu -chdir=infra/opentofu/live output -raw runner_repository_url):latest" \
  .
```

## 4. Run the pipeline

The runner executes `python -m xdata_ingestion.pipeline && sqlmesh -p transform plan --auto-apply --no-prompts` on a daily EventBridge schedule ([infra/opentofu/live/main.tf](infra/opentofu/live/main.tf)).

To trigger it manually before the next firing, run the task directly on the existing cluster + task definition:

```bash
aws ecs run-task \
  --cluster ducklake-runner \
  --task-definition ducklake-runner \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[<subnet-ids>],securityGroups=[<runner-sg>],assignPublicIp=ENABLED}"
```

Subnet IDs and the runner security group come from the `networking` and `runner` modules — read them with `tofu -chdir=infra/opentofu/live state show ...`.

Or run the ingest locally against the dev catalog and bucket:

```bash
. ./scripts/load_env.sh
uv run python -m xdata_ingestion.pipeline
```

## 5. Query the lake

```bash
. ./scripts/load_env.sh
just sqlmesh fetchdf "show all tables"
just sqlmesh fetchdf "select * from ducklake.raw.coins_markets limit 5"
```

For ad-hoc DuckDB sessions, `ATTACH 'postgres:dbname=$PGDATABASE host=$PGHOST port=$PGPORT user=$PGUSER sslmode=require' AS ducklake (TYPE ducklake, DATA_PATH '$DUCKLAKE_DATA_PATH')`.

## Further reading

- [docs/data_stack.md](docs/data_stack.md) — reference architecture
- [CLAUDE.md](CLAUDE.md) — repo conventions
