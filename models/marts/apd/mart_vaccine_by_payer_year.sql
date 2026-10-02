-- Vaccines in the APD summary file, per year x payer x active ingredient (the summary grain).
-- Brands that share an ingredient (Boostrix + Adacel) are pooled here; see mart_vaccine_brand_by_payer_year
-- for the NDC-9 brand split. Age-band estimates apply the row's age shares to fills and members
-- (the state publishes shares, not counts; the file does not say whether shares are of fills or members).

with base as (

    select
        s.year,
        s.payer_type,
        m.vaccine_group,
        s.nonproprietary_name,
        m.products,
        m.part                    as medicare_benefit_part,
        m.schedule,
        m.eligible_age_min,
        m.ira_zero_cost_from,
        sum(s.rx_count)           as fills,
        sum(s.unique_members)     as members,
        sum(s.member_paid_sum)    as member_paid_sum,
        sum(s.insurer_paid_sum)   as insurer_paid_sum,
        sum(s.total_paid_sum)     as total_paid_sum,
        -- shares are identical across class rows of the same ingredient in practice; take the fill-weighted mean
        sum(s.rx_count * s.pct_age_under_19) / sum(s.rx_count) as pct_age_under_19,
        sum(s.rx_count * s.pct_age_19_44)    / sum(s.rx_count) as pct_age_19_44,
        sum(s.rx_count * s.pct_age_45_64)    / sum(s.rx_count) as pct_age_45_64,
        sum(s.rx_count * s.pct_age_65_plus)  / sum(s.rx_count) as pct_age_65_plus,
        sum(s.rx_count * s.pct_female)       / sum(s.rx_count) as pct_female
    from {{ ref('stg_apd_rx_summary') }} s
    join {{ ref('int_vaccine_ingredient_map') }} m using (nonproprietary_name)
    group by all

)

select
    year || '|' || payer_type || '|' || nonproprietary_name as row_key,
    *,
    fills / nullif(members, 0)                 as fills_per_member,
    member_paid_sum / nullif(total_paid_sum, 0) as oop_share,
    member_paid_sum / nullif(fills, 0)         as oop_per_fill,
    total_paid_sum / nullif(fills, 0)          as paid_per_fill,
    fills   * pct_age_45_64                    as fills_age_45_64_est,
    fills   * pct_age_65_plus                  as fills_age_65_plus_est,
    members * pct_age_45_64                    as members_age_45_64_est,
    members * pct_age_65_plus                  as members_age_65_plus_est,
    year >= extract(year from ira_zero_cost_from) and payer_type = 'MEDICARE' as is_ira_zero_cost_period
from base
