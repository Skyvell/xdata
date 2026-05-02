# OpenTofu project structure

Reference for structuring an OpenTofu project that deploys one application to multiple environments (dev, int, prod) with isolated state, a CI-driven apply pipeline, and no duplicated HCL across environments. The `aws` provider is used throughout; the patterns transfer to other providers.

---

## Layout

```
infra/
├── modules/app/
│   ├── variables.tf
│   ├── outputs.tf
│   ├── locals.tf
│   ├── networking.tf          # split by concern; one file per topic
│   ├── compute.tf
│   ├── database.tf
│   ├── iam.tf
│   └── tests/basic.tftest.hcl
├── live/
│   ├── main.tf                # single module call
│   ├── variables.tf           # pass-through declarations
│   ├── providers.tf
│   └── backend.tf             # empty; filled at init
├── config/
│   ├── {dev,int,prod}.tfvars
│   └── {dev,int,prod}.s3.tfbackend
├── .tflint.hcl
└── trivy.yaml
```

A `.pre-commit-config.yaml` lives at the repository root (see [Pre-commit hooks](#pre-commit-hooks)).

OpenTofu merges every `.tf` in a directory, so splitting the module by concern keeps files focused without spawning separate state. `live/` is the only directory `tofu` runs in; `config/` is pure data — adding an environment means adding two files. Commit `.terraform.lock.hcl` for reproducible `init`. Per-account foundation (state bucket, OIDC, deploy roles) is set up once, out-of-band — see [State bootstrap](#state-bootstrap).

---

## Environments as data

Environments differ only through `.tfvars` values and backend configuration. Keep per-environment knobs explicit; resist `env == "prod"` branches inside the module — add a variable or a field on a `features` object instead.

### config/&lt;env&gt;.tfvars

```hcl
# dev.tfvars
environment   = "dev"
instance_size = "small"
vpc_cidr      = "10.0.0.0/16"
```

| Variable | dev | int | prod |
|---|---|---|---|
| `instance_size` | `small` | `medium` | `large` |
| `vpc_cidr` | `10.0.0.0/16` | `10.1.0.0/16` | `10.2.0.0/16` |

### config/&lt;env&gt;.s3.tfbackend

```hcl
bucket       = "myapp-tofu-state"
key          = "dev/opentofu.tfstate"
region       = "eu-north-1"
kms_key_id   = "arn:aws:kms:eu-north-1:000000000000:key/…"  # printed by bootstrap-state
use_lockfile = true
encrypt      = true
```

Only `key` varies across environments (`<env>/opentofu.tfstate`). `use_lockfile = true` replaces the deprecated DynamoDB lock table with S3 conditional writes; it requires bucket versioning. The bucket and key are created by [State bootstrap](#state-bootstrap).

---

## Root configuration

### live/backend.tf

Empty; `-backend-config=<env>.s3.tfbackend` fills it at init time, so no environment identifier appears in HCL.

```hcl
terraform {
  backend "s3" {}
}
```

### live/providers.tf

```hcl
terraform {
  required_version = "~> 1.11"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"

  default_tags {
    tags = {
      Project     = "myapp"
      Environment = var.environment
      ManagedBy   = "opentofu"
    }
  }
}
```

No `assume_role` block: `aws-actions/configure-aws-credentials` sets OIDC credentials before OpenTofu runs, and each GitHub Environment stores its own `AWS_ROLE_ARN` pointing at the deploy role in the matching account.

`default_tags` covers every resource, so individual resources only declare tags unique to them (e.g. `Name`).

### live/main.tf

```hcl
module "app" {
  source = "../modules/app"

  environment   = var.environment
  instance_size = var.instance_size
  vpc_cidr      = var.vpc_cidr
}
```

### live/variables.tf

```hcl
variable "environment"   { type = string }
variable "instance_size" { type = string }
variable "vpc_cidr"      { type = string }
```

---

## Module

One file per concern (networking, compute, database, iam). Resources reference each other through plain resource addresses.

### modules/app/variables.tf

```hcl
variable "environment" {
  type        = string
  description = "Environment name (dev, int, prod)"
}

variable "instance_size" { type = string }
variable "vpc_cidr"      { type = string }
```

For optional per-environment behaviour, pass a single `features` object rather than scattering `environment == "prod"` checks across the module:

```hcl
variable "features" {
  type = object({
    multi_az    = bool
    waf_enabled = bool
  })
}
```

### modules/app/locals.tf

```hcl
locals {
  name_prefix = "myapp-${var.environment}"
}
```

### modules/app/networking.tf (example)

One concrete file to illustrate the pattern; other concerns follow the same shape.

```hcl
data "aws_availability_zones" "available" { state = "available" }

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name_prefix}-vpc" }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = { Name = "${local.name_prefix}-private-${count.index}" }
}
```

### modules/app/outputs.tf

Outputs are the module's public surface. Expose identifiers a caller needs to compose with other stacks (networking, IAM, monitoring), nothing more.

```hcl
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC hosting the application."
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "Subnets for compute and database tiers."
}

output "app_security_group_id" {
  value       = aws_security_group.app.id
  description = "Security group attached to application instances."
}
```

### modules/app/tests/basic.tftest.hcl

Mocked — no API calls, no credentials. Run with `tofu -chdir=infra/modules/app test`.

```hcl
mock_provider "aws" {}

run "dev_wiring" {
  variables {
    environment   = "dev"
    instance_size = "small"
    vpc_cidr      = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR must match input"
  }
}
```

---

## Local workflow

Local plans only; applies go through the pipeline. A `justfile` or equivalent task runner holds the recipes.

```just
plan-dev:
    tofu -chdir=infra/live init -backend-config=../config/dev.s3.tfbackend -reconfigure
    tofu -chdir=infra/live plan -var-file=../config/dev.tfvars

plan-int:
    tofu -chdir=infra/live init -backend-config=../config/int.s3.tfbackend -reconfigure
    tofu -chdir=infra/live plan -var-file=../config/int.tfvars

plan-prod:
    tofu -chdir=infra/live init -backend-config=../config/prod.s3.tfbackend -reconfigure
    tofu -chdir=infra/live plan -var-file=../config/prod.tfvars
```

---

## Pre-commit hooks

Catches formatting, lint, policy, and stale module documentation before code is pushed. CI re-runs the same checks; local hooks shorten the feedback loop from minutes to seconds.

### .pre-commit-config.yaml

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.97.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
        args: [--args=--recursive]
      - id: terraform_docs
        args: [--args=--config=.terraform-docs.yml]
      - id: terraform_trivy
        args: [--args=--config=infra/trivy.yaml]
```

`pre-commit-terraform` invokes `tofu` when present (despite the name). Install with `pre-commit install` once per clone.

---

## Module documentation

`terraform-docs` reads `variables.tf` and `outputs.tf` and writes the inputs/outputs tables into the module's `README.md`. Run via the pre-commit hook above; the README never goes stale because the hook fails commits whose declarations don't match the rendered tables.

### .terraform-docs.yml

```yaml
formatter: markdown table
output:
  file: README.md
  mode: inject
  template: |-
    <!-- BEGIN_TF_DOCS -->
    {{ .Content }}
    <!-- END_TF_DOCS -->
sort:
  enabled: true
  by: required
```

Each module gets a `README.md` with a one-paragraph summary above the markers; everything between the markers is generated.

---

## CI/CD

Three workflows cover the lifecycle. Each uses OIDC to assume the per-environment deploy role; no long-lived AWS keys exist anywhere.

**GitHub Environments.** Create `dev`, `int`, `prod` under Settings → Environments. Each stores an `AWS_ROLE_ARN` variable for its target AWS account; `prod` requires reviewers.

**`ci.yml` — runs on every PR touching `infra/**`.** Gates merge on `tofu fmt -check`, `tofu validate`, `tflint --recursive`, `trivy config`, `tofu test`, and a plan against dev. The plan is written with `-out=tfplan.binary`, uploaded as an artifact, rendered to text, posted as a PR comment, and fed to `infracost` for a cost-diff comment. Pin every third-party action to a commit SHA.

**`deploy.yml` — applies on merge to `main` (dev) or manual dispatch (int, prod).** The `environment:` key routes to the matching GitHub Environment and triggers prod's reviewer gate. `concurrency.cancel-in-progress: false` is required — cancelling mid-apply leaves state locked and resources half-created. For dev, the job downloads the `tfplan-dev` artifact from the merged PR's CI run and runs `tofu apply tfplan.binary` directly, so what ships is exactly what was reviewed (use `dawidd6/action-download-artifact` — the built-in download action cannot reach across workflow runs). Int and prod plan-and-apply in one job since there is no PR artifact; the reviewer gate is the equivalent checkpoint.

**`drift.yml` — scheduled, weekday mornings.** Matrix over `[dev, int, prod]`. Runs `tofu plan -detailed-exitcode`; exit code 2 means drift (1 means error), so capture the exit code explicitly and only alert on 2. Wire the alert step to Slack via `slackapi/slack-github-action` or to PagerDuty.

---

## State bootstrap

One-time-per-AWS-account, set up manually in the AWS Console. Nothing here changes after initial setup, so click-ops is fine — and the doc avoids drifting from whatever script approach you'd otherwise need to maintain.

### What to create

- **State bucket** `<project>-tofu-state` — versioning enabled, all public access blocked, SSE-KMS with a customer-managed key. State holds secrets in plaintext.
- **KMS key** — customer-managed, rotation enabled. Key policy grants encrypt/decrypt to the deploy roles.
- **GitHub OIDC provider** — URL `https://token.actions.githubusercontent.com`, audience `sts.amazonaws.com`. AWS validates the JWT chain directly; the thumbprint is no longer security-relevant.
- **Deploy roles**, one per environment (`<project>-deploy-{dev,int,prod}`) with the trust policy below, plus a permissions policy granting access to the matching state-bucket prefix and to whatever `live/` actually manages.

### Trust policy

The line most setups get wrong is `StringLike` on `sub` — it restricts each role to one repository **and** one environment. Without it, any repo in your org can assume the role.

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::<ACCOUNT>:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike":   { "token.actions.githubusercontent.com:sub": "repo:<ORG>/<REPO>:environment:<ENV>" }
    }
  }]
}
```

### Wiring

Paste the KMS key ARN into each `config/<env>.s3.tfbackend` as `kms_key_id`. Set each role ARN as the `AWS_ROLE_ARN` variable on the matching GitHub Environment.

---

## Lint and policy configuration

### infra/.tflint.hcl

```hcl
plugin "aws" {
  enabled = true
  version = "0.47.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
```

### infra/trivy.yaml

Trivy is the policy scanner — single binary, faster than Checkov, and the same tool covers IaC, container, and dependency scanning. Suppressions live alongside their justification.

```yaml
severity: HIGH,CRITICAL
misconfiguration:
  include-non-failures: false

# Each ignored finding documents the resource and the reason. Review quarterly.
ignore:
  - id: AVD-AWS-0089          # S3 access logging
    paths:
      - "infra/modules/app/storage.tf"
    statement: "Logs bucket itself; logging it would recurse."
```

---

## Ephemeral secrets

OpenTofu 1.11+ `ephemeral` blocks expose values at apply time without writing them to state. Use for secrets that a resource needs to consume but must never be persisted.

```hcl
ephemeral "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "myapp/${var.environment}/db-password"
}
```

For database master passwords specifically, prefer provider-managed secrets (e.g. `aws_db_instance.manage_master_user_password = true`), which keep the password inside the cloud provider and out of OpenTofu entirely.

---

## Design choices

- **Environment is data, not code.** One root configuration; differences live in `config/*.tfvars` and `config/*.s3.tfbackend`. Per-environment folders duplicate HCL and drift apart.
- **Separate backend key per environment.** A mistake in dev cannot corrupt prod state. Workspaces share a backend and are too easy to misselect.
- **One module, multiple files.** Split by concern; adopt multiple modules only when independent deploy cycles are needed or `tofu plan` exceeds ~30 s.
- **Plan locally, apply in CI.** A local apply bypasses lint, policy, approval, and audit trail.
- **Direct OIDC to the target account.** The GitHub Action assumes the per-environment deploy role; the provider has no `assume_role` block. A misconfigured dev role cannot reach prod.
- **S3 native locking.** `use_lockfile = true` uses S3 conditional writes; no DynamoDB table, no inter-service dependency.
- **`features` object for toggles.** Per-environment capabilities stay explicit and independent of the environment name.

---

## When to evolve

- **Split the module** when plan times exceed ~30 s or when parts of the stack need to deploy independently. Use `moved` blocks to refactor state without manual surgery.
- **Add Terragrunt** only when wiring outputs between independent modules has become repetitive enough that `terragrunt run-all plan` saves meaningful time. With one module, it is pure overhead.
- **Promote bootstrap to code** when you start onboarding multiple AWS accounts and Console click-ops becomes a liability. A second OpenTofu root configuration (or CloudFormation stack) handles the foundation declaratively. Below that scale it is ceremony.
- **Add a `global/` stack** for once-per-org resources that *aren't* bootstrap-blocking: shared DNS zones, organization-wide IAM, route-53 delegation.
