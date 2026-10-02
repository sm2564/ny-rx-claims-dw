-- after the 2023 rescale, the four age shares (and the two sex shares) must sum to 1 +/- 0.02 on every row
select row_key, year, pct_age_under_19 + pct_age_19_44 + pct_age_45_64 + pct_age_65_plus as age_sum,
       pct_female + pct_male as sex_sum
from {{ ref('stg_apd_rx_summary') }}
where abs(pct_age_under_19 + pct_age_19_44 + pct_age_45_64 + pct_age_65_plus - 1) > 0.02
   or abs(pct_female + pct_male - 1) > 0.02
