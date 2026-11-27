/*SELECT
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

        --SELECT
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


2016-01-04 2026-11-20
*/
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
)
SELECT
    generate_series(min_date, max_date, INTERVAL '1 day')::DATE AS date_id
FROM date_bounds
--generate tanggal dari min_date sampai max_date, penambahan 1 hari