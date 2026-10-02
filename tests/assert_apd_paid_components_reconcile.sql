-- insurer_paid_sum + member_paid_sum must equal total_paid_sum within $1 on every summary and detail row
select 'summary' as source, row_key, insurer_paid_sum, member_paid_sum, total_paid_sum
from {{ ref('stg_apd_rx_summary') }}
where abs(insurer_paid_sum + member_paid_sum - total_paid_sum) > 1
union all
select 'detail', row_key, insurer_paid_sum, member_paid_sum, total_paid_sum
from {{ ref('stg_apd_rx_detail') }}
where abs(insurer_paid_sum + member_paid_sum - total_paid_sum) > 1
