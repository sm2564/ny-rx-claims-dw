-- Guard against a partial 2024 file: national claims for eight flat-demand generics must not fall more than
-- 5% year over year in 2024 (an 11-month file would show about -8% on every one of them).
with g as (
    select year, generic_name, sum(tot_clms) as clms
    from {{ ref('stg_cms_partd_geo') }}
    where geo_level = 'National'
      and generic_name in ('Levothyroxine Sodium', 'Atorvastatin Calcium', 'Amlodipine Besylate', 'Metformin Hcl',
                           'Lisinopril', 'Losartan Potassium', 'Metoprolol Succinate', 'Omeprazole')
    group by 1, 2
)
select a.generic_name, a.clms as clms_2024, b.clms as clms_2023, a.clms / b.clms - 1 as yoy
from g a join g b on a.generic_name = b.generic_name and a.year = 2024 and b.year = 2023
where a.clms / b.clms - 1 < -0.05
