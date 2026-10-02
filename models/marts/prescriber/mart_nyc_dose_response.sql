-- NYC prescriber panel for the dose-response design: NPIs in the five boroughs with at least one Shingrix row
-- 2018-2024 and a 2022 practice profile. Treatment intensity = 2022 non-LIS share of all Part D claims
-- (LIS members already paid ~$0, so the $0 policy bit hardest where non-LIS share was high).
-- Outcome = Shingrix claims per NPI-year; years without a row are suppressed (< 11 claims) and are given as
-- null plus a zero-imputed copy. The regression (prescriber + year fixed effects) runs in analysis/readout.py.

with nyc_npis as (

    select distinct npi
    from {{ ref('mart_vaccine_prescriber') }}
    where product = 'Shingrix' and is_nyc

),

intensity as (

    select
        p.npi,
        p.nonlis_share_all_drugs    as nonlis_share_2022,
        p.mapd_share_all_drugs      as mapd_share_2022,
        p.dual_share_benes          as dual_share_2022,
        p.tot_clms                  as all_drug_clms_2022,
        p.specialty_bucket,
        p.prescriber_type,
        p.zip5,
        p.ruca
    from {{ ref('stg_cms_partd_prescriber') }} p
    join nyc_npis using (npi)
    where p.year = 2022 and p.nonlis_share_all_drugs is not null

),

years as (

    select unnest(generate_series(2018, 2024)) as year

),

sh as (

    select year, npi, tot_clms, tot_benes
    from {{ ref('mart_vaccine_prescriber') }}
    where product = 'Shingrix'

)

select
    i.npi || '|' || y.year                                   as row_key,
    i.npi,
    y.year,
    y.year >= 2023                                           as post,
    i.nonlis_share_2022,
    i.nonlis_share_2022 >= 0.5                               as high_nonlis,
    ntile(4) over (order by i.nonlis_share_2022, i.npi)      as nonlis_quartile_2022,
    i.mapd_share_2022,
    i.dual_share_2022,
    i.all_drug_clms_2022,
    i.specialty_bucket,
    i.prescriber_type,
    i.zip5,
    i.ruca,
    s.tot_clms                                               as shingrix_clms,
    coalesce(s.tot_clms, 0)                                  as shingrix_clms_imputed0,
    s.tot_clms is not null                                   as has_shingrix_row,
    p.npi is not null                                        as in_provider_file_that_year
from intensity i
cross join years y
left join sh s on s.npi = i.npi and s.year = y.year
left join {{ ref('stg_cms_partd_prescriber') }} p on p.npi = i.npi and p.year = y.year
