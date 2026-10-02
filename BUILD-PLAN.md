# Build plan v2: Vaccine cost-sharing study on commercial, Medicare, and Medicaid pharmacy claims (NY All-Payer Database + CMS Part D / Part B)

**Status:** SHIPPED 2026-10-02. Phases A-E done. Public repo https://github.com/sm2564/ny-rx-claims-dw (first commit 6e66ad1; second commit fixed the workflow YAML, whose `--vars` JSON needed a block scalar). Pages: https://sm2564.github.io/ny-rx-claims-dw. `dbt build`: 161 pass, 1 expected warn, 0 errors, locally and in CI on `data/sample/`. career-ops-3: article-digest.md §14 (every number with its mart), cv.md Projects entry, keyword-bank Tier 1 line, bullet variants RX-AE-1 / RX-HRA-1 / RX-DAM-1 / RX-DAM-2 / RX-DGA-1, ZS G1 (v3). v1 (CMS Part D class-level market analysis) is kept as `BUILD-PLAN-v1-2026-10-01.md`; its prescriber-level marts survive as Phase C here.

**Why:** ZS #3288 recruiter screen (2026-10-01) named "hands-on commercial pharmaceutical secondary data (claims, prescription)" as the one gap. No record-level commercial claims file is public. The closest real thing is New York State's All-Payer Database (APD) prescription public-use files: insurer-submitted pharmacy claims, aggregated by the state, 2018-2023, split COMMERCIAL / MEDICARE / NYS PROGRAMS. This plan builds a warehouse over those files and uses them, together with CMS Part D and Part B public files, to answer one dated policy question with a published benchmark. Integrity rule unchanged: nothing goes on a resume until the repo exists and the numbers are in `career-ops-3/article-digest.md`; the clock starts at ship date.

**The question:** Did the Inflation Reduction Act's $0 cost sharing for Part D vaccines (effective 2023-01-01) raise uptake, and did it hold up against the 2024 decline? Benchmarks: USC/Michigan JAMA research letter (May 2024, IQVIA NPA, Part D +46%, commercial -21%, DiD design); ASPE HP-2024-09 (Medicare claims, shingles +42%, Tdap +114% vs 2021). Published work stops at 2023; this project adds 2024, the cross-vaccine reversal pattern, the within-Medicare Part B comparison, and the prescriber layer.

**What commercial claims work this demonstrates (say it this way, never "vendor" or "record-level"):** payer segmentation of pharmacy claims; NDC-9 / labeler / brand-generic drug dimension; plan-paid vs member-paid decomposition from sums; control-group contamination check and age restriction; detail-to-summary reconciliation; documented data breaks. Resume line (written only after Phase E): "Pharmacy claims analytics across commercial, Medicare, and Medicaid segments on the NY All-Payer Database and CMS Part D/Part B public files: policy difference-in-differences with a published benchmark | DuckDB, dbt, Python".

---

## Phase A. NY APD all-payer pharmacy claims warehouse (the commercial-claims layer; load-bearing)

### A0. Sources (verified 2026-10-01 via Socrata API; some duplicate dataset ids on the portal are dead aliases, use these)
| Year | Summary (per active ingredient x payer, ~5.4k rows) | Detail (per NDC-9 x payer, ~48.6k rows) |
|---|---|---|
| 2018 | `ci3f-cgyk` | `cyc9-2wny` |
| 2019 | `4dcc-cpuw` | `uyx4-b5m4` |
| 2020 | `ex4n-37un` | `4w6e-7nqk` |
| 2021 | `6fqq-u42v` | `abip-s7zs` |
| 2022 | `u7cf-j545` | `dqfk-auc2` |
| 2023 | `hz49-8qnd` | `ch8f-5ikm` (verify; alt `vwf9-djje`) |
API: `https://health.data.ny.gov/resource/<id>.json` (Socrata; `$select`, `$where`, `$limit=50000`, or CSV export via `/api/views/<id>/rows.csv?accessType=DOWNLOAD`). Store raw CSVs under `data/raw/apd/` (gitignored); check a 2018 and a 2023 summary file into `data/sample/` for CI.

