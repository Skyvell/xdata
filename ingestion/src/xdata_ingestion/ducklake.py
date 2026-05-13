"""DuckLake destination wired from runner-injected env vars.

Postgres connection params follow libpq's standard env var names (PGHOST,
PGPORT, PGDATABASE, PGUSER, PGPASSWORD); DuckLake-specific values
(DUCKLAKE_METADATA_SCHEMA, DUCKLAKE_DATA_PATH) keep their own prefix.
S3 access uses the default AWS credential chain — the task role grants
the needed S3 permissions.
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
                "host": os.environ["PGHOST"],
                "port": int(os.environ["PGPORT"]),
                "username": os.environ["PGUSER"],
                "password": os.environ["PGPASSWORD"],
                "database": os.environ["PGDATABASE"],
                "query": {"sslmode": "require"},
            }),
            storage=os.environ["DUCKLAKE_DATA_PATH"],
        )
    )
