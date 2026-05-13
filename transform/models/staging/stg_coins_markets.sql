MODEL (
  name ducklake.staging.stg_coins_markets,
  kind VIEW,
);

SELECT
    id AS coin_id,
    symbol,
    name,
    image,
    market_cap_rank,
    current_price,
    high_24h,
    low_24h,
    market_cap,
    fully_diluted_valuation,
    total_volume,
    price_change_24h,
    price_change_percentage_24h,
    market_cap_change_24h,
    market_cap_change_percentage_24h,
    circulating_supply,
    total_supply,
    max_supply,
    ath,
    ath_change_percentage,
    atl,
    atl_change_percentage,
    CAST(ath_date AS TIMESTAMP) AS ath_date,
    CAST(atl_date AS TIMESTAMP) AS atl_date,
    CAST(last_updated AS TIMESTAMP) AS last_updated
FROM ducklake.raw.coins_markets
