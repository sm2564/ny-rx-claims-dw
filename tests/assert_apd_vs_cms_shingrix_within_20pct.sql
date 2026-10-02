-- NY APD Medicare Shingrix members must agree with CMS NY Shingrix beneficiaries within 20% every year
select year, apd_medicare_members, cms_ny_benes, members_ratio_apd_over_cms
from {{ ref('mart_recon_apd_vs_cms_shingrix') }}
where members_ratio_apd_over_cms < 0.8 or members_ratio_apd_over_cms > 1.2
