{{ config(materialized='table') }}

-- NY All-Payer Database prescription drug summary PUFs, 2018-2023.
-- Grain: one row per year x payer_type x nonproprietary drug name (active ingredient).
-- Raw CSVs are read directly from {{ var('raw_dir') }}/apd/ (CI points raw_dir at data/sample/).
-- Column-name drift across years ("Standard Deviation of X" vs "Standard Deviation X") is coalesced here.

with raw as (

    select *
    from read_csv_auto(
        '{{ var("raw_dir") }}/apd/apd_rx_summary_*.csv',
        header = true, union_by_name = true, all_varchar = true, filename = true
    )

),

typed as (

    select
        cast("Year" as integer)                                       as year,
        "File Type"                                                   as file_type,
        upper(trim("Payer Type"))                                     as payer_type,
        upper(trim("Nonproprietary Drug Name"))                       as nonproprietary_name,
        upper(trim("Therapeutic Class"))                              as therapeutic_class,
        cast("Total Prescriptions Rank" as integer)                   as total_rx_rank,
        cast("Payer Prescriptions Rank" as integer)                   as payer_rx_rank,
        cast("Number of Prescriptions Filled" as bigint)              as rx_count,
        cast("Unique Members" as bigint)                              as unique_members,
        cast("Median Days Supply" as double)                          as days_supply_median,
        cast("Mean Days Supply" as double)                            as days_supply_mean,
        cast("Standard Deviation Days Supply" as double)              as days_supply_sd,
        cast("Median Quantity Dispensed" as double)                   as quantity_median,
        cast("Mean Quantity Dispensed" as double)                     as quantity_mean,
        cast("Standard Deviation Quantity Dispensed" as double)       as quantity_sd,
        -- Per-claim paid statistics are computed by the state over NON-ZERO claims only.
        -- They exclude $0 fills and therefore RISE after a $0 cost-sharing policy. Never derive
        -- out-of-pocket shares from them; use the *_paid_sum columns.
        cast("Median Insurer Paid Amount" as double)                  as insurer_paid_median_nonzero,
        cast("Mean Insurer Paid Amount" as double)                    as insurer_paid_mean_nonzero,
        cast("Standard Deviation Insurer Paid Amount" as double)      as insurer_paid_sd_nonzero,
        cast("Median Member Paid Amount" as double)                   as member_paid_median_nonzero,
        cast("Mean Member Paid Amount" as double)                     as member_paid_mean_nonzero,
        cast(coalesce("Standard Deviation of Member Paid Amount",
                      "Standard Deviation Member Paid Amount") as double) as member_paid_sd_nonzero,
        cast("Median Total Paid Amount" as double)                    as total_paid_median_nonzero,
        cast("Mean Total Paid Amount" as double)                      as total_paid_mean_nonzero,
        cast(coalesce("Standard Deviation of Total Paid Amount",
                      "Standard Deviation Total Paid Amount") as double)  as total_paid_sd_nonzero,
        cast("Sum Insurer Paid Amount" as double)                     as insurer_paid_sum,
        cast("Sum Member Paid Amount" as double)                      as member_paid_sum,
        cast("Sum Total Paid Amount" as double)                       as total_paid_sum,
        cast("Percentage Aged Under 19 Years" as double)              as pct_age_under_19_raw,
        cast("Percentage Aged 19 to 44 Years" as double)              as pct_age_19_44_raw,
        cast("Percentage Aged 45 to 64 Years" as double)              as pct_age_45_64_raw,
        cast("Percentage Aged 65 Plus Years" as double)               as pct_age_65_plus_raw,
        cast("Percentage Female" as double)                           as pct_female_raw,
        cast("Percentage Male" as double)                             as pct_male_raw,
        regexp_extract(filename, '([^/]+)$', 1)                       as source_file
    from raw

),

scaled as (

    -- The 2023 file publishes the percentage columns at 1/100 of the 2018-2022 scale
    -- (0.0092 where earlier years show 0.912). Normalize so every year is a share in [0, 1].
    -- 59 rows in 2018-2020 repeat an ingredient x class key verbatim in the state's file (two rows with
    -- different counts and ranks); they are kept as separate rows and distinguished by source_row_seq.
    select
        *,
        case when year = 2023 then 100.0 else 1.0 end as pct_scale,
        row_number() over (
            partition by year, payer_type, nonproprietary_name, therapeutic_class
            order by rx_count desc
        ) as source_row_seq
    from typed

)

select
    year || '|' || payer_type || '|' || nonproprietary_name || '|' || therapeutic_class || '|' || source_row_seq as row_key,
    * exclude (pct_age_under_19_raw, pct_age_19_44_raw, pct_age_45_64_raw, pct_age_65_plus_raw,
               pct_female_raw, pct_male_raw),
    pct_age_under_19_raw * pct_scale as pct_age_under_19,
    pct_age_19_44_raw    * pct_scale as pct_age_19_44,
    pct_age_45_64_raw    * pct_scale as pct_age_45_64,
    pct_age_65_plus_raw  * pct_scale as pct_age_65_plus,
    pct_female_raw       * pct_scale as pct_female,
    pct_male_raw         * pct_scale as pct_male
from scaled
