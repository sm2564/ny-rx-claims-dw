{{ config(severity = 'warn') }}
-- Ingredient-level reconciliation (year x payer x ingredient) within 0.5%. Expected to WARN: the detail file
-- suppresses NDC-9 rows under 11 members into one VARIOUS row per payer-year, so about a third of ingredient
-- rows come in 0.5-1% low. mart_recon_apd_detail_vs_summary lists every miss. Totals are tested at error
-- severity in assert_apd_detail_totals_reconcile_to_summary.
select *
from {{ ref('mart_recon_apd_detail_vs_summary') }}
where recon_status in ('detail low', 'detail high')
  and nonproprietary_name not like 'VARIOUS%'
