-- Reconciliation of the NDC-9 detail file to the ingredient summary file, per year x payer x ingredient.
-- Published so the misses are visible: the singular test assert_apd_detail_reconciles_to_summary reads it.

with detail as (

    select year, payer_type, nonproprietary_name,
           count(*) as ndc9_rows, sum(rx_count) as rx_detail, sum(total_paid_sum) as paid_detail
    from {{ ref('stg_apd_rx_detail') }}
    group by 1, 2, 3

),

summary as (

    select year, payer_type, nonproprietary_name,
           count(*) as class_rows, sum(rx_count) as rx_summary, sum(total_paid_sum) as paid_summary
    from {{ ref('stg_apd_rx_summary') }}
    group by 1, 2, 3

)

select
    s.year || '|' || s.payer_type || '|' || s.nonproprietary_name as row_key,
    s.year,
    s.payer_type,
    s.nonproprietary_name,
    s.class_rows,
    s.rx_summary,
    s.paid_summary,
    d.ndc9_rows,
    d.rx_detail,
    d.paid_detail,
    d.rx_detail - s.rx_summary                                     as rx_diff,
    (d.rx_detail - s.rx_summary) / nullif(s.rx_summary, 0)        as rx_diff_pct,
    case
        when d.rx_detail is null then 'no detail rows'
        when abs(d.rx_detail - s.rx_summary) <= 0.005 * s.rx_summary then 'reconciles'
        when d.rx_detail < s.rx_summary then 'detail low'
        else 'detail high'
    end                                                            as recon_status
from summary s
left join detail d using (year, payer_type, nonproprietary_name)