Columns (both files): year, file_type, number_of_prescriptions_filled, nonproprietary_drug_name, therapeutic_class, payer_type, unique_members, median/mean/sd of days_supply, quantity, insurer_paid, member_paid, total_paid, and `sum_insurer_paid_amount`, `sum_member_paid_amount`, `sum_total_paid_amount`. Summary adds `percentage_aged_*` and `percentage_female/male`. Detail adds `ndc_9_digits`, `proprietary_drug_name`, `drug_category` (BRAND/GENERIC/NA), `labeler_name`, `dosage_form`, `active_strength`, `active_strength_unit`.

### A1. Known data facts to encode as tests or documented caveats (all observed 2026-10-01)
- Mean/median paid columns are "when not zero": they EXCLUDE $0 fills and rise after a $0 policy. Use the `sum_*` columns for any cost-sharing measure. Test: never derive OOP share from means.
- 2023 summary `percentage_*` columns are scaled 1/100 relative to 2018-2022 (e.g., 0.0092 vs 0.912). Normalize in staging; test that age shares sum to ~1 per row after normalization.
- NYS PROGRAMS vaccine rows drop ~75% in 2023 (Shingrix 45,733 -> 11,212) coinciding with the 2023-04-01 NYRx pharmacy carve-out. Medicaid is NOT a usable control for 2023 vaccines; document, do not model.
- COMMERCIAL includes self-funded (ERISA) plans and employer retiree plans that are not Part D; MEDICARE includes standalone Part D and Medicare Advantage drug plans (confirmed by the 2023 cost-sharing collapse landing there). Commercial 65+ fills fell -22% in 2023 vs -13% for 45-64: payer switching contaminates the 65+ slice of the control. Control = commercial ages 45-64 (file bands; Shingrix eligibility starts at 50, state the approximation).
- No prescriber, no sub-state geography, no month, no patient level, no dose number. "All-payer" means insurer-submitted claims of all three segments; it is not vendor data.
- 2023 totals: Commercial 36.5M Rx / $7.0B; Medicare 114.3M / $21.0B; NYS Programs 87.6M / $10.2B (summary file sums; record in README as control totals).

### A2. dbt models (DuckDB; copy `profiles.yml`, CI, and reconciliation-test pattern from `~/Projects/nyc-health-dw`)
- `stg_apd_rx_summary`, `stg_apd_rx_detail`: typed, snake_case, year as int, payer_type as enum, 2023 percentage normalization.
- `dim_payer` (3 rows, with the program definitions above), `dim_drug_ndc9` (from detail: ndc9, labeler, brand/generic, class, form, strength), `dim_ingredient` (from summary).
- `seeds/vaccine_products.csv`: nonproprietary names and NDC-9s for Shingrix, Zostavax, RSV (Arexvy, Abrysvo), Tdap (Boostrix, Adacel), Td (Tenivac, Tdvax), Hep A/B (Havrix, Vaqta, Engerix-B, Heplisav-B, Recombivax, Twinrix, PreHevbrio), HPV (Gardasil 9), meningococcal (Menveo, MenQuadfi, Menactra, Bexsero, Trumenba), typhoid (Typhim Vi, Vivotif); columns: product, nonproprietary_name_pattern, ndc9_list, part (D/B), schedule (once / series / 10yr / annual), eligible_age_min, ira_zero_cost_from (2023-01-01 or NULL).
- Marts:
  - `mart_payer_market`: per year x payer: Rx, members, total/insurer/member paid, member-paid share.
  - `mart_class_by_payer`: per year x payer x therapeutic class, with commercial share of class.
  - `mart_brand_generic_by_payer`: brand vs generic Rx and spend share per year x payer.
  - `mart_labeler_commercial`: top labelers by commercial spend per year (from detail).
  - `mart_vaccine_by_payer_year`: the vaccine seed joined to summary: fills, members, fills_per_member, member_paid_sum, total_paid_sum, oop_share, oop_per_fill, age-band fills.
