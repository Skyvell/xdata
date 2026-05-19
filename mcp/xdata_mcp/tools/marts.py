import re

from fastmcp import FastMCP

from xdata_shared.ducklake import DuckLake
from xdata_shared.serialization import jsonable

marts_mcp = FastMCP("marts")

ducklake = DuckLake.from_env()

_MART_NAME_RE = re.compile(r"^[a-zA-Z_][a-zA-Z0-9_]*$")


@marts_mcp.tool
def list_marts() -> list[str]:
    """List mart tables available in the DuckLake (schema `marts`)."""
    with ducklake.connect(read_only=True) as conn:
        rows = conn.execute(
            "SELECT table_name FROM information_schema.tables "
            "WHERE table_catalog = 'ducklake' AND table_schema = 'marts' "
            "ORDER BY table_name"
        ).fetchall()
        return [r[0] for r in rows]


@marts_mcp.tool
def describe_mart(name: str) -> list[dict]:
    """Describe columns of a mart table. `name` must be a valid SQL identifier."""
    if not _MART_NAME_RE.match(name):
        raise ValueError(f"invalid mart name: {name!r}")
    with ducklake.connect(read_only=True) as conn:
        cur = conn.execute(f'DESCRIBE ducklake.marts."{name}"')
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]


@marts_mcp.tool
def query_marts(sql: str, max_rows: int = 10000) -> dict:
    """Run a read-only SQL query against the DuckLake. Returns columns + rows."""
    with ducklake.connect(read_only=True) as conn:
        cur = conn.execute(sql)
        columns = [d[0] for d in cur.description]
        rows = cur.fetchmany(max_rows + 1)
        truncated = len(rows) > max_rows
        return {
            "columns": columns,
            "rows": [[jsonable(v) for v in row] for row in rows[:max_rows]],
            "truncated": truncated,
        }
