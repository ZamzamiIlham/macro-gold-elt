
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select regime_id
from "macro_dw"."analytics"."mart_gold_macro_analytics"
where regime_id is null



  
  
      
    ) dbt_internal_test