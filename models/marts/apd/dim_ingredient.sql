-- One row per active ingredient (nonproprietary drug name) in the APD summary files.

with ranked as (

    select
        nonproprietary_name,
        therapeutic_class,
        min(year)                                         as first_year,
        max(year)                                         as last_year,
        sum(rx_count)                                     as total_rx_all_years,
        count(distinct payer_type)                        as payer_count,
        row_number() over (partition by nonproprietary_name order by max(year) desc, sum(rx_count) desc) as rn
    from {{ ref('stg_apd_rx_summary') }}
    group by 1, 2

)

select
    r.nonproprietary_name,
    r.therapeutic_class,
    r.first_year,
    r.last_year,
    r.total_rx_all_years,
    r.payer_count,
    v.vaccine_group,
    v.part                       as medicare_benefit_part,
    v.products                   as vaccine_products,
    v.vaccine_group is not null  as is_vaccine
from ranked r
left join {{ ref('int_vaccine_ingredient_map') }} v using (nonproprietary_name)
where r.rn = 1
