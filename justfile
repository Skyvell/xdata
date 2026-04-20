# Project task runner
# Install just: https://github.com/casey/just
# Usage: just <recipe>

# List available recipes
default:
    @just --list

# ── Infrastructure ────────────────────────────────────────────────────────────

# Bootstrap the OpenTofu state bucket for a given account (one-time per account).
# Usage: just bootstrap-state eu-north-1 myapp-tofu-state
bootstrap-state region bucket:
    aws s3api create-bucket \
        --bucket {{bucket}} \
        --region {{region}} \
        --create-bucket-configuration LocationConstraint={{region}}
    aws s3api put-bucket-versioning \
        --bucket {{bucket}} \
        --versioning-configuration Status=Enabled
    aws s3api put-bucket-encryption \
        --bucket {{bucket}} \
        --server-side-encryption-configuration \
        '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms"},"BucketKeyEnabled":true}]}'
    aws s3api put-public-access-block \
        --bucket {{bucket}} \
        --public-access-block-configuration \
        'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
