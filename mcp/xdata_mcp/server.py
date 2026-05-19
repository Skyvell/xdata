from fastmcp import FastMCP

from xdata_mcp.tools.marts import marts_mcp


def create_server() -> FastMCP:
    mcp = FastMCP(
        name="xdata",
        instructions="""
        This server exposes DuckLake query tools grouped by category.
        Use marts_* tools to list, describe, and query mart tables in the
        DuckLake catalog (schema `marts`).
        """,
        on_duplicate="error",
    )

    mcp.mount(marts_mcp, namespace="marts")

    return mcp


mcp = create_server()
