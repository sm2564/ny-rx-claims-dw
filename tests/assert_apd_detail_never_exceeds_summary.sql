-- suppression can only move Rx out of an ingredient row, never into it: detail must not exceed summary by > 0.5%
select *
from {{ ref('mart_recon_apd_detail_vs_summary') }}
where recon_status = 'detail high'
  and nonproprietary_name not like 'VARIOUS%'
