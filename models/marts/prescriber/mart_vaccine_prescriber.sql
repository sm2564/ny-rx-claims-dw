-- Per NPI x vaccine product x year for New York prescribers (CMS Part D), joined to the prescriber's
-- whole-practice Part D profile (ZIP, RUCA, LIS / non-LIS mix, MAPD / PDP mix, dual share).
-- Pharmacy-administered vaccines carry the pharmacist's or pharmacy's NPI; ZIP is the practice location.

select
    d.year || '|' || d.npi || '|' || s.product   as row_key,
    d.year,
    d.npi,
    s.product,
    s.vaccine_group,
    s.schedule,
    d.last_or_org_name,
    d.first_name,
    d.city,
    p.zip5,
    p.ruca,
    p.ruca_desc,
    p.is_nyc,
    d.prescriber_type,
    d.prescriber_type_source,
    d.specialty_bucket,
    d.tot_clms,
    d.tot_benes,
    d.tot_drug_cost,
    d.ge65_tot_clms,
    d.ge65_tot_benes,
    p.tot_clms                 as all_drug_clms,
    p.tot_benes                as all_drug_benes,
    p.nonlis_share_all_drugs,
    p.mapd_share_all_drugs,
    p.dual_share_benes,
    p.bene_avg_age,
    d.tot_clms / nullif(p.tot_clms, 0) as product_share_of_prescriber_clms
from {{ ref('stg_cms_partd_prescriber_drug') }} d
join {{ ref('vaccine_products') }} s on d.brand_name = s.cms_partd_brand_name
left join {{ ref('stg_cms_partd_prescriber') }} p on p.year = d.year and p.npi = d.npi
