-- Shingrix prescriber concentration: NY NPIs with a Shingrix row (>= 11 claims) ranked into deciles per year.
-- Decile 1 = highest-volume tenth. share_of_claims for decile 1 is the top-decile concentration.

with sh as (

    select year, npi, specialty_bucket, tot_clms
    from {{ ref('mart_vaccine_prescriber') }}
    where product = 'Shingrix'

),

ranked as (

    select *, ntile(10) over (partition by year order by tot_clms desc, npi) as decile
    from sh

)

select
    year || '|' || decile                                        as row_key,
    year,
    decile,
    case when year <= 2022 then 'pre' when year = 2023 then 'post 2023' else 'post 2024' end as period,
    count(*)                                                     as npis,
    sum(tot_clms)                                                as claims,
    sum(tot_clms) / sum(sum(tot_clms)) over (partition by year)  as share_of_claims,
    min(tot_clms)                                                as min_clms,
    max(tot_clms)                                                as max_clms,
    sum(case when specialty_bucket = 'Pharmacist / pharmacy' then 1 else 0 end) / count(*) as pharmacist_share_of_npis
from ranked
group by 1, 2, 3, 4
