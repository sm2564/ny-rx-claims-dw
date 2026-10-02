-- continuing + exited + entered changes must sum to the total year-over-year change in Shingrix claims
with totals as (
    select year, sum(tot_clms) as clms
    from {{ ref('mart_vaccine_prescriber') }} where product = 'Shingrix' group by 1
),
decomp as (
    select y0, y1, sum(change_in_clms) as decomposed_change
    from {{ ref('mart_prescriber_attrition') }} where specialty_bucket = 'ALL' group by 1, 2
)
select d.y0, d.y1, d.decomposed_change, t1.clms - t0.clms as actual_change
from decomp d
join totals t0 on t0.year = d.y0
join totals t1 on t1.year = d.y1
where d.decomposed_change <> t1.clms - t0.clms
