-- Two independent sources for the same thing: NY APD MEDICARE Shingrix members (insurer-submitted claims
-- aggregated by the state) vs CMS Part D NY Shingrix beneficiaries (CMS claims by prescriber state).
-- Differences: APD is by member residence/plan, CMS is by prescriber location; APD MEDICARE includes all
-- Medicare drug plans covering NY residents. Agreement within 20% is the acceptance band.

select
    a.year,
    a.members                                     as apd_medicare_members,
    a.fills                                       as apd_medicare_fills,
    c.tot_benes                                   as cms_ny_benes,
    c.tot_clms                                    as cms_ny_claims,
    a.members / c.tot_benes                       as members_ratio_apd_over_cms,
    a.fills / c.tot_clms                          as fills_ratio_apd_over_cms,
    a.oop_share                                   as apd_oop_share,
    a.oop_per_fill                                as apd_oop_per_fill,
    c.nonlis_bene_cost_share / c.tot_clms         as cms_nonlis_cost_share_per_claim,
    c.lis_bene_cost_share / c.tot_clms            as cms_lis_cost_share_per_claim
from {{ ref('mart_vaccine_by_payer_year') }} a
join {{ ref('stg_cms_partd_geo') }} c
  on c.year = a.year and c.geo_desc = 'New York' and c.brand_name = 'Shingrix'
where a.payer_type = 'MEDICARE'
  and a.nonproprietary_name = 'ZOSTER VACCINE RECOMBINANT ADJUVANTED'