- Tests: unique (year, payer, ingredient) and (year, payer, ndc9); not_null keys; `member + insurer = total` within $1 per row; shares in [0,1]; detail rows summed by ingredient x payer x year reconcile to the summary row within 0.5% (singular test; report the misses); 2023 age shares sum to 1 after normalization; vaccine seed `relationships` to dim_ingredient.

### A3. Phase A readout (the commercial-claims deliverable in its own right)
`analysis/apd_readout.py`: four figures to `docs/`: payer market size 2018-2023; commercial brand/generic share; commercial member-paid share by class; vaccine OOP share by payer 2018-2023 (Shingrix, Tdap). README section "What commercial claims are here, and what they are not."

## Phase B. The policy study (Medicare vaccine $0 cost sharing)

### B0. Additional sources
- CMS Part D Prescribers by Geography and Drug (state + national rows), 2018-2024: ids 2018 `b083c9b6-b841-4676-8d0a-fb03ee1431a1`, 2019 `73a6335e-f16f-4c81-a84b-6b5a986e2bf8`, 2020 `83891e77-99cf-4865-b60a-97703b916e09`, 2021 `7dda2a9d-034a-446a-b4b3-e1254e0127b2`, 2022 `1fc57194-a51d-4864-aee6-de0889488151`, 2023 `3463648b-1971-478d-84ca-80cadc758153`, 2024 `c8ea3f8e-3a09-4fea-86f2-8902fb4b0920`. Columns include Tot_Clms, Tot_Benes, Tot_Prscrbrs, Tot_Drug_Cst, LIS_Bene_Cst_Shr, NonLIS_Bene_Cst_Shr. API filter: `filter[f0][condition][path]=Brnd_Name&...[operator]=CONTAINS&...[value]=Shingrix`. Note the 2024 catalog title reads "2024-12-01" where other years read "12-31": verify full-year coverage against a flat-demand drug before using 2024.
- CMS Medicare Physician & Other Practitioners by Geography and Service (and by Provider and Service for Phase C), 2018-2024: Part B vaccines by HCPCS. Flu: 90653, 90656, 90662, 90674, 90682, 90686, 90688, 90694, 90756 + admin G0008. Pneumococcal: 90670, 90671, 90677, 90732 + admin G0009. COVID: 91300-series + admin (report only, not a fatigue benchmark). TO VERIFY FIRST: that pharmacy roster-billed flu shots appear in these files under pharmacy NPIs; if not, use the geography file only and say so.
- Denominators: CMS Medicare enrollment by state/county (Part D enrollment for NY); Census ACS population 50+ and 65+ for NY by year.

### B1. Designs (in this order; each one is a mart + a figure + a paragraph)
1. **Replication, Medicare vs Commercial DiD (NY APD).** Outcome: unique members with a Shingrix fill, per 1,000 enrollees. Treated: MEDICARE. Control: COMMERCIAL ages 45-64. Pre: 2021-2022. Post: 2023. First stage: OOP share (Medicare 21.7% -> 3.2%; commercial flat ~4%). Report alongside JAMA 2024 (+46 / -21) and ASPE (+42). Pre-trend check on 2018-2022 for both segments (the published papers do not do this).
2. **Within-Medicare, Part D vs Part B (CMS files, NY + national, 2018-2024).** Treated: Part D vaccines (Shingrix, Tdap/Td, Hep, HPV, meningococcal, travel; RSV reported separately because of the 2024-06 recommendation change). Always-free comparators: flu (fatigue meter, annual, no depletion); pneumococcal (depletion comparator, once-per-lifetime; model the late-2021 PCV20 launch bump or start the series in 2022). Measures: (a) Shingrix/flu claims ratio by year; (b) uptake as share of remaining eligible pool, pool = Census 65+ minus cumulative fills since 2018, for Shingrix and pneumococcal; (c) event-study coefficients 2023, 2024 (2025 when released ~2027-05).
3. **Cross-vaccine reversal table (CMS NY Part D, 2021-2024).** Already observed: Shingrix +30%/-28%, Arexvy -43%, Abrysvo -19%, Boostrix +78%/+19%, Adacel +21%/-6%, Twinrix/Havrix/Typhim/Gardasil/meningococcal all up in 2024. Interpretation: 2024 decline is specific to the once-per-lifetime, 2023-surge vaccines (depletion + RSV recommendation narrowing), not general. This is a heterogeneity test, not a DiD (all Part D vaccines were freed the same day); say so.
4. **Boostrix vs Adacel brand share within Tdap** (the brand-team finding): share by year, NY and national, 2018-2024.

