
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    asset_id as unique_field,
    count(*) as n_records

from "macro_dw"."analytics"."fact_market_daily"
where asset_id is not null
group by asset_id
having count(*) > 1



  
  
      
    ) dbt_internal_test