{{ config(severity = 'warn') }}
-- prescriber rows should carry most NY Shingrix claims; warn if under 70% in any year
select *
from {{ ref('mart_recon_cms_prescriber_vs_geo') }}
where product = 'Shingrix' and claims_coverage_ratio < 0.7
