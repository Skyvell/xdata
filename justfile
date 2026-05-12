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

# Plan SQLMesh changes (no args = prod virtual env; pass `dev` etc. for a virtual env).
sqlmesh-plan *args:
    cd transform && uv run sqlmesh plan {{args}}

# Plan and auto-apply.
sqlmesh-apply *args:
    cd transform && uv run sqlmesh plan --auto-apply {{args}}
