MODEL (
  name ducklake.marts.top_coins,
  kind FULL,
);

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
FROM ducklake.staging.stg_coins_markets
WHERE market_cap_rank <= 50
ORDER BY market_cap_rank
