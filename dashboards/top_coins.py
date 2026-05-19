import marimo

__generated_with = "0.23.6"
app = marimo.App(width="medium")


@app.cell
def _():
    import altair as alt
    import marimo as mo

    from xdata_shared.ducklake import DuckLake

    return DuckLake, alt, mo


@app.cell
def _(mo):
    mo.md("""
    # Top coins
    """)
    return


@app.cell
def _(DuckLake):
    conn = DuckLake.from_env().connect()
    return (conn,)


@app.cell
def _(conn):
    df = conn.sql(
        """
        SELECT
            coin_id,
            symbol,
            name,
            market_cap_rank,
            current_price,
            market_cap,
            total_volume,
            price_change_percentage_24h,
            last_updated
        FROM ducklake.marts.top_coins
        ORDER BY market_cap_rank
        """
    ).df()
    return (df,)


@app.cell
def _(df, mo):
    total_market_cap = float(df["market_cap"].sum())
    total_volume = float(df["total_volume"].sum())
    mo.hstack(
        [
            mo.stat(label="Total market cap", value=f"${total_market_cap / 1e12:.2f}T"),
            mo.stat(label="24h volume", value=f"${total_volume / 1e9:.2f}B"),
            mo.stat(label="Coins", value=str(len(df))),
        ],
        gap=2,
    )
    return


@app.cell
def _(alt, df, mo):
    market_cap_chart = (
        alt.Chart(df)
        .mark_bar()
        .encode(
            x=alt.X("market_cap:Q", title="Market cap (USD)"),
            y=alt.Y("symbol:N", sort="-x", title=None),
            tooltip=["name", "market_cap", "current_price"],
        )
        .properties(title="Market cap by coin", height=600)
    )
    mo.ui.altair_chart(market_cap_chart)
    return


@app.cell
def _(alt, df, mo):
    change_chart = (
        alt.Chart(df)
        .mark_bar()
        .encode(
            x=alt.X("price_change_percentage_24h:Q", title="24h change (%)"),
            y=alt.Y("symbol:N", sort="-x", title=None),
            color=alt.condition(
                "datum.price_change_percentage_24h > 0",
                alt.value("#2ca02c"),
                alt.value("#d62728"),
            ),
            tooltip=["name", "price_change_percentage_24h"],
        )
        .properties(title="24h % change", height=600)
    )
    mo.ui.altair_chart(change_chart)
    return


@app.cell
def _(df, mo):
    mo.ui.table(df, page_size=50, selection=None)
    return


if __name__ == "__main__":
    app.run()
