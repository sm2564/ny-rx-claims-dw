-- Non-LIS beneficiary cost share per claim for every Part D vaccine brand from 2023 (NY and US).
-- The IRA set cost sharing to $0 for ACIP-recommended adult vaccines; residuals mark off-recommendation
-- use (Gardasil 9 above 45, RSV before the recommendation applied, Hep A outside risk groups).

select
    row_key,
    year,
    geo,
    product,
    vaccine_group,
    ira_zero_cost_expected,
    claims,
    nonlis_cost_share_total,
    nonlis_cost_share_per_claim,
    lis_cost_share_per_claim,
    nonlis_cost_share_per_claim >= 1.0 as residual_over_one_dollar
from {{ ref('mart_study_cross_vaccine_reversal') }}
where year >= 2023
