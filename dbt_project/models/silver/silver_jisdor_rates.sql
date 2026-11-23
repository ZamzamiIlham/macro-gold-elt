WITH jisdor_rates AS (
    SELECT
        rate_date,
        currency,
        jisdor_rate,
        ingested_at,
        ROW_NUMBER() OVER(PARTITION BY rate_date ORDER BY ingested_at DESC) as urutan
    FROM {{ source('raw', 'jisdor_rates') }}
    WHERE jisdor_rate IS NOT NULL)
SELECT 
    rate_date::DATE AS trade_date,
    currency,
    jisdor_rate,
    ingested_at
FROM jisdor_rates
WHERE urutan = 1
ORDER BY trade_date DESC