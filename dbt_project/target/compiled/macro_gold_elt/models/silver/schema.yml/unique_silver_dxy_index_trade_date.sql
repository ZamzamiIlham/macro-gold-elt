
    
    

select
    trade_date as unique_field,
    count(*) as n_records

from "macro_dw"."analytics"."silver_dxy_index"
where trade_date is not null
group by trade_date
having count(*) > 1


