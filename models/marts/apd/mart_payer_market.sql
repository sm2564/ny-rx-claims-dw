-- Market size per year x payer segment: prescriptions, spend, and the member-paid share.
-- unique_members is per ingredient row and is not additive across drugs; member_ingredient_pairs keeps the
-- sum for scale only. Cost-sharing shares come from the *_paid_sum columns, never from per-claim means.

select
    s.year,
    s.payer_type,
    p.payer_name,
    p.is_ira_treated,
    count(*)                                                     as ingredient_rows,
    sum(s.rx_count)                                              as rx_count,
    sum(s.unique_members)                                        as member_ingredient_pairs,
    sum(s.total_paid_sum)                                        as total_paid,
    sum(s.insurer_paid_sum)                                      as insurer_paid,
    sum(s.member_paid_sum)                                       as member_paid,
    sum(s.member_paid_sum) / nullif(sum(s.total_paid_sum), 0)    as member_paid_share,
    sum(s.total_paid_sum) / nullif(sum(s.rx_count), 0)           as paid_per_rx,
    sum(s.member_paid_sum) / nullif(sum(s.rx_count), 0)          as member_paid_per_rx,
    sum(s.rx_count) / sum(sum(s.rx_count)) over (partition by s.year)         as rx_share_of_year,
    sum(s.total_paid_sum) / sum(sum(s.total_paid_sum)) over (partition by s.year) as spend_share_of_year
from {{ ref('stg_apd_rx_summary') }} s
join {{ ref('dim_payer') }} p using (payer_type)
group by 1, 2, 3, 4
