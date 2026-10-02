{{ config(materialized='table') }}

-- CMS Medicare Part D Prescribers by Provider, New York rows, 2018-2024 (pulled by scripts/fetch_cms_prescribers.py).
-- Grain: year x NPI. Counts under 11 are suppressed by CMS (null here). LIS / non-LIS, MAPD / PDP and brand /
-- generic claim splits are for the prescriber's whole Part D volume, not any one drug.

with raw as (

    select *
    from read_csv_auto(
        '{{ var("raw_dir") }}/cms/partd_prescriber/by_provider_ny_*.csv',
        header = true, union_by_name = true, all_varchar = true, filename = true
    )

),

typed as (

    select
        cast(regexp_extract(filename, '(\d{4})\.csv$', 1) as integer) as year,
        Prscrbr_NPI                                 as npi,
        Prscrbr_Last_Org_Name                       as last_or_org_name,
        Prscrbr_First_Name                          as first_name,
        Prscrbr_Crdntls                             as credentials,
        Prscrbr_Ent_Cd                              as entity_code,
        Prscrbr_City                                as city,
        Prscrbr_State_Abrvtn                        as state,
        Prscrbr_Zip5                                as zip5,
        Prscrbr_RUCA                                as ruca,
        Prscrbr_RUCA_Desc                           as ruca_desc,
        Prscrbr_Type                                as prescriber_type,
        Prscrbr_Type_Src                            as prescriber_type_source,
        try_cast(Tot_Clms as bigint)                as tot_clms,
        try_cast(Tot_30day_Fills as double)         as tot_30day_fills,
        try_cast(Tot_Drug_Cst as double)            as tot_drug_cost,
        try_cast(Tot_Day_Suply as bigint)           as tot_day_supply,
        try_cast(Tot_Benes as bigint)               as tot_benes,
        try_cast(GE65_Tot_Clms as bigint)           as ge65_tot_clms,
        try_cast(GE65_Tot_Benes as bigint)          as ge65_tot_benes,
        try_cast(Brnd_Tot_Clms as bigint)           as brand_tot_clms,
        try_cast(Gnrc_Tot_Clms as bigint)           as generic_tot_clms,
        try_cast(Othr_Tot_Clms as bigint)           as other_tot_clms,
        try_cast(MAPD_Tot_Clms as bigint)           as mapd_tot_clms,
        try_cast(PDP_Tot_Clms as bigint)            as pdp_tot_clms,
        try_cast(LIS_Tot_Clms as bigint)            as lis_tot_clms,
        try_cast(NonLIS_Tot_Clms as bigint)         as nonlis_tot_clms,
        try_cast(Bene_Avg_Age as double)            as bene_avg_age,
        try_cast(Bene_Age_LT_65_Cnt as bigint)      as bene_age_lt_65_cnt,
        try_cast(Bene_Age_65_74_Cnt as bigint)      as bene_age_65_74_cnt,
        try_cast(Bene_Age_75_84_Cnt as bigint)      as bene_age_75_84_cnt,
        try_cast(Bene_Age_GT_84_Cnt as bigint)      as bene_age_gt_84_cnt,
        try_cast(Bene_Feml_Cnt as bigint)           as bene_female_cnt,
        try_cast(Bene_Male_Cnt as bigint)           as bene_male_cnt,
        try_cast(Bene_Race_Wht_Cnt as bigint)       as bene_race_white_cnt,
        try_cast(Bene_Race_Black_Cnt as bigint)     as bene_race_black_cnt,
        try_cast(Bene_Race_Api_Cnt as bigint)       as bene_race_api_cnt,
        try_cast(Bene_Race_Hspnc_Cnt as bigint)     as bene_race_hispanic_cnt,
        try_cast(Bene_Dual_Cnt as bigint)           as bene_dual_cnt,
        try_cast(Bene_Ndual_Cnt as bigint)          as bene_nondual_cnt,
        try_cast(Bene_Avg_Risk_Scre as double)      as bene_avg_risk_score
    from raw

)

select
    year || '|' || npi                                                   as row_key,
    *,
    {{ specialty_bucket('prescriber_type') }}                            as specialty_bucket,
    {{ is_nyc_zip('zip5') }}                                             as is_nyc,
    nonlis_tot_clms / nullif(lis_tot_clms + nonlis_tot_clms, 0)          as nonlis_share_all_drugs,
    mapd_tot_clms / nullif(mapd_tot_clms + pdp_tot_clms, 0)              as mapd_share_all_drugs,
    bene_dual_cnt / nullif(bene_dual_cnt + bene_nondual_cnt, 0)          as dual_share_benes
from typed
