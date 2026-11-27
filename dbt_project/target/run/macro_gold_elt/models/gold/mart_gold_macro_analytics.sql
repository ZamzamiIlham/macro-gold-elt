
  create view "macro_dw"."analytics"."mart_gold_macro_analytics__dbt_tmp"
    
    
  as (
    WITH jisdor_trading_days AS(
    SELECT 
        date_id,
        close_value as jisdor_usd_idr
    FROM "macro_dw"."analytics"."fact_market_daily"
    WHERE asset_id = 'JISDOR_IDR'
),
dxy_prices AS(
    SELECT
        date_id,
        close_value as dxy_index_close
    FROM "macro_dw"."analytics"."fact_market_daily"
    WHERE asset_id = 'DXY_INDEX'
),
gold_prices AS(
    SELECT
        date_id,
        close_value as gold_global_usd_oz,
        ma_180_value as gold_ma_180
    FROM "macro_dw"."analytics"."fact_market_daily"
    WHERE asset_id = 'GOLD_USD'
),
analisis_market AS(
    SELECT 
        j.date_id,
        j.jisdor_usd_idr,
        g_latest.gold_global_usd_oz,
        g_latest.gold_ma_180,
        dxy_latest.dxy_index_close
    FROM jisdor_trading_days j 
    LEFT JOIN LATERAL (
        SELECT 
            gold_global_usd_oz,
            gold_ma_180
        FROM gold_prices g
        WHERE g.date_id < j.date_id
        ORDER BY g.date_id DESC
        LIMIT 1
    ) g_latest ON TRUE
    LEFT JOIN LATERAL(
        SELECT 
            dxy_index_close
        FROM dxy_prices d
        WHERE d.date_id < j.date_id
        ORDER BY d.date_id DESC 
        LIMIT 1
    ) dxy_latest ON TRUE
),
summary AS(
    SELECT
        date_id,
        ROUND(gold_global_usd_oz,2) as gold_global_usd_oz,
        ROUND(dxy_index_close,2) as dxy_index_close,
        jisdor_usd_idr,
        ROUND((gold_global_usd_oz*jisdor_usd_idr)/31.1034768,2 ) as gold_local_idr_gram,

        --hitung jisdor_pct_change
        ROUND(((jisdor_usd_idr - LAG(jisdor_usd_idr) OVER (ORDER BY date_id)) / NULLIF(LAG(jisdor_usd_idr) OVER (ORDER BY date_id), 0)) * 100, 4) as jisdor_pct_change,
        --hitung gold_pct_change
        ROUND(((gold_global_usd_oz - LAG(gold_global_usd_oz) OVER (ORDER BY date_id)) / NULLIF(LAG(gold_global_usd_oz) OVER (ORDER BY date_id), 0)) * 100, 4) as gold_usd_pct_change,
        --hitung dxy_pct_change
        ROUND(((dxy_index_close - LAG(dxy_index_close) OVER (ORDER BY date_id)) / NULLIF(LAG(dxy_index_close) OVER (ORDER BY date_id), 0)) * 100, 4) as dxy_pct_change,
        --hitung pct_above_ma180
        ROUND(((gold_global_usd_oz - gold_ma_180) / NULLIF(gold_ma_180, 0)) * 100, 2) AS pct_above_ma180,
        --hitung rolling30d
        ROUND(
            CORR(gold_global_usd_oz, jisdor_usd_idr) OVER (
                ORDER BY date_id
                ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
            )::NUMERIC,
            4
        ) AS rolling_30d_corr
    FROM analisis_market
    WHERE gold_global_usd_oz IS NOT NULL AND dxy_index_close IS NOT NULL
)
SELECT
    date_id,
        CASE 
        WHEN pct_above_ma180 > 0 AND jisdor_pct_change > 0.15 THEN 'SAFE_HAVEN_RALLY'
        WHEN pct_above_ma180 > 0  AND ABS(jisdor_pct_change) <= 0.15 THEN 'GLOBAL_BULL_STABLE_FX'
        WHEN pct_above_ma180 <= 0  AND ABS(jisdor_pct_change) > 0.15 THEN 'FX_DRIVEN_INFLATION'
        WHEN pct_above_ma180 < 0 AND dxy_pct_change > 0.15 THEN 'DXY_PRESSURE_BEARISH'
        ELSE 'NEUTRAL_CONSOLIDATION'
    END AS regime_id,
    gold_global_usd_oz,
    dxy_index_close,
    jisdor_usd_idr,
    gold_local_idr_gram,
    jisdor_pct_change,
    gold_usd_pct_change,
    dxy_pct_change,
    pct_above_ma180,
    rolling_30d_corr
FROM summary
ORDER BY date_id DESC
  );