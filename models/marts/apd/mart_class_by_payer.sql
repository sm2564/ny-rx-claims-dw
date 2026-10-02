-- Therapeutic class x payer x year: volume, spend, member-paid share, and each payer's share of the class.
-- payer_share_of_class_rx for payer_type = 'COMMERCIAL' is "the commercial share of the class".

with base as (

    select
        year,
        payer_type,
        therapeutic_class,
        count(*)                as ingredient_rows,
        sum(rx_count)           as rx_count,
        sum(total_paid_sum)     as total_paid,
        sum(insurer_paid_sum)   as insurer_paid,
        sum(member_paid_sum)    as member_paid
    from {{ ref('stg_apd_rx_summary') }}
    group by 1, 2, 3

)

select
    year || '|' || payer_type || '|' || therapeutic_class as row_key,
    *,
    member_paid / nullif(total_paid, 0)                                           as member_paid_share,
    total_paid / nullif(rx_count, 0)                                              as paid_per_rx,
    rx_count   / sum(rx_count)   over (partition by year, therapeutic_class)      as payer_share_of_class_rx,
    total_paid / sum(total_paid) over (partition by year, therapeutic_class)      as payer_share_of_class_spend,
    rx_count   / sum(rx_count)   over (partition by year, payer_type)             as class_share_of_payer_rx,
    total_paid / sum(total_paid) over (partition by year, payer_type)             as class_share_of_payer_spend
from base
