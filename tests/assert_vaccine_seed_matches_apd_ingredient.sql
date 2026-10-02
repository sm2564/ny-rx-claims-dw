-- every seed row with an APD name pattern must match at least one ingredient in dim_ingredient
select s.product, s.apd_name_pattern
from {{ ref('vaccine_products') }} s
where s.apd_name_pattern is not null and s.apd_name_pattern <> ''
  and not exists (
      select 1 from {{ ref('dim_ingredient') }} i
      where regexp_matches(i.nonproprietary_name, s.apd_name_pattern)
  )
