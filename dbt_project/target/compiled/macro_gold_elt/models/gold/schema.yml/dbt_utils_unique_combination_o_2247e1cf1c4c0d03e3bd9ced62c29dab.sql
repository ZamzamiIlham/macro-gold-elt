





with validation_errors as (

    select
        date_id, asset_id
    from "macro_dw"."analytics"."fact_market_daily"
    group by date_id, asset_id
    having count(*) > 1

)

select *
from validation_errors


