
    
    

select
    trade_date as unique_field,
    count(*) as n_records

from "macro_dw"."analytics"."silver_jisdor_rates"
where trade_date is not null
group by trade_date
having count(*) > 1


