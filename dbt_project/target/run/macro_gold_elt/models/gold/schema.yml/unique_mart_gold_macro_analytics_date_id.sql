
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    date_id as unique_field,
    count(*) as n_records

from "macro_dw"."analytics"."mart_gold_macro_analytics"
where date_id is not null
group by date_id
having count(*) > 1



  
  
      
    ) dbt_internal_test