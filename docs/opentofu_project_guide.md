# OpenTofu project structure

## Layout

```
infra/
├── modules/app/
│   ├── variables.tf
│   ├── outputs.tf
│   ├── locals.tf
│   ├── networking.tf
│   ├── catalog.tf
│   ├── lake.tf
│   ├── iam.tf
│   └── tests/basic.tftest.hcl
├── live/
│   ├── main.tf
│   ├── variables.tf
│   ├── providers.tf
│   └── backend.tf
├── config/
│   ├── {dev,int,prod}.tfvars
│   └── {dev,int,prod}.s3.tfbackend
├── .tflint.hcl
└── trivy.yaml
```

OpenTofu merges every `.tf` in a directory, so splitting the module by concern keeps files focused without spawning separate state. `live/` is the only directory `tofu` runs in; `config/` is pure data — adding an environment means adding two files (`<env>.tfvars` + `<env>.s3.tfbackend`).

## Non-obvious wirings

- `live/backend.tf` is intentionally empty; `-backend-config=<env>.s3.tfbackend` fills it at init time, so no environment identifier appears in HCL.
- No `assume_role` block in the provider — GitHub Actions OIDC sets credentials before OpenTofu runs.
- Only `key` varies across `<env>.s3.tfbackend` files (`<env>/opentofu.tfstate`); bucket and KMS key are shared.
- `use_lockfile = true` uses S3 conditional writes (requires bucket versioning); no DynamoDB lock table.
- Optional per-env behaviour goes in a single `features` object passed through to the module — not `env == "prod"` branches.
- Per-account bootstrap (state bucket, KMS key, OIDC provider, deploy roles) is set up out-of-band; not managed by this repo.

## Module surface

Outputs are the contract with downstream consumers: `catalog_endpoint` (DuckLake `ATTACH` target), `lake_bucket_name` (`DATA_PATH`), `compute_role_arn` (Dagster Cloud OIDC). Tests live in `modules/app/tests/*.tftest.hcl` and run with `tofu -chdir=infra/modules/app test` using `mock_provider "aws" {}` (no credentials).
