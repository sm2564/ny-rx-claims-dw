-- Brand vs generic mix per year x payer, from the NDC-9 detail file (drug_category: BRAND / GENERIC / NA).

with base as (

    select
        year,
        payer_type,
        drug_category,
        count(distinct ndc9)    as ndc9_count,
        sum(rx_count)           as rx_count,
        sum(total_paid_sum)     as total_paid,
        sum(insurer_paid_sum)   as insurer_paid,
        sum(member_paid_sum)    as member_paid
    from {{ ref('stg_apd_rx_detail') }}
    group by 1, 2, 3

)

select
    year || '|' || payer_type || '|' || drug_category as row_key,
    *,
    rx_count   / sum(rx_count)   over (partition by year, payer_type)  as rx_share,
    total_paid / sum(total_paid) over (partition by year, payer_type)  as spend_share,
    member_paid / nullif(total_paid, 0)                                as member_paid_share,
    total_paid / nullif(rx_count, 0)                                   as paid_per_rx,
    member_paid / nullif(rx_count, 0)                                  as member_paid_per_rx
from base
