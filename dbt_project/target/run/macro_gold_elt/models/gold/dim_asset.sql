
  create view "macro_dw"."analytics"."dim_asset__dbt_tmp"
    
    
  as (
    SELECT
    asset_id,
    asset_name,
    ticker_symbol,
    asset_category,
    unit_measure,
    source_authority
FROM "macro_dw"."analytics_gold"."mapping_asset"
  );