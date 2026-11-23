
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  





with validation_errors as (

    select
        date_id, asset_id
    from "macro_dw"."analytics"."fact_market_daily"
    group by date_id, asset_id
    having count(*) > 1

)

select *
from validation_errors



  
  
      
    ) dbt_internal_test