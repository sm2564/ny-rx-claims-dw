-- Design 2 (long): Medicare vaccine volumes per year x geo (NY, US) x vaccine group x benefit part.
-- Part D from the Prescribers-by-Geography file (PDP + MA-PD claims). Part B from the Physician & Other
-- Practitioners geography file (fee-for-service only; admin codes G0008 / G0009 are the cleanest shot counts).

with partd as (

    select
        g.year,
        case when g.geo_level = 'National' then 'US' else 'NY' end as geo,
        s.vaccine_group,
        'D'                        as part,
        sum(g.tot_clms)            as partd_claims,
        sum(g.tot_benes)           as partd_benes,
        sum(g.ge65_tot_benes)      as partd_benes_65_plus,
        sum(g.tot_drug_cost)       as partd_drug_cost,
        sum(g.nonlis_bene_cost_share) as partd_nonlis_cost_share_total
    from {{ ref('stg_cms_partd_geo') }} g
    join {{ ref('vaccine_products') }} s on g.brand_name = s.cms_partd_brand_name
    where g.geo_desc in ('National', 'New York')
    group by 1, 2, 3, 4

),

partb as (

    select
        p.year,
        case when p.geo_level = 'National' then 'US' else 'NY' end as geo,
        h.vaccine_group,
        'B' as part,
        sum(case when h.kind = 'admin'   then p.tot_services end) as partb_admin_services,
        sum(case when h.kind = 'admin'   then p.tot_benes end)    as partb_admin_benes,
        sum(case when h.kind = 'product' then p.tot_services end) as partb_product_services,
        sum(case when h.kind = 'product' then p.tot_benes end)    as partb_product_benes
    from {{ ref('stg_cms_phys_geo') }} p
    join {{ ref('vaccine_hcpcs') }} h using (hcpcs_cd)
    where p.geo_desc in ('National', 'New York')
    group by 1, 2, 3, 4

),

unioned as (

    select year, geo, vaccine_group, part,
           partd_claims, partd_benes, partd_benes_65_plus, partd_drug_cost, partd_nonlis_cost_share_total,
           null::double as partb_admin_services, null::bigint as partb_admin_benes,
           null::double as partb_product_services, null::bigint as partb_product_benes
    from partd
    union all
    select year, geo, vaccine_group, part,
           null, null, null, null, null,
           partb_admin_services, partb_admin_benes, partb_product_services, partb_product_benes
    from partb

)

select
    u.year || '|' || u.geo || '|' || u.vaccine_group || '|' || u.part as row_key,
    u.*,
    d.pop_65_plus,
    d.partd_enrollees,
    d.medicare_ffs_benes,
    d.medicare_benes_65_plus,
    u.partd_claims / d.partd_enrollees * 1000          as partd_claims_per_1000_enrollees,
    u.partd_benes  / d.partd_enrollees * 1000          as partd_benes_per_1000_enrollees,
    u.partb_admin_services / d.medicare_ffs_benes * 1000 as partb_admin_per_1000_ffs_benes,
    u.partd_claims / lag(u.partd_claims) over (partition by u.geo, u.vaccine_group, u.part order by u.year) - 1 as partd_claims_yoy_pct,
    u.partb_admin_services / lag(u.partb_admin_services) over (partition by u.geo, u.vaccine_group, u.part order by u.year) - 1 as partb_admin_yoy_pct
from unioned u
left join {{ ref('stg_ny_denominators') }} d using (geo, year)
