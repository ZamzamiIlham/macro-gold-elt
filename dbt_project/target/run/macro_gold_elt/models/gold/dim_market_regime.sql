
  create view "macro_dw"."analytics"."dim_market_regime__dbt_tmp"
    
    
  as (
    SELECT 
    regime_id,
    regime_label,
    risk_level,
    action_recommendation
FROM "macro_dw"."analytics_gold"."mapping_regime"
  );