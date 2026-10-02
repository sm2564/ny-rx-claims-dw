{{ config(materialized='table') }}

-- CMS Medicare Part D Prescribers by Provider and Drug, New York rows for the Part D vaccine brands,
-- 2018-2024 (pulled by scripts/fetch_cms_prescribers.py). Grain: year x NPI x brand x generic.
-- Rows with fewer than 11 claims do not exist in the source; Tot_Benes under 11 is null.

with raw as (

    select *
    from read_csv_auto(
        '{{ var("raw_dir") }}/cms/partd_prescriber/by_provider_drug_ny_vaccines_*.csv',
        header = true, union_by_name = true, all_varchar = true, filename = true
    )

)

select
    cast(regexp_extract(filename, '(\d{4})\.csv$', 1) as integer) || '|' || Prscrbr_NPI || '|' || Brnd_Name || '|' || Gnrc_Name as row_key,
    cast(regexp_extract(filename, '(\d{4})\.csv$', 1) as integer) as year,
    Prscrbr_NPI                                 as npi,
    Prscrbr_Last_Org_Name                       as last_or_org_name,
    Prscrbr_First_Name                          as first_name,
    Prscrbr_City                                as city,
    Prscrbr_State_Abrvtn                        as state,
    Prscrbr_Type                                as prescriber_type,
    Prscrbr_Type_Src                            as prescriber_type_source,
    {{ specialty_bucket('Prscrbr_Type') }}      as specialty_bucket,
    Brnd_Name                                   as brand_name,
    Gnrc_Name                                   as generic_name,
    try_cast(Tot_Clms as bigint)                as tot_clms,
    try_cast(Tot_30day_Fills as double)         as tot_30day_fills,
    try_cast(Tot_Day_Suply as bigint)           as tot_day_supply,
    try_cast(Tot_Drug_Cst as double)            as tot_drug_cost,
    try_cast(Tot_Benes as bigint)               as tot_benes,
    GE65_Sprsn_Flag is not null                 as ge65_suppressed,
    try_cast(GE65_Tot_Clms as bigint)           as ge65_tot_clms,
    try_cast(GE65_Tot_Benes as bigint)          as ge65_tot_benes
from raw
