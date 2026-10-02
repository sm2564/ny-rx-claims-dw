-- Design 1 estimates: pre (mean 2021-2022) vs post (2023) for treated (Medicare) and control (commercial 45-64).
-- did_pct_points = difference of percentage changes (the form the JAMA letter reports);
-- did_log = ln ratio-of-ratios (the regression DiD on log outcomes). Two aggregate series, so no standard errors:
-- this is a point estimate with a published benchmark, not an inference.

with p as (

    select * from {{ ref('mart_study_did_replication') }} where arm in ('treated', 'control')

),

agg as (

    select
        arm,
        avg(case when period = 'pre'  then members_per_1000 end) as pre_rate,
        avg(case when period = 'post' then members_per_1000 end) as post_rate,
        avg(case when period = 'pre'  then members end)          as pre_members,
        avg(case when period = 'post' then members end)          as post_members,
        avg(case when period = 'pre'  then fills end)            as pre_fills,
        avg(case when period = 'post' then fills end)            as post_fills,
        avg(case when period = 'pre'  then oop_share end)        as pre_oop,
        avg(case when period = 'post' then oop_share end)        as post_oop,
        max(case when year = 2018 then members_per_1000 end)     as rate_2018,
        max(case when year = 2022 then members_per_1000 end)     as rate_2022,
        max(case when year = 2023 then members_per_1000 end)     as rate_2023
    from p
    group by 1

),

long as (

    select 'members_per_1000' as measure, 'pre = mean 2021-2022, post = 2023' as definition, arm, pre_rate as pre_value, post_rate as post_value from agg
    union all select 'members', 'pre = mean 2021-2022, post = 2023', arm, pre_members, post_members from agg
    union all select 'fills', 'pre = mean 2021-2022, post = 2023', arm, pre_fills, post_fills from agg
    union all select 'oop_share (first stage)', 'pre = mean 2021-2022, post = 2023', arm, pre_oop, post_oop from agg
    union all select 'members_per_1000, 2022 vs 2023', 'pre = 2022, post = 2023', arm, rate_2022, rate_2023 from agg
    union all select 'members_per_1000 pre-trend', 'pre = 2018, post = 2022 (no policy change; should be ~0)', arm, rate_2018, rate_2022 from agg

),

wide as (

    select
        measure, definition,
        max(case when arm = 'treated' then pre_value end)  as treated_pre,
        max(case when arm = 'treated' then post_value end) as treated_post,
        max(case when arm = 'control' then pre_value end)  as control_pre,
        max(case when arm = 'control' then post_value end) as control_post
    from long
    group by 1, 2

)

select
    measure,
    definition,
    treated_pre,
    treated_post,
    treated_post - treated_pre                                      as treated_change_abs,
    treated_post / treated_pre - 1                                  as treated_change_pct,
    control_pre,
    control_post,
    control_post - control_pre                                      as control_change_abs,
    control_post / control_pre - 1                                  as control_change_pct,
    (treated_post / treated_pre - 1) - (control_post / control_pre - 1) as did_pct_points,
    (treated_post / treated_pre) / (control_post / control_pre) - 1 as did_ratio_of_ratios,
    ln(treated_post / treated_pre) - ln(control_post / control_pre) as did_log
from wide
