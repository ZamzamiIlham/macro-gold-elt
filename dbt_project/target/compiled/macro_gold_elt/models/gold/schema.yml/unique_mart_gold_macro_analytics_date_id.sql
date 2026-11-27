
    
    

select
    date_id as unique_field,
    count(*) as n_records

from "macro_dw"."analytics"."mart_gold_macro_analytics"
where date_id is not null
group by date_id
having count(*) > 1


