-- Labelers ranked by commercial spend per year (NDC-9 detail file, COMMERCIAL segment only).
-- All labelers are kept with their rank; readouts filter to the top N.

with base as (

    select
        year,
        labeler_name,
        count(distinct ndc9)                                                 as ndc9_count,
        count(distinct nonproprietary_name)                                  as ingredient_count,
        sum(rx_count)                                                        as rx_count,
        sum(total_paid_sum)                                                  as total_paid,
        sum(member_paid_sum)                                                 as member_paid,
        sum(case when drug_category = 'BRAND' then total_paid_sum else 0 end) as brand_paid,
        sum(case when drug_category = 'BRAND' then rx_count else 0 end)       as brand_rx
    from {{ ref('stg_apd_rx_detail') }}
    where payer_type = 'COMMERCIAL'
    group by 1, 2

)

select
    year || '|' || labeler_name as row_key,
    *,
    rank() over (partition by year order by total_paid desc)           as spend_rank,
    rank() over (partition by year order by rx_count desc)             as rx_rank,
    total_paid / sum(total_paid) over (partition by year)              as spend_share,
    rx_count   / sum(rx_count)   over (partition by year)              as rx_share,
    brand_paid / nullif(total_paid, 0)                                 as brand_share_of_spend,
    member_paid / nullif(total_paid, 0)                                as member_paid_share
from base
