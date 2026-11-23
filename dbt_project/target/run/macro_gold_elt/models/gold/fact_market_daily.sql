
  create view "macro_dw"."analytics"."fact_market_daily__dbt_tmp"
    
    
  as (
    WITH raw_summary AS (
    SELECT 
        trade_date,
        'DXY_INDEX'::VARCHAR(20) AS asset_id,
        close AS close_value
    FROM "macro_dw"."analytics"."silver_dxy_index"

    UNION ALL 

    SELECT 
        trade_date,
        'GOLD_USD'::VARCHAR(20) AS asset_id,
        close AS close_value
    FROM "macro_dw"."analytics"."silver_gold_prices"

    UNION ALL 

    SELECT 
        trade_date,
        'JISDOR_IDR'::VARCHAR(20) AS asset_id,
        jisdor_rate AS close_value
    FROM "macro_dw"."analytics"."silver_jisdor_rates"
)

SELECT 
    rs.asset_id,
    rs.trade_date AS date_id,
    rs.close_value::DECIMAL(14, 4) AS close_value,
    ROUND(
        (
            (rs.close_value - LAG(rs.close_value) OVER (PARTITION BY rs.asset_id ORDER BY rs.trade_date))
            / NULLIF(LAG(rs.close_value) OVER (PARTITION BY rs.asset_id ORDER BY rs.trade_date), 0) * 100
        ),
        4
    )::DECIMAL(8, 4) AS daily_pct_change,
    ROUND(
        AVG(rs.close_value) OVER (
            PARTITION BY rs.asset_id 
            ORDER BY rs.trade_date
            ROWS BETWEEN 179 PRECEDING AND CURRENT ROW
        ),
        4
    )::DECIMAL(14, 4) AS ma_180_value
FROM raw_summary rs
INNER JOIN "macro_dw"."analytics"."dim_date" d 
    ON d.date_id = rs.trade_date
WHERE d.is_weekend = FALSE
ORDER BY rs.trade_date DESC, rs.asset_id
  );