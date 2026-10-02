-- Coverage of the NY prescriber-level vaccine rows against the NY state total in the geography file,
-- per brand x year. The gap is CMS suppression of prescriber x drug rows under 11 claims.

with pr as (

    select year, brand_name, sum(tot_clms) as prescriber_clms, count(*) as npis
    from {{ ref('stg_cms_partd_prescriber_drug') }}
    group by 1, 2

),

geo as (

    select g.year, g.brand_name, s.product, g.tot_clms as geo_clms, g.tot_prescribers as geo_prescribers
    from {{ ref('stg_cms_partd_geo') }} g
    join {{ ref('vaccine_products') }} s on g.brand_name = s.cms_partd_brand_name
    where g.geo_desc = 'New York'

)

select
    g.year || '|' || g.product                     as row_key,
    g.year,
    g.product,
    g.brand_name,
    g.geo_clms,
    coalesce(p.prescriber_clms, 0)                 as prescriber_clms,
    coalesce(p.prescriber_clms, 0) / g.geo_clms    as claims_coverage_ratio,
    g.geo_prescribers,
    coalesce(p.npis, 0)                            as npis_with_rows,
    coalesce(p.npis, 0) / g.geo_prescribers        as prescriber_coverage_ratio
from geo g
left join pr p using (year, brand_name)
