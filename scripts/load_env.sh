#!/usr/bin/env bash
# Source-only: sets PG* and DUCKLAKE_* env vars from the active AWS profile.
# Use as:  . ./scripts/load_env.sh
#
# Uses the profile's configured region too — this project's convention is
# "one AWS account = one environment", so AWS_PROFILE is the env switch.
set -euo pipefail

export AWS_REGION=$(aws configure get region)

rds=$(aws rds describe-db-instances --db-instance-identifier metadata --output json)
export PGHOST=$(jq -r '.DBInstances[0].Endpoint.Address' <<<"$rds")
export PGPORT=$(jq -r '.DBInstances[0].Endpoint.Port' <<<"$rds")
export PGDATABASE=metadata

secret=$(aws secretsmanager get-secret-value \
    --secret-id "$(jq -r '.DBInstances[0].MasterUserSecret.SecretArn' <<<"$rds")" \
    --output text --query SecretString)
export PGUSER=$(jq -r .username <<<"$secret")
export PGPASSWORD=$(jq -r .password <<<"$secret")

export DUCKLAKE_METADATA_SCHEMA=ducklake
export DUCKLAKE_DATA_PATH=s3://ducklake-$(aws sts get-caller-identity --query Account --output text)/
