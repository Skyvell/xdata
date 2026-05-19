"""DuckLake connection config + connect helper.

Postgres params follow libpq's standard env vars (PGHOST/PGPORT/PGDATABASE/
PGUSER/PGPASSWORD); DuckLake-specific values keep the DUCKLAKE_ prefix.
S3 access uses the default AWS credential chain via httpfs's S3 secret.
"""

import os
from dataclasses import dataclass

import duckdb


@dataclass(frozen=True)
class DuckLake:
    host: str
    port: int
    database: str
    user: str
    data_path: str
    metadata_schema: str

    @classmethod
    def from_env(cls) -> "DuckLake":
        return cls(
            host=os.environ["PGHOST"],
            port=int(os.environ["PGPORT"]),
            database=os.environ["PGDATABASE"],
            user=os.environ["PGUSER"],
            data_path=os.environ["DUCKLAKE_DATA_PATH"],
            metadata_schema=os.environ["DUCKLAKE_METADATA_SCHEMA"],
        )

    def connect(self, *, read_only: bool = False) -> duckdb.DuckDBPyConnection:
        """Open an in-memory DuckDB connection with the DuckLake catalog attached."""
        conn = duckdb.connect(":memory:")
        self._attach_catalog(conn, read_only=read_only)
        return conn

    def _build_catalog_dsn(self) -> str:
        return (
            f"postgres:dbname={self.database} "
            f"host={self.host} "
            f"port={self.port} "
            f"user={self.user} "
            f"sslmode=require"
        )

    def _attach_catalog(self, conn: duckdb.DuckDBPyConnection, *, read_only: bool) -> None:
        conn.execute("INSTALL ducklake; LOAD ducklake;")
        conn.execute("INSTALL httpfs; LOAD httpfs;")
        conn.execute(
            "CREATE OR REPLACE SECRET s3_default (TYPE S3, PROVIDER credential_chain);"
        )
        options = (
            f"DATA_PATH '{self.data_path}', "
            f"METADATA_SCHEMA '{self.metadata_schema}'"
        )
        if read_only:
            options += ", READ_ONLY"
        conn.execute(f"ATTACH 'ducklake:{self._build_catalog_dsn()}' AS ducklake ({options});")
