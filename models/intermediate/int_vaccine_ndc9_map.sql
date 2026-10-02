-- One row per (product, NDC-9) from the pipe-separated apd_ndc9_list in the vaccine_products seed.

select
    s.product,
    s.vaccine_group,
    s.part,
    s.manufacturer,
    s.schedule,
    s.ira_zero_cost_from,
    trim(n.ndc9) as ndc9
from {{ ref('vaccine_products') }} s,
     unnest(string_split(s.apd_ndc9_list, '|')) as n(ndc9)
where s.apd_ndc9_list is not null and s.apd_ndc9_list <> ''
