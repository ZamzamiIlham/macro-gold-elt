
  create view "macro_dw"."analytics"."silver_dxy_index__dbt_tmp"
    
    
  as (
    WITH dxy_index AS(
    SELECT 
        price_date,
        open,
        high,
        close,
        ingested_at,
        ROW_NUMBER() OVER(PARTITION BY price_date ORDER BY ingested_at DESC) as urutan
    FROM "macro_dw"."raw"."dxy_index" 
    WHERE close IS NOT NULL
)
SELECT 
    price_date::DATE AS trade_date,
    open,
    high,
    close,
    ingested_at
FROM dxy_index
WHERE urutan = 1
ORDER BY trade_date DESC
  );