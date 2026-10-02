-- From 2023 every ACIP-recommended Part D vaccine brand must show (near-)zero non-LIS cost sharing:
-- under $1 per claim. Brands flagged ira_zero_cost_expected = 'N' (Gardasil 9, Zostavax) are excluded;
-- their residuals are documented in mart_study_cost_share_residuals.
select year, geo, product, claims, nonlis_cost_share_per_claim
from {{ ref('mart_study_cost_share_residuals') }}
where ira_zero_cost_expected = 'Y'
  and residual_over_one_dollar
