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

# SQLMesh embeds the DuckLake ATTACH path in a single-quoted SQL literal
# without escaping it, so inlining a password (which libpq's own quoting
# would wrap in single quotes) breaks the outer SQL. Pass the password to
# libpq via its standard env var instead and leave the DSN credential-free.
os.environ["PGPASSWORD"] = os.environ["DUCKLAKE_PASSWORD"]


def _create_metadata_connection_string() -> str:
    return (
        f"postgres:dbname={os.environ['DUCKLAKE_DB']} "
        f"host={os.environ['DUCKLAKE_HOST']} "
        f"port={os.environ['DUCKLAKE_PORT']} "
        f"user={os.environ['DUCKLAKE_USER']} "
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
