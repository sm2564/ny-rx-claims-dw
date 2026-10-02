-- Denominators per geo x year, pivoted from the ny_denominators seed (Census PEP population; CMS enrollment).

select
    geo,
    year,
    max(case when measure = 'pop_total'              then value end) as pop_total,
    max(case when measure = 'pop_45_64'              then value end) as pop_45_64,
    max(case when measure = 'pop_50_plus'            then value end) as pop_50_plus,
    max(case when measure = 'pop_60_plus'            then value end) as pop_60_plus,
    max(case when measure = 'pop_65_plus'            then value end) as pop_65_plus,
    max(case when measure = 'medicare_total_benes'   then value end) as medicare_total_benes,
    max(case when measure = 'medicare_benes_65_plus' then value end) as medicare_benes_65_plus,
    max(case when measure = 'medicare_ma_benes'      then value end) as medicare_ma_benes,
    max(case when measure = 'medicare_total_benes'   then value end)
      - max(case when measure = 'medicare_ma_benes'  then value end) as medicare_ffs_benes,
    max(case when measure = 'partd_enrollees'        then value end) as partd_enrollees,
    max(case when measure = 'partd_pdp'              then value end) as partd_pdp,
    max(case when measure = 'partd_mapd'             then value end) as partd_mapd,
    max(case when measure = 'partd_lis'              then value end) as partd_lis,
    max(case when measure = 'partd_no_lis'           then value end) as partd_no_lis,
    max(case when measure = 'employer_ins_45_64'     then value end) as employer_ins_45_64,
    max(case when measure = 'medicare_cov_65_plus'   then value end) as medicare_cov_65_plus
from {{ ref('ny_denominators') }}
group by 1, 2
