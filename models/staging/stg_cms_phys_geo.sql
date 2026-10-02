{{ config(materialized='table') }}

-- CMS Medicare Physician & Other Practitioners by Geography and Service, 2018-2024 (national + state rows).
-- Part B fee-for-service claims only (Medicare Advantage encounters are not in these files).
-- Grain: year x geography x HCPCS x place of service (F = facility, O = office). Rows with a blank geography
-- (unknown / foreign) are keyed 'XX'.

with raw as (

    select *
    from read_csv_auto(
        '{{ var("raw_dir") }}/cms/phys_geo/phys_geo_*.csv',
        header = true, union_by_name = true, all_varchar = true, filename = true
    )

)

select
    cast(regexp_extract(filename, '(\d{4})\.csv$', 1) as integer)
        || '|' || case when Rndrng_Prvdr_Geo_Lvl = 'National' then 'US' else coalesce(nullif(Rndrng_Prvdr_Geo_Cd, ''), 'XX') end || '|' || HCPCS_Cd || '|' || Place_Of_Srvc as row_key,
    cast(regexp_extract(filename, '(\d{4})\.csv$', 1) as integer) as year,
    Rndrng_Prvdr_Geo_Lvl                            as geo_level,
    case when Rndrng_Prvdr_Geo_Lvl = 'National' then 'US' else coalesce(nullif(Rndrng_Prvdr_Geo_Cd, ''), 'XX') end as geo_code,
    Rndrng_Prvdr_Geo_Desc                           as geo_desc,
    HCPCS_Cd                                        as hcpcs_cd,
    HCPCS_Desc                                      as hcpcs_desc,
    HCPCS_Drug_Ind = 'Y'                            as is_drug_hcpcs,
    Place_Of_Srvc                                   as place_of_service,
    try_cast(Tot_Rndrng_Prvdrs as integer)          as tot_providers,
    try_cast(Tot_Benes as bigint)                   as tot_benes,
    try_cast(Tot_Srvcs as double)                   as tot_services,
    try_cast(Tot_Bene_Day_Srvcs as double)          as tot_bene_day_services,
    try_cast(Avg_Sbmtd_Chrg as double)              as avg_submitted_charge,
    try_cast(Avg_Mdcr_Alowd_Amt as double)          as avg_medicare_allowed,
    try_cast(Avg_Mdcr_Pymt_Amt as double)           as avg_medicare_payment,
    try_cast(Avg_Mdcr_Stdzd_Amt as double)          as avg_medicare_standardized
from raw
