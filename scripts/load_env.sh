#!/usr/bin/env bash
# Source-only: sets PG* and DUCKLAKE_* env vars from the active AWS profile.
# Use as:  . ./scripts/load_env.sh
#
# Uses the profile's configured region too — this project's convention is
# "one AWS account = one environment", so AWS_PROFILE is the env switch.
#
# Each value is assigned before being exported so command-substitution
# failures (e.g. expired SSO) propagate under `set -e`; `export FOO=$(...)`
# would silently swallow them via the export builtin's exit status.
set -euo pipefail

AWS_REGION=$(aws configure get region)
export AWS_REGION

rds=$(aws rds describe-db-instances --db-instance-identifier metadata --output json)
PGHOST=$(jq -r '.DBInstances[0].Endpoint.Address' <<<"$rds")
PGPORT=$(jq -r '.DBInstances[0].Endpoint.Port' <<<"$rds")
PGDATABASE=metadata
export PGHOST PGPORT PGDATABASE

secret_arn=$(jq -r '.DBInstances[0].MasterUserSecret.SecretArn' <<<"$rds")
secret=$(aws secretsmanager get-secret-value \
    --secret-id "$secret_arn" --output text --query SecretString)
PGUSER=$(jq -r .username <<<"$secret")
PGPASSWORD=$(jq -r .password <<<"$secret")
export PGUSER PGPASSWORD

account=$(aws sts get-caller-identity --query Account --output text)
DUCKLAKE_METADATA_SCHEMA=ducklake
DUCKLAKE_DATA_PATH="s3://ducklake-${account}/"
export DUCKLAKE_METADATA_SCHEMA DUCKLAKE_DATA_PATH
