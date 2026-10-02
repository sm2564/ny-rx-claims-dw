-- Vaccine brands (products) per year x payer from the NDC-9 detail file.
-- members is summed over the product's NDC-9s; a member who filled two NDC-9s of one product counts twice.

with base as (

    select
        d.year,
        d.payer_type,
        v.product,
        v.vaccine_group,
        v.manufacturer,
        v.part                   as medicare_benefit_part,
        v.schedule,
        v.ira_zero_cost_from,
        count(distinct d.ndc9)   as ndc9_count,
        sum(d.rx_count)          as fills,
        sum(d.unique_members)    as members,
        sum(d.member_paid_sum)   as member_paid_sum,
        sum(d.insurer_paid_sum)  as insurer_paid_sum,
        sum(d.total_paid_sum)    as total_paid_sum
    from {{ ref('stg_apd_rx_detail') }} d
    join {{ ref('int_vaccine_ndc9_map') }} v using (ndc9)
    group by all

)

select
    year || '|' || payer_type || '|' || product as row_key,
    *,
    member_paid_sum / nullif(total_paid_sum, 0)                               as oop_share,
    member_paid_sum / nullif(fills, 0)                                        as oop_per_fill,
    total_paid_sum / nullif(fills, 0)                                         as paid_per_fill,
    fills / sum(fills) over (partition by year, payer_type, vaccine_group)    as share_of_group_fills
from base
