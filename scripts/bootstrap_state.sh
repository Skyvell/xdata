#!/usr/bin/env bash
# Bootstrap the OpenTofu state bucket for a given account (one-time per account).
# Usage: bootstrap_state.sh <region> <bucket>

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <region> <bucket>" >&2
    exit 1
fi

region="$1"
bucket="$2"

aws s3api create-bucket \
    --bucket "$bucket" \
    --region "$region" \
    --create-bucket-configuration "LocationConstraint=$region"

aws s3api put-bucket-versioning \
    --bucket "$bucket" \
    --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
    --bucket "$bucket" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms"},"BucketKeyEnabled":true}]}'

aws s3api put-public-access-block \
    --bucket "$bucket" \
    --public-access-block-configuration \
    'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
