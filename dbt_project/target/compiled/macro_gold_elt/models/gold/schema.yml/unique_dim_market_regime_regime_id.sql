
    
    

select
    regime_id as unique_field,
    count(*) as n_records

from "macro_dw"."analytics"."dim_market_regime"
where regime_id is not null
group by regime_id
having count(*) > 1


