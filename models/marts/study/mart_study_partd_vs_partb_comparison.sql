-- Design 2 (wide): Shingrix (Part D, $0 from 2023) against the always-free Part B comparators,
-- per year x geo. Flu = fatigue meter (annual, no depletion); pneumococcal = depletion comparator.
-- Remaining-pool uptake: pool_t = Census 65+ population minus cumulative Shingrix beneficiaries 2018..t-1
-- (Shingrix launched 2017-10, so the 2018+ cumulative is nearly complete; a person with doses in two
-- calendar years is counted twice, so the pool is slightly understated). The pneumococcal pool ignores
-- pre-2018 vaccination and is overstated; read its level with care and its trend as-is.
-- Event study: ln(Shingrix rate / flu rate) relative to 2022.

with l as (

    select * from {{ ref('mart_study_partd_vs_partb') }}

),

w as (

    select
        year, geo,
        max(case when vaccine_group = 'shingles'     then partd_claims end)            as shingrix_claims,
        max(case when vaccine_group = 'shingles'     then partd_benes end)             as shingrix_benes,
        max(case when vaccine_group = 'rsv'          then partd_claims end)            as rsv_claims,
        max(case when vaccine_group = 'rsv'          then partd_benes end)             as rsv_benes,
        max(case when vaccine_group = 'tdap'         then partd_claims end)            as tdap_partd_claims,
        max(case when vaccine_group = 'influenza'    then partb_admin_services end)    as flu_admin_services,
        max(case when vaccine_group = 'influenza'    then partb_admin_benes end)       as flu_admin_benes,
        max(case when vaccine_group = 'influenza'    then partb_product_services end)  as flu_product_services,
        max(case when vaccine_group = 'pneumococcal' then partb_admin_services end)    as pneumo_admin_services,
        max(case when vaccine_group = 'pneumococcal' then partb_admin_benes end)       as pneumo_admin_benes,
        max(case when vaccine_group = 'pneumococcal' then partb_product_services end)  as pneumo_product_services,
        max(case when vaccine_group = 'covid'        then partb_admin_services end)    as covid_admin_services,
        max(case when vaccine_group = 'tdap_partb'   then partb_product_services end)  as tdap_partb_services,
        max(pop_65_plus)            as pop_65_plus,
        max(partd_enrollees)        as partd_enrollees,
        max(medicare_ffs_benes)     as medicare_ffs_benes,
        max(medicare_benes_65_plus) as medicare_benes_65_plus
    from l
    group by 1, 2

),

rates as (

    select
        *,
        shingrix_claims / partd_enrollees * 1000                                    as shingrix_claims_per_1000_partd,
        shingrix_benes  / partd_enrollees * 1000                                    as shingrix_benes_per_1000_partd,
        flu_admin_services / medicare_ffs_benes * 1000                              as flu_admin_per_1000_ffs,
        pneumo_admin_services / medicare_ffs_benes * 1000                           as pneumo_admin_per_1000_ffs,
        shingrix_claims / flu_admin_services                                        as shingrix_to_flu_claims_ratio,
        (shingrix_claims / partd_enrollees) / (flu_admin_services / medicare_ffs_benes) as shingrix_to_flu_rate_ratio,
        sum(shingrix_benes) over (partition by geo order by year rows between unbounded preceding and 1 preceding)      as shingrix_benes_cumulative_prior,
        sum(pneumo_admin_benes) over (partition by geo order by year rows between unbounded preceding and 1 preceding)  as pneumo_benes_cumulative_prior
    from w

),

pool as (

    select
        *,
        pop_65_plus - coalesce(shingrix_benes_cumulative_prior, 0)                  as shingrix_remaining_pool,
        shingrix_benes / (pop_65_plus - coalesce(shingrix_benes_cumulative_prior, 0)) as shingrix_uptake_of_remaining_pool,
        pop_65_plus - coalesce(pneumo_benes_cumulative_prior, 0)                    as pneumo_remaining_pool,
        pneumo_admin_benes / (pop_65_plus - coalesce(pneumo_benes_cumulative_prior, 0)) as pneumo_uptake_of_remaining_pool
    from rates

)

select
    year || '|' || geo as row_key,
    *,
    ln(shingrix_to_flu_rate_ratio)
        - max(case when year = 2022 then ln(shingrix_to_flu_rate_ratio) end) over (partition by geo) as event_study_log_ratio_vs_2022,
    exp(ln(shingrix_to_flu_rate_ratio)
        - max(case when year = 2022 then ln(shingrix_to_flu_rate_ratio) end) over (partition by geo)) - 1 as event_study_pct_vs_2022,
    shingrix_claims / lag(shingrix_claims) over (partition by geo order by year) - 1            as shingrix_claims_yoy_pct,
    flu_admin_services / lag(flu_admin_services) over (partition by geo order by year) - 1      as flu_admin_yoy_pct,
    pneumo_admin_services / lag(pneumo_admin_services) over (partition by geo order by year) - 1 as pneumo_admin_yoy_pct
from pool
