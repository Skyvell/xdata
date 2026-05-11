"""DuckLake destination wired to the AWS catalog + lake bucket.

Authenticates to Postgres via RDS IAM authentication — `boto3` generates a
short-lived auth token at runtime, no long-lived password is involved. The
caller's IAM principal needs `rds-db:connect` on DB_USER.
"""

import boto3
from dlt.common.configuration.specs import ConnectionStringCredentials
from dlt.destinations import ducklake
from dlt.destinations.impl.ducklake.configuration import DuckLakeCredentials

INSTANCE_ID = "ducklake"

# TODO: switch to a dedicated app-level user once one exists in the catalog.
# When you do, also update the rds-db:connect Resource ARN in
# infra/modules/app/iam.tf to reference the new user.
DB_USER = "ducklake_admin"


def destination():
    rds = boto3.client("rds")
    sts = boto3.client("sts")

    db = rds.describe_db_instances(DBInstanceIdentifier=INSTANCE_ID)["DBInstances"][0]
    host = db["Endpoint"]["Address"]
    port = db["Endpoint"]["Port"]
    db_name = db["DBName"]

    token = rds.generate_db_auth_token(DBHostname=host, Port=port, DBUsername=DB_USER)
    account_id = sts.get_caller_identity()["Account"]

    return ducklake(
        credentials=DuckLakeCredentials(
            catalog=ConnectionStringCredentials({
                "drivername": "postgresql",
                "host": host,
                "port": port,
                "username": DB_USER,
                "password": token,
                "database": db_name,
                "query": {"sslmode": "require"},
            }),
            storage=f"s3://ducklake-{account_id}/",
        )
    )
