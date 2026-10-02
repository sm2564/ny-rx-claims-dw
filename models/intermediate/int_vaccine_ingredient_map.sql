-- One row per APD active-ingredient name that matches a vaccine_products seed pattern.
-- Several brands can share one ingredient name (Boostrix and Adacel both map to the Tdap ingredient),
-- so group-level attributes are taken once and the matching products are listed.

with ingredients as (

    select distinct nonproprietary_name
    from {{ ref('stg_apd_rx_summary') }}

),

seed as (

    select *
    from {{ ref('vaccine_products') }}
    where apd_name_pattern is not null and apd_name_pattern <> ''

),

matched as (

    select
        i.nonproprietary_name,
        s.vaccine_group,
        s.part,
        s.schedule,
        s.eligible_age_min,
        s.ira_zero_cost_from,
        s.product
    from ingredients i
    join seed s on regexp_matches(i.nonproprietary_name, s.apd_name_pattern)

)

select
    nonproprietary_name,
    vaccine_group,
    part,
    schedule,
    eligible_age_min,
    ira_zero_cost_from,
    array_to_string(list_sort(list_distinct(list(product))), ', ') as products,
    count(distinct product)                                        as product_count
from matched
group by 1, 2, 3, 4, 5, 6
qualify row_number() over (partition by nonproprietary_name order by product_count desc, vaccine_group) = 1
