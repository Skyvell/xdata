"""SQLMesh project config wired from runner-injected env vars.

The scheduled-runner contract supplies DUCKLAKE_HOST/PORT/DB/USER/PASSWORD/
METADATA_SCHEMA/DATA_PATH. SQLMesh state lives in the same Postgres instance
as the DuckLake catalog (database 'metadata'), under schema 'sqlmesh'.
"""

import os

from sqlmesh.core.config import Config, GatewayConfig, ModelDefaultsConfig
from sqlmesh.core.config.connection import (
    DuckDBAttachOptions,
    DuckDBConnectionConfig,
    PostgresConnectionConfig,
)


def _create_metadata_connection_string() -> str:
    """Return a libpq DSN for DuckLake's ATTACH path.

    DuckLake's `ATTACH 'ducklake:postgres:...'` parses the inner connection
    string as libpq key=value pairs, not as a URL — a `postgres://` URL is
    interpreted as a filesystem path and the attach fails.
    """
    password = os.environ["DUCKLAKE_PASSWORD"].replace("\\", "\\\\").replace("'", "\\'")
    return (
        f"postgres:dbname={os.environ['DUCKLAKE_DB']} "
        f"host={os.environ['DUCKLAKE_HOST']} "
        f"port={os.environ['DUCKLAKE_PORT']} "
        f"user={os.environ['DUCKLAKE_USER']} "
        f"password='{password}' "
        f"sslmode=require"
    )


config = Config(
    gateways={
        "dev": GatewayConfig(
            connection=DuckDBConnectionConfig(
                extensions=["ducklake"],
                catalogs={
                    "ducklake": DuckDBAttachOptions(
                        type="ducklake",
                        path=_create_metadata_connection_string(),
                        data_path=os.environ["DUCKLAKE_DATA_PATH"],
                        metadata_schema=os.environ["DUCKLAKE_METADATA_SCHEMA"],
                    ),
                },
            ),
            state_connection=PostgresConnectionConfig(
                host=os.environ["DUCKLAKE_HOST"],
                port=int(os.environ["DUCKLAKE_PORT"]),
                user=os.environ["DUCKLAKE_USER"],
                password=os.environ["DUCKLAKE_PASSWORD"],
                database=os.environ["DUCKLAKE_DB"],
                sslmode="require",
            ),
            state_schema=os.environ.get("SQLMESH_STATE_SCHEMA", "sqlmesh"),
        ),
    },
    default_gateway="dev",
    model_defaults=ModelDefaultsConfig(
        dialect="duckdb",
        start="2026-01-01",
    ),
)
