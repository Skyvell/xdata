"""DuckLake destination wired to the AWS catalog + lake bucket.

Fetches the catalog password from the RDS-managed Secrets Manager secret at
runtime so it never lives on disk locally. AWS auth via boto3's default chain.
"""

from __future__ import annotations

import json

import boto3
from dlt.destinations import ducklake
from dlt.destinations.impl.ducklake.configuration import DuckLakeCredentials

REGION = "eu-north-1"


def destination():
    rds = boto3.client("rds", region_name=REGION)
    secrets = boto3.client("secretsmanager", region_name=REGION)
    sts = boto3.client("sts", region_name=REGION)

    db = rds.describe_db_instances(DBInstanceIdentifier="ducklake")["DBInstances"][0]
    creds = json.loads(
        secrets.get_secret_value(SecretId=db["MasterUserSecret"]["SecretArn"])[
            "SecretString"
        ]
    )

    return ducklake(
        credentials=DuckLakeCredentials(
            catalog=(
                f"postgres://{creds['username']}:{creds['password']}"
                f"@{db['Endpoint']['Address']}:{db['Endpoint']['Port']}"
                f"/metadata?sslmode=require"
            ),
            storage=f"s3://ducklake-{sts.get_caller_identity()['Account']}/",
        )
    )
