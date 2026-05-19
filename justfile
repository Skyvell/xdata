set positional-arguments := true

# List available recipes.
default:
    @just --list

# Bootstrap terraform state in AWS.
bootstrap-state region bucket:
    ./scripts/bootstrap_state.sh {{region}} {{bucket}}

# Initialize OpenTofu for the given environment.
tofu-init env:
    tofu -chdir=infra/opentofu/live init -backend-config=../config/{{env}}.s3.tfbackend

# Plan OpenTofu changes for the given environment.
tofu-plan env: (tofu-init env)
    tofu -chdir=infra/opentofu/live plan -var-file=../config/{{env}}.tfvars

# Apply OpenTofu changes for the given environment.
tofu-apply env: (tofu-init env)
    tofu -chdir=infra/opentofu/live apply -var-file=../config/{{env}}.tfvars -auto-approve

# Destroy OpenTofu-managed resources for the given environment.
tofu-destroy env: (tofu-init env)
    tofu -chdir=infra/opentofu/live destroy -var-file=../config/{{env}}.tfvars

# Patch sqlmesh's magics.py for Python 3.14 argparse compatibility.
# Re-run after every `uv sync` that reinstalls sqlmesh. Mirrors the Dockerfile.
patch-sqlmesh:
    sed -i '' 's|type=t.Union\[bool, t.Iterable\[str\]\]|type=str|' \
        .venv/lib/python3.14/site-packages/sqlmesh/magics.py

# Run any sqlmesh subcommand against the active AWS profile.
# Usage: just sqlmesh plan dev --auto-apply
@sqlmesh *args:
    . ./scripts/load_env.sh && cd transform && set -x && uv run sqlmesh "$@"

# Edit a Marimo dashboard (live ATTACH to AWS DuckLake; http://localhost:2718).
# Usage: just dashboard top_coins
dashboard name:
    . ./scripts/load_env.sh && cd dashboards && uv run marimo edit {{name}}.py

# Serve a Marimo dashboard read-only (app mode; http://localhost:2718).
# Usage: just dashboard-run top_coins
dashboard-run name:
    . ./scripts/load_env.sh && cd dashboards && uv run marimo run {{name}}.py

# Run the MCP server (stdio) that exposes DuckLake mart query tools.
mcp-serve:
    . ./scripts/load_env.sh && cd mcp && uv run python -m xdata_mcp
