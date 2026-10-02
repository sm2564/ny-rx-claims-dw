select 'tdap_brand_share' as mart, row_key, brand_share_of_fills as share
from {{ ref('mart_study_tdap_brand_share') }} where brand_share_of_fills < 0 or brand_share_of_fills > 1
union all
select 'uptake_of_remaining_pool', row_key, shingrix_uptake_of_remaining_pool
from {{ ref('mart_study_partd_vs_partb_comparison') }} where shingrix_uptake_of_remaining_pool < 0 or shingrix_uptake_of_remaining_pool > 1
