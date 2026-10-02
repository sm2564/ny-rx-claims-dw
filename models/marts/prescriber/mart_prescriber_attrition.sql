-- Is the 2024 Shingrix drop demand or channel? Decompose the year-over-year change in NY Shingrix claims into
-- continuing NPIs (present both years), exits (present in year 0 only) and entrants (year 1 only), by specialty
-- bucket and in total. Suppression caveat: an NPI falling below 11 Shingrix claims "exits" while still
-- prescribing, so exits overstate true channel loss.

with sh as (

    select year, npi, specialty_bucket, tot_clms
    from {{ ref('mart_vaccine_prescriber') }}
    where product = 'Shingrix'

),

pairs as (

    select 2021 as y0, 2022 as y1
    union all select 2022, 2023
    union all select 2023, 2024

),

universe as (

    select p.y0, p.y1, s.npi
    from pairs p
    join sh s on s.year in (p.y0, p.y1)
    group by 1, 2, 3

),

j as (

    select
        u.y0, u.y1, u.npi,
        coalesce(a.specialty_bucket, b.specialty_bucket) as specialty_bucket,
        a.tot_clms as clms_y0,
        b.tot_clms as clms_y1,
        case when a.npi is not null and b.npi is not null then 'continuing'
             when a.npi is not null then 'exited'
             else 'entered' end as status
    from universe u
    left join sh a on a.year = u.y0 and a.npi = u.npi
    left join sh b on b.year = u.y1 and b.npi = u.npi

),

agg as (

    select
        y0, y1,
        coalesce(specialty_bucket, 'ALL') as specialty_bucket,
        status,
        count(*)                         as npis,
        sum(coalesce(clms_y0, 0))        as clms_y0,
        sum(coalesce(clms_y1, 0))        as clms_y1,
        sum(coalesce(clms_y1, 0)) - sum(coalesce(clms_y0, 0)) as change_in_clms
    from j
    group by grouping sets ((y0, y1, specialty_bucket, status), (y0, y1, status))

)

select
    y0 || '-' || y1 || '|' || specialty_bucket || '|' || status              as row_key,
    y0 || '-' || y1                                                           as year_pair,
    *,
    change_in_clms / sum(change_in_clms) over (partition by y0, y1, specialty_bucket) as share_of_total_change,
    change_in_clms / nullif(sum(clms_y0) over (partition by y0, y1, specialty_bucket), 0) as change_as_pct_of_y0_total
from agg
