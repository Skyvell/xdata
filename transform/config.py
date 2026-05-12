"""SQLMesh project config wired from runner-injected env vars.

The scheduled-runner contract supplies DUCKLAKE_HOST/PORT/DB/USER/PASSWORD/
METADATA_SCHEMA/DATA_PATH. SQLMesh state lives in the same Postgres instance
as the DuckLake catalog (database 'metadata'), under schema 'sqlmesh'.
"""

import os
from urllib.parse import quote

from sqlmesh.core.config import Config, GatewayConfig, ModelDefaultsConfig
from sqlmesh.core.config.connection import (
    DuckDBAttachOptions,
    DuckDBConnectionConfig,
    PostgresConnectionConfig,
)


def _create_metadata_connection_string() -> str:
    user = quote(os.environ["DUCKLAKE_USER"], safe="")
    password = quote(os.environ["DUCKLAKE_PASSWORD"], safe="")
    host = os.environ["DUCKLAKE_HOST"]
    port = os.environ["DUCKLAKE_PORT"]
    db = os.environ["DUCKLAKE_DB"]
    return f"postgres://{user}:{password}@{host}:{port}/{db}"


config = Config(
    gateways={
        "dev": GatewayConfig(
            connection=DuckDBConnectionConfig(
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
