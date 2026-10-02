-- Design 4: Boostrix vs Adacel share within Tdap, per year, from two sources:
-- CMS Part D (NY and US, 2018-2024) and the NY APD detail file by payer (2018-2023).

with cms as (

    select
        'CMS Part D'                 as source,
        geo                          as segment,
        year,
        product,
        claims                       as fills,
        benes                        as members
    from {{ ref('mart_study_cross_vaccine_reversal') }}
    where vaccine_group = 'tdap'

),

apd as (

    select
        'NY APD'                     as source,
        payer_type                   as segment,
        year,
        product,
        fills,
        members
    from {{ ref('mart_vaccine_brand_by_payer_year') }}
    where vaccine_group = 'tdap'

),

u as (

    select * from cms
    union all
    select * from apd

)

select
    source || '|' || segment || '|' || year || '|' || product         as row_key,
    *,
    fills / sum(fills) over (partition by source, segment, year)     as brand_share_of_fills,
    fills / lag(fills) over (partition by source, segment, product order by year) - 1 as fills_yoy_pct
from u
