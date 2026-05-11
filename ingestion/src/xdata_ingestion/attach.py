"""Print a DuckDB ATTACH script for the rujira DuckLake.

Used by `just explore` — pipes the output into `duckdb -ui -init` so an
interactive DuckDB session opens with the lake already attached.

The output contains the catalog password in plaintext; treat it as transient.
"""

from __future__ import annotations

import json

import boto3

REGION = "eu-north-1"


def attach_sql() -> str:
    rds = boto3.client("rds", region_name=REGION)
    secrets = boto3.client("secretsmanager", region_name=REGION)
    sts = boto3.client("sts", region_name=REGION)

    db = rds.describe_db_instances(DBInstanceIdentifier="ducklake")["DBInstances"][0]
    creds = json.loads(
        secrets.get_secret_value(SecretId=db["MasterUserSecret"]["SecretArn"])[
            "SecretString"
        ]
    )
    account = sts.get_caller_identity()["Account"]

    catalog_dsn = (
        f"host={db['Endpoint']['Address']} port={db['Endpoint']['Port']} "
        f"dbname=metadata user={creds['username']} password={creds['password']} "
        f"sslmode=require"
    )

    return f"""\
INSTALL ducklake;
LOAD ducklake;
INSTALL httpfs;
LOAD httpfs;

CREATE OR REPLACE SECRET s3_lake (TYPE s3, PROVIDER credential_chain, REGION '{REGION}');

ATTACH 'ducklake:postgres:{catalog_dsn}' AS lake
  (DATA_PATH 's3://ducklake-{account}/', METADATA_SCHEMA 'ducklake');

USE lake;
"""


if __name__ == "__main__":
    print(attach_sql())
