select year, sum(share_of_claims) as total_share
from {{ ref('mart_prescriber_deciles') }}
group by 1
having abs(sum(share_of_claims) - 1) > 0.001
