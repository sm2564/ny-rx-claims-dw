{{ config(materialized='table') }}

-- CMS Medicare Part D Prescribers by Geography and Drug, 2018-2024 (national + state rows).
-- Grain: year x geography x brand x generic name. A few rows per year carry a blank geography code and
-- description (unknown / foreign prescriber location); they are keyed 'XX' and excluded by geo_desc filters. Dollar cost-share columns are totals, not per claim.
-- The 2024 file (catalog title "2024-12-01") was verified full-year: flat-demand generics grew 0.5-9%
-- in 2024, in line with 2023, and the catalog's temporal coverage reads 2024-01-01 to 2024-12-31.

with raw as (

    select *
    from read_csv_auto(
        '{{ var("raw_dir") }}/cms/partd_geo/partd_geo_*.csv',
        header = true, union_by_name = true, all_varchar = true, filename = true
    )

)

select
    cast(regexp_extract(filename, '(\d{4})\.csv$', 1) as integer)
        || '|' || case when Prscrbr_Geo_Lvl = 'National' then 'US' else coalesce(nullif(Prscrbr_Geo_Cd, ''), 'XX') end || '|' || Brnd_Name || '|' || Gnrc_Name as row_key,
    cast(regexp_extract(filename, '(\d{4})\.csv$', 1) as integer) as year,
    Prscrbr_Geo_Lvl                                 as geo_level,
    case when Prscrbr_Geo_Lvl = 'National' then 'US' else coalesce(nullif(Prscrbr_Geo_Cd, ''), 'XX') end      as geo_code,
    Prscrbr_Geo_Desc                                as geo_desc,
    Brnd_Name                                       as brand_name,
    Gnrc_Name                                       as generic_name,
    try_cast(Tot_Prscrbrs as integer)               as tot_prescribers,
    try_cast(Tot_Clms as bigint)                    as tot_clms,
    try_cast(Tot_30day_Fills as double)             as tot_30day_fills,
    try_cast(Tot_Drug_Cst as double)                as tot_drug_cost,
    try_cast(Tot_Benes as bigint)                   as tot_benes,
    GE65_Sprsn_Flag is not null                     as ge65_suppressed,
    try_cast(GE65_Tot_Clms as bigint)               as ge65_tot_clms,
    try_cast(GE65_Tot_Drug_Cst as double)           as ge65_tot_drug_cost,
    try_cast(GE65_Tot_Benes as bigint)              as ge65_tot_benes,
    try_cast(LIS_Bene_Cst_Shr as double)            as lis_bene_cost_share,
    try_cast(NonLIS_Bene_Cst_Shr as double)         as nonlis_bene_cost_share,
    Opioid_Drug_Flag = 'Y'                          as is_opioid,
    Antbtc_Drug_Flag = 'Y'                          as is_antibiotic,
    Antpsyct_Drug_Flag = 'Y'                        as is_antipsychotic
from raw
