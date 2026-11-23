
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select asset_id
from "macro_dw"."analytics"."fact_market_daily"
where asset_id is null



  
  
      
    ) dbt_internal_test