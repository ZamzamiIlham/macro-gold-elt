WITH gold_prices AS(
    SELECT 
        price_date,
        open,
        high,
        close,
        ingested_at,
        ROW_NUMBER() OVER(PARTITION BY price_date ORDER BY ingested_at DESC) as urutan
    FROM "macro_dw"."raw"."gold_prices" 
    WHERE close IS NOT NULL
)
SELECT 
    price_date::DATE AS trade_date,
    open,
    high,
    close,
    ingested_at
FROM gold_prices
WHERE urutan = 1