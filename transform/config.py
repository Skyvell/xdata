"""SQLMesh project config wired from runner-injected env vars.

Postgres connection params follow libpq's standard env var names
(PGHOST/PGPORT/PGDATABASE/PGUSER/PGPASSWORD); DuckLake-specific values
(DUCKLAKE_METADATA_SCHEMA, DUCKLAKE_DATA_PATH) keep their own prefix.
SQLMesh state lives in the same Postgres instance as the DuckLake catalog,
under schema 'sqlmesh'.
"""

import os

from sqlmesh.core.config import Config, GatewayConfig, ModelDefaultsConfig
from sqlmesh.core.config.connection import (
    DuckDBAttachOptions,
    DuckDBConnectionConfig,
    PostgresConnectionConfig,
)


def _create_metadata_connection_string() -> str:
    """Return a credential-free libpq DSN for DuckLake's ATTACH path.

    SQLMesh embeds this in a single-quoted SQL literal without escaping it,
    so inlining a password would break the outer SQL when libpq's own quoting
    introduces single quotes. The password is supplied to libpq via PGPASSWORD
    in the runner's task env instead.
    """
    return (
        f"postgres:dbname={os.environ['PGDATABASE']} "
        f"host={os.environ['PGHOST']} "
        f"port={os.environ['PGPORT']} "
        f"user={os.environ['PGUSER']} "
        f"sslmode=require"
    )


config = Config(
    gateways={
        "dev": GatewayConfig(
            connection=DuckDBConnectionConfig(
                extensions=["ducklake", "httpfs"],
                # DuckDB's httpfs extension doesn't use the AWS credential
                # chain by default; this secret tells it to read creds from
                # the Fargate task role (and any standard AWS env vars).
                secrets={
                    "s3_default": {
                        "TYPE": "S3",
                        "PROVIDER": "credential_chain",
                    },
                },
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
                host=os.environ["PGHOST"],
                port=int(os.environ["PGPORT"]),
                user=os.environ["PGUSER"],
                password=os.environ["PGPASSWORD"],
                database=os.environ["PGDATABASE"],
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
