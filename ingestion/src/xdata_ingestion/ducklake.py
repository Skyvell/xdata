"""DuckLake destination wired from runner-injected env vars.

The scheduled-runner task definition injects DUCKLAKE_* env vars: HOST, PORT,
DB, USER, PASSWORD (the latter two from the RDS-managed master secret),
METADATA_SCHEMA, and DATA_PATH. S3 access uses the default AWS credential
chain — the task role grants the needed S3 permissions.
"""

import os

from dlt.common.configuration.specs import ConnectionStringCredentials
from dlt.destinations import ducklake
from dlt.destinations.impl.ducklake.configuration import DuckLakeCredentials


def destination():
    return ducklake(
        credentials=DuckLakeCredentials(
            metadata_schema=os.environ["DUCKLAKE_METADATA_SCHEMA"],
            catalog=ConnectionStringCredentials({
                "drivername": "postgresql",
                "host": os.environ["DUCKLAKE_HOST"],
                "port": int(os.environ["DUCKLAKE_PORT"]),
                "username": os.environ["DUCKLAKE_USER"],
                "password": os.environ["DUCKLAKE_PASSWORD"],
                "database": os.environ["DUCKLAKE_DB"],
                "query": {"sslmode": "require"},
            }),
            storage=os.environ["DUCKLAKE_DATA_PATH"],
        )
    )
