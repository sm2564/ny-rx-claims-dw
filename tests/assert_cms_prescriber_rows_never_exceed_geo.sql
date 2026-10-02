-- suppression removes rows; the prescriber-level sum can never exceed the state total (0.1% tolerance)
select *
from {{ ref('mart_recon_cms_prescriber_vs_geo') }}
where prescriber_clms > geo_clms * 1.001
