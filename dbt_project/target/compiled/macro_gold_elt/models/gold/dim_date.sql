WITH date_bounds AS (
    SELECT
        LEAST(
            (SELECT MIN(trade_date) FROM "macro_dw"."analytics"."silver_gold_prices"),
            (SELECT MIN(trade_date) FROM "macro_dw"."analytics"."silver_dxy_index"),
            (SELECT MIN(trade_date) FROM "macro_dw"."analytics"."silver_jisdor_rates")
        ) AS min_date,
        GREATEST(
            (SELECT MAX(trade_date) FROM "macro_dw"."analytics"."silver_gold_prices"),
            (SELECT MAX(trade_date) FROM "macro_dw"."analytics"."silver_dxy_index"),
            (SELECT MAX(trade_date) FROM "macro_dw"."analytics"."silver_jisdor_rates")
        ) AS max_date
),

date_spine AS (
    SELECT
        generate_series(min_date, max_date, INTERVAL '1 day')::DATE AS date_id
    FROM date_bounds
),

jisdor_active_dates AS (
    SELECT DISTINCT trade_date
    FROM "macro_dw"."analytics"."silver_jisdor_rates"
)

SELECT
    d.date_id,
    EXTRACT(YEAR FROM d.date_id)::INT AS year,
    EXTRACT(QUARTER FROM d.date_id)::INT AS quarter,
    EXTRACT(MONTH FROM d.date_id)::INT AS month,
    TRIM(TO_CHAR(d.date_id, 'Day'))::VARCHAR(10) AS day_name,
    (EXTRACT(ISODOW FROM d.date_id) IN (6, 7))::BOOLEAN AS is_weekend,
    (
        EXTRACT(ISODOW FROM d.date_id) NOT IN (6, 7)
        AND j.trade_date IS NULL
    )::BOOLEAN AS is_bi_holiday
FROM date_spine d
LEFT JOIN jisdor_active_dates j
    ON d.date_id = j.trade_date
ORDER BY d.date_id