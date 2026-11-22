/*
trade_date,indicator,unit,price_value,is_holiday_fill
2026-05-12,GOLD_USD,USD/oz,2685.50,FALSE
2026-05-12,DXY_INDEX,INDEX,103.85,FALSE
2026-05-12,JISDOR_IDR,IDR/USD,16200.00,TRUE (diisi dari 11 Mei)
2026-05-12,GOLD_IDR_GRAM,IDR/gram,1398719.00,TRUE
*/

WITH raw_silver_unioned AS (
    SELECT
        trade_date AS date_id,
        'GOLD_USD'::VARCHAR(20) AS asset_id,   -- <-- Ini yang akan dicocokkan ke dim_asset.asset_id
        close AS raw_close
    FROM {{ ref('silver_gold_prices') }}

    UNION ALL

    SELECT
        trade_date AS date_id,
        'DXY_INDEX'::VARCHAR(20) AS asset_id,  -- <-- Sama dengan PK di dim_asset
        close AS raw_close
    FROM {{ ref('silver_dxy_index') }}

    UNION ALL

    SELECT
        trade_date AS date_id,
        'JISDOR_IDR'::VARCHAR(20) AS asset_id, -- <-- Sama dengan PK di dim_asset
        jisdor_rate AS raw_close
    FROM {{ ref('silver_jisdor_rates') }}
)
SELECT * FROM raw_silver_unioned