### B2. Phase B tests
Sum of brand rows reconciles to the state total per vaccine class; NY APD Medicare Shingrix members vs CMS NY Shingrix benes agree within 20% each year (two independent sources; report the ratio); NonLIS_Bene_Cst_Shr = 0 for every ACIP-recommended Part D brand from 2023 (the residuals on Gardasil, RSV, Hep A are off-recommendation use; document).

## Phase C. Prescriber layer (CMS Part D by Provider and Drug + by Provider; v1's marts, re-pointed at vaccines)
- Load NY rows only (filter `Prscrbr_State_Abrvtn=NY`) for 2018-2024, by-Provider-and-Drug (ids in v1 / catalog: 2023 `e54db557-cd82-4e91-a0fe-61aad5865d69`, 2024 `9552739e-3d05-4c1b-8eff-ecabf391e2e5`) and by-Provider (2023 `42888afe-3b85-4a61-a4ee-091f00bd62bc`, 2024 `14d8e8a9-7e9b-4370-a044-bf97c46b4b44`; carries Prscrbr_Zip5, RUCA, LIS_Tot_Clms / NonLIS_Tot_Clms, MAPD/PDP split, dual and race bene counts).
- Marts (v1 vocabulary): `mart_vaccine_prescriber` (per NPI x product x year), `mart_prescriber_deciles` (ntile(10) on Shingrix claims; top-decile concentration pre/post), `mart_specialty_cut` (pharmacist vs physician vs NP/PA share), `mart_nyc_dose_response` (NYC ZIPs; treatment intensity = 2022 non-LIS share; outcome = Shingrix claims 2018-2024; prescriber FE), `mart_prescriber_attrition` (NPIs present 2023 absent 2024: is the 2024 drop demand or channel).
- Optional: CMS Facility Affiliation file (`data.cms.gov/provider-data`, id `27ea-46a8`, NPI -> hospital CCN) to tag H+H vs voluntary affiliation for a Medicare-side cut tied to the migrant-impact hospital list. Spillover only; never claim it measures migrant prescriptions.
- Caveat: rows under 11 claims suppressed; prescriber ZIP is practice location; pharmacy-administered vaccines carry pharmacy/pharmacist NPIs.

## Phase D. CI, README, readout
- `.github/workflows/dbt.yml`: `dbt seed && dbt build` on the `data/sample/` files (two APD summary years + one CMS geography extract), under one minute.
- README sections: what the data is and is not (per payer segment); the question and the published benchmarks; grain and keys; the marts; headline numbers in plain sentences (replication estimate, within-Medicare estimate, 2024 reversal table, Tdap brand share); the data breaks found (means-exclude-zero, 2023 scaling, NYRx break, 2024 title date); what a brand team would do next.
- `analysis/readout.py`: all figures to `docs/`.

## Phase E. Attest, then claim (career-ops-3)
- `article-digest.md`: new section with every number and its mart; `cv.md` Projects entry tagged "Personal project (2026)"; memory `project-ccd-partd-context` -> SHIPPED with date.
- Only then: the resume line above, and in the ZS G1 answer: "I have since built a pharmacy-claims warehouse over New York's all-payer database, commercial, Medicare, and Medicaid segments, and used it with CMS Part D and Part B files to replicate and extend the published estimate of the IRA vaccine cost-sharing effect." Never "vendor data", never "record-level commercial claims", never "patient-level".

## Later (separate)
- Columbia data access: ask Mailman library / HPM whether MarketScan, Optum, or IQVIA licenses are open to TA staff; a yes converts the commercial layer to record-level work.
- Migrant-signature Medicaid Rx study (statewide, SDUD quarterly + APD NYS Programs): a different project, health-policy shaped.
