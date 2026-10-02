-- One row per 9-digit NDC seen in any APD detail file, with the most recent year's attributes.
-- Labeler can change across years for the same NDC-9 (Vivotif: Bavarian Nordic -> PaxVax); the latest wins.

with ranked as (

    select
        d.*,
        min(year)      over (partition by ndc9) as first_year,
        max(year)      over (partition by ndc9) as last_year,
        sum(rx_count)  over (partition by ndc9) as total_rx_all_years,
        row_number()   over (partition by ndc9 order by year desc, rx_count desc) as rn
    from {{ ref('stg_apd_rx_detail') }} d

)

select
    r.ndc9,
    r.labeler_code,
    r.labeler_name,
    r.proprietary_name,
    r.nonproprietary_name,
    r.drug_category,
    r.therapeutic_class,
    r.dosage_form,
    r.active_strength,
    r.active_strength_unit,
    r.first_year,
    r.last_year,
    r.total_rx_all_years,
    v.product        as vaccine_product,
    v.vaccine_group,
    v.vaccine_group is not null as is_vaccine
from ranked r
left join {{ ref('int_vaccine_ndc9_map') }} v using (ndc9)
where r.rn = 1
