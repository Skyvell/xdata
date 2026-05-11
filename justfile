# List available recipes.
default:
    @just --list

# Bootstrap terraform state in AWS.
bootstrap-state region bucket:
    ./scripts/bootstrap_state.sh {{region}} {{bucket}}

# Initialize OpenTofu for the given environment.
tofu-init env:
    tofu -chdir=infra/live init -backend-config=../config/{{env}}.s3.tfbackend

# Plan OpenTofu changes for the given environment.
tofu-plan env: (tofu-init env)
    tofu -chdir=infra/live plan -var-file=../config/{{env}}.tfvars

# Apply OpenTofu changes for the given environment.
tofu-apply env: (tofu-init env)
    tofu -chdir=infra/live apply -var-file=../config/{{env}}.tfvars -auto-approve

# Destroy OpenTofu-managed resources for the given environment.
tofu-destroy env: (tofu-init env)
    tofu -chdir=infra/live destroy -var-file=../config/{{env}}.tfvars

# Open DuckDB UI with the rujira lake pre-attached. Requires AWS auth in env.
explore:
    #!/usr/bin/env bash
    set -euo pipefail
    init_sql=$(mktemp)
    trap "rm -f $init_sql" EXIT
    uv run python -m xdata_ingestion.attach > "$init_sql"
    duckdb -ui -init "$init_sql"
