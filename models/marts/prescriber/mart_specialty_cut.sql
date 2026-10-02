-- Who writes the vaccine claim: pharmacist vs physician vs NP/PA, per year x vaccine group (NY, CMS Part D).

with base as (

    select
        year,
        vaccine_group,
        specialty_bucket,
        count(distinct npi)   as npis,
        sum(tot_clms)         as claims,
        sum(tot_benes)        as benes_reported
    from {{ ref('mart_vaccine_prescriber') }}
    group by 1, 2, 3

)

select
    year || '|' || vaccine_group || '|' || specialty_bucket             as row_key,
    *,
    claims / sum(claims) over (partition by year, vaccine_group)        as share_of_group_claims,
    npis   / sum(npis)   over (partition by year, vaccine_group)        as share_of_group_npis,
    claims / lag(claims) over (partition by vaccine_group, specialty_bucket order by year) - 1 as claims_yoy_pct
from base
