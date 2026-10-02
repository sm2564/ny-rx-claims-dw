-- year x payer totals of the NDC-9 detail file must tie to the summary file within 0.5% (Rx and spend)
with d as (
    select year, payer_type, sum(rx_count) as rx_detail, sum(total_paid_sum) as paid_detail
    from {{ ref('stg_apd_rx_detail') }} group by 1, 2
),
s as (
    select year, payer_type, sum(rx_count) as rx_summary, sum(total_paid_sum) as paid_summary
    from {{ ref('stg_apd_rx_summary') }} group by 1, 2
)
select s.year, s.payer_type, rx_summary, rx_detail, paid_summary, paid_detail
from s join d using (year, payer_type)
where abs(rx_detail - rx_summary) > 0.005 * rx_summary
   or abs(paid_detail - paid_summary) > 0.005 * paid_summary
