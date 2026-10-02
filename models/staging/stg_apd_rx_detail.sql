{{ config(materialized='table') }}

-- NY All-Payer Database prescription drug detail PUFs, 2018-2023.
-- Grain: one row per year x payer_type x 9-digit NDC (labeler + product; package code dropped by the state).
-- 2018 column names carry a double space ("Median Member Paid  Amount"); later years drop the "of".

with raw as (

    select *
    from read_csv_auto(
        '{{ var("raw_dir") }}/apd/apd_rx_detail_*.csv',
        header = true, union_by_name = true, all_varchar = true, filename = true
    )

)

select
    cast("Year" as integer) || '|' || upper(trim("Payer Type")) || '|' || coalesce("NDC 9 digits", 'VARIOUS') as row_key,
    cast("Year" as integer)                                       as year,
    "File Type"                                                   as file_type,
    upper(trim("Payer Type"))                                     as payer_type,
    -- the one suppressed row per payer-year ("VARIOUS WITH UNIQUE MBRS UNDER 11") has no NDC
    coalesce("NDC 9 digits", 'VARIOUS')                           as ndc9,
    substr("NDC 9 digits", 1, 5)                                  as labeler_code,
    "NDC 9 digits" is null                                        as is_suppressed_bucket,
    upper(trim("Nonproprietary Drug Name"))                       as nonproprietary_name,
    upper(trim("Proprietary Drug Name"))                          as proprietary_name,
    coalesce(upper(trim("Drug Category")), 'SUPPRESSED')          as drug_category,
    upper(trim("Therapeutic Class"))                              as therapeutic_class,
    coalesce(upper(trim("Labeler Name")), 'VARIOUS (SUPPRESSED)') as labeler_name,
    "Dosage Form"                                                 as dosage_form,
    "Active Strength"                                             as active_strength,
    "Active Strength Unit"                                        as active_strength_unit,
    cast("Number of Prescriptions Filled" as bigint)              as rx_count,
    cast("Unique Members" as bigint)                              as unique_members,
    cast("Median Days Supply" as double)                          as days_supply_median,
    cast("Mean Days Supply" as double)                            as days_supply_mean,
    cast("Standard Deviation Days Supply" as double)              as days_supply_sd,
    cast("Median Quantity Dispensed" as double)                   as quantity_median,
    cast("Mean Quantity Dispensed" as double)                     as quantity_mean,
    cast("Standard Deviation Quantity Dispensed" as double)       as quantity_sd,
    -- non-zero-claim statistics; see stg_apd_rx_summary for why these are never used for cost sharing
    cast("Median Insurer Paid Amount" as double)                  as insurer_paid_median_nonzero,
    cast("Mean Insurer Paid Amount" as double)                    as insurer_paid_mean_nonzero,
    cast(coalesce("Standard Deviation of Insurer Paid Amount",
                  "Standard Deviation Insurer Paid Amount") as double) as insurer_paid_sd_nonzero,
    cast(coalesce("Median Member Paid Amount",
                  "Median Member Paid  Amount") as double)           as member_paid_median_nonzero,
    cast(coalesce("Mean Member Paid Amount",
                  "Mean Member Paid  Amount") as double)             as member_paid_mean_nonzero,
    cast(coalesce("Standard Deviation of Member Paid Amount",
                  "Standard Deviation Member Paid Amount") as double) as member_paid_sd_nonzero,
    cast("Median Total Paid Amount" as double)                    as total_paid_median_nonzero,
    cast("Mean Total Paid Amount" as double)                      as total_paid_mean_nonzero,
    cast(coalesce("Standard Deviation of Total Paid Amount",
                  "Standard Deviation Total Paid Amount") as double)  as total_paid_sd_nonzero,
    cast("Sum Insurer Paid Amount" as double)                     as insurer_paid_sum,
    cast("Sum Member Paid Amount" as double)                      as member_paid_sum,
    cast("Sum Total Paid Amount" as double)                       as total_paid_sum,
    regexp_extract(filename, '([^/]+)$', 1)                       as source_file
from raw
