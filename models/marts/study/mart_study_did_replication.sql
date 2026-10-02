-- Design 1 panel: Shingrix uptake per year x segment in the NY APD, with denominators.
-- Treated = MEDICARE (all drug-plan members). Control = COMMERCIAL ages 45-64 (members x the row's 45-64 age
-- share; Shingrix eligibility starts at 50, so the file's 45-64 band is an approximation). Two further
-- segments are carried for the README only: commercial 65+ (contaminated by switching into Medicare) and
-- NYS Programs (NYRx carve-out break 2023-04-01). Pre = 2021-2022, post = 2023; 2018-2020 is the pre-trend window.
-- Commercial oop_share is the all-ages commercial value: the file does not publish cost sharing by age band.

with vax as (

    select *
    from {{ ref('mart_vaccine_by_payer_year') }}
    where nonproprietary_name = 'ZOSTER VACCINE RECOMBINANT ADJUVANTED'

),

den as (

    select * from {{ ref('stg_ny_denominators') }} where geo = 'NY'

),

panel as (

    select
        v.year, 'MEDICARE' as segment, 'treated' as arm,
        'Medicare drug-plan members, all ages (PDP + MA-PD)' as segment_definition,
        v.members, v.fills, v.oop_share, v.oop_per_fill, v.member_paid_sum, v.total_paid_sum,
        d.partd_enrollees as denominator, 'CMS Medicare Monthly Enrollment: NY Part D enrollees' as denominator_source
    from vax v join den d using (year)
    where v.payer_type = 'MEDICARE'

    union all

    select
        v.year, 'COMMERCIAL_45_64', 'control',
        'Commercial members ages 45-64 (members x age-45-64 share of the row)',
        v.members_age_45_64_est, v.fills_age_45_64_est, v.oop_share, v.oop_per_fill,
        v.member_paid_sum * v.pct_age_45_64, v.total_paid_sum * v.pct_age_45_64,
        d.pop_45_64, 'Census PEP: NY civilian population ages 45-64'
    from vax v join den d using (year)
    where v.payer_type = 'COMMERCIAL'

    union all

    select
        v.year, 'COMMERCIAL_65_PLUS', 'contaminated',
        'Commercial members 65+ (payer switching into Medicare; not a control)',
        v.members_age_65_plus_est, v.fills_age_65_plus_est, v.oop_share, v.oop_per_fill,
        v.member_paid_sum * v.pct_age_65_plus, v.total_paid_sum * v.pct_age_65_plus,
        d.pop_65_plus, 'Census PEP: NY civilian population 65+'
    from vax v join den d using (year)
    where v.payer_type = 'COMMERCIAL'

    union all

    select
        v.year, 'NYS_PROGRAMS', 'broken_2023',
        'Medicaid and state programs (NYRx pharmacy carve-out 2023-04-01; not a control)',
        v.members, v.fills, v.oop_share, v.oop_per_fill, v.member_paid_sum, v.total_paid_sum,
        null, 'none'
    from vax v
    where v.payer_type = 'NYS PROGRAMS'

)

select
    year || '|' || segment                                   as row_key,
    *,
    members / denominator * 1000                             as members_per_1000,
    fills / denominator * 1000                               as fills_per_1000,
    case when year between 2021 and 2022 then 'pre'
         when year = 2023 then 'post'
         else 'pre-trend' end                                as period,
    members / lag(members) over (partition by segment order by year) - 1                         as members_yoy_pct,
    (members / denominator) / lag(members / denominator) over (partition by segment order by year) - 1 as rate_yoy_pct,
    oop_share - lag(oop_share) over (partition by segment order by year)                          as oop_share_yoy_change
from panel
