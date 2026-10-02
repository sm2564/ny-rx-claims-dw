-- every share column in the APD marts must be in [0, 1]
select 'mart_payer_market' as mart, year, payer_type, member_paid_share as share
from {{ ref('mart_payer_market') }} where member_paid_share < 0 or member_paid_share > 1
union all
select 'mart_class_by_payer', year, payer_type, member_paid_share
from {{ ref('mart_class_by_payer') }} where member_paid_share < 0 or member_paid_share > 1
   or payer_share_of_class_rx < 0 or payer_share_of_class_rx > 1
union all
select 'mart_brand_generic_by_payer', year, payer_type, rx_share
from {{ ref('mart_brand_generic_by_payer') }} where rx_share < 0 or rx_share > 1 or spend_share < 0 or spend_share > 1
union all
select 'mart_vaccine_by_payer_year', year, payer_type, oop_share
from {{ ref('mart_vaccine_by_payer_year') }} where oop_share < 0 or oop_share > 1
   or pct_age_45_64 < 0 or pct_age_45_64 > 1 or pct_age_65_plus < 0 or pct_age_65_plus > 1
union all
select 'mart_vaccine_brand_by_payer_year', year, payer_type, oop_share
from {{ ref('mart_vaccine_brand_by_payer_year') }} where oop_share < 0 or oop_share > 1
