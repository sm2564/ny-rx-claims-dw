-- Design 3: every Part D vaccine brand per year x geo (NY, US), 2018-2024, with year-over-year change.
-- All Part D vaccines went to $0 on the same day, so this is a heterogeneity table, not a DiD.
-- depletion_class separates once-per-lifetime vaccines that surged in 2023 from boosters and small-base series.

with b as (

    select
        g.year,
        case when g.geo_level = 'National' then 'US' else 'NY' end as geo,
        s.product,
        s.vaccine_group,
        s.schedule,
        s.ira_zero_cost_expected,
        sum(g.tot_clms)                 as claims,
        sum(g.tot_benes)                as benes,
        sum(g.tot_prescribers)          as prescriber_rows,
        sum(g.tot_drug_cost)            as drug_cost,
        sum(g.lis_bene_cost_share)      as lis_cost_share_total,
        sum(g.nonlis_bene_cost_share)   as nonlis_cost_share_total
    from {{ ref('stg_cms_partd_geo') }} g
    join {{ ref('vaccine_products') }} s on g.brand_name = s.cms_partd_brand_name
    where g.geo_desc in ('National', 'New York')
    group by 1, 2, 3, 4, 5, 6

),

l as (

    select
        *,
        lag(claims) over (partition by geo, product order by year) as prev_year_claims,
        case
            when vaccine_group in ('shingles', 'rsv') then 'once-per-lifetime, 2023 surge (depletable)'
            when vaccine_group in ('tdap', 'td')       then '10-year booster'
            when vaccine_group in ('hep_a', 'hep_b', 'hep_ab', 'hpv', 'mening_acwy', 'mening_b', 'mening_abcwy', 'varicella', 'mmr') then 'series, small base'
            else 'travel, small base'
        end as depletion_class
    from b

)

select
    year || '|' || geo || '|' || product                as row_key,
    *,
    claims / prev_year_claims - 1                       as claims_yoy_pct,
    drug_cost / nullif(claims, 0)                       as drug_cost_per_claim,
    nonlis_cost_share_total / nullif(claims, 0)         as nonlis_cost_share_per_claim,
    lis_cost_share_total / nullif(claims, 0)            as lis_cost_share_per_claim
from l
