# Build plan: Prescriber-level Rx analytics on CMS Part D Prescribers by Provider and Drug (2023)

**Why:** ZS #3288 (and every pharma commercial analytics req) requires hands-on work with prescription / HCP-level secondary data. The closest free, real, public analog to vendor HCP-level Rx data (Xponent-style) is CMS's Part D Prescribers by Provider and Drug file: one row per prescriber NPI × drug, with claim counts, 30-day fills, day supply, drug cost, and beneficiary counts. Build it, then claim it (integrity rule from the modern-DE-stack plan: the clock starts at ship date; nothing goes on a resume until the repo exists and the numbers are in `article-digest.md`).

**Scope (one evening to a weekend):** one therapeutic class, prescriber-level market analysis in DuckDB + dbt, with tests and a README that states the numbers. Stack he already holds: DuckDB, dbt-duckdb, Python, GitHub Actions (see `nyc-health-dw`).

**Deliverable names (fixed now so the resume line can be written later):**
- Repo: `~/Projects/CCD/` (this folder; private is fine; cite by name, no URL, per the GitHub-private rule).
- Resume project line, written only after Step 9: "Prescriber-Level Rx Market Analysis on CMS Part D | DuckDB, dbt, Python".

---

## Step 0. Decide the class (10 min)
Pick ONE class whose brands are mostly retail-pharmacy, Part D-covered, and recognizable to a brand team. Two good options:
- **Oral anticoagulants (DOACs + warfarin):** Eliquis (apixaban), Xarelto (rivaroxaban), Pradaxa (dabigatran), Savaysa (edoxaban), warfarin. Clean class, high Medicare volume, brand vs generic story.
- **GLP-1 receptor agonists (diabetes-indicated, Part D-covered):** Ozempic, Rybelsus, Trulicity, Mounjaro, Victoza / liraglutide, Bydureon BCise. Note: weight-loss-only brands (Wegovy, Zepbound) are generally NOT Part D-covered for obesity, so the class is diabetes GLP-1s. Topical for ZS (IRA negotiation cycle, GLP-1 demand).
Write the product list as a seed CSV: `seeds/class_products.csv` with columns `brand_name, generic_name, class, molecule, is_brand`. This is the "market definition by product list" that the ZS drill (Part 1, Spine) calls for.

## Step 1. Get the data (30 min)
1. Dataset page: https://data.cms.gov/provider-summary-by-type-of-service/medicare-part-d-prescribers/medicare-part-d-prescribers-by-provider-and-drug (2023 is the latest year, released May 2026).
2. Open the data dictionary linked on that page and copy the column list into `docs/data-dictionary.md`. Confirm the exact names before coding; expect columns like `Prscrbr_NPI`, `Prscrbr_Type`, `Prscrbr_State_Abrvtn`, `Brnd_Name`, `Gnrc_Name`, `Tot_Clms`, `Tot_30day_Fills`, `Tot_Day_Suply`, `Tot_Drug_Cst`, `Tot_Benes`, plus the `GE65_*` (age 65+) variants and suppression flags.
3. Download the full-year CSV (large; ~25M rows) OR pull only the class via the Socrata-style API filter on `Brnd_Name` / `Gnrc_Name` (the page has an "API" tab with the query syntax). Prefer the full CSV once, stored under `data/raw/` (gitignored), so the class share denominator can be the whole market later.
4. Record in the README: file name, download date, row count, and the suppression rule from the methodology PDF (drug rows with fewer than 11 claims are suppressed; beneficiary counts under 11 are blanked). This is the "caveats" slide of the ZS drill.

## Step 2. Load into DuckDB (20 min)
```
duckdb data/partd.duckdb
CREATE TABLE raw_partd AS SELECT * FROM read_csv_auto('data/raw/<file>.csv', header=true);
SELECT count(*), count(DISTINCT Prscrbr_NPI) FROM raw_partd;
```
Save the two counts to the README. Check `Tot_Clms` sums for the class against a CMS public total if one exists (control-total habit from COpAT).

## Step 3. dbt project skeleton (30 min)
`dbt init ccd_partd` (inside this folder) with the duckdb adapter (copy `profiles.yml` pattern from `nyc-health-dw`).
- `models/staging/stg_partd_prescriber_drug.sql`: typed columns, lower-snake names, `prescriber_npi`, `prescriber_type`, `state`, `brand_name`, `generic_name`, `total_claims`, `total_30day_fills`, `total_day_supply`, `total_drug_cost`, `total_benes` (nullable), `year = 2023`.
- `models/staging/stg_class_products.sql` from the seed.
- `models/intermediate/int_class_rows.sql`: staging rows joined to the product list (the market).
- Tests in `schema.yml`: `not_null` + `unique` on (`prescriber_npi`, `brand_name`, `generic_name`); `accepted_values` on `is_brand`; `relationships` from class rows to the seed; a `dbt_utils.expression_is_true` that `total_30day_fills >= total_claims` is NOT assumed (it is often lower or higher; test instead that both are >= 0).

## Step 4. Marts (the analytics; 1-2 h)
1. `mart_brand_share.sql`: per brand, claims, 30-day fills, drug cost, prescriber count; share of class = brand claims / class claims. (ZS vocabulary: TRx ≈ `total_claims`; there is no NBRx in this file, say so.)
2. `mart_prescriber_class_volume.sql`: per NPI, class claims, brand claims, brand share, specialty, state; **deciles** by class claims (`ntile(10)`), decile 10 = top writers.
3. `mart_decile_concentration.sql`: share of class claims written by each decile; top-decile and top-two-decile concentration (the "targeting" numbers).
4. `mart_specialty_cut.sql` and `mart_state_cut.sql`: class claims and brand share by `prescriber_type` and by state; brand share variation across states.
5. `mart_cost_per_fill.sql`: `total_drug_cost / total_30day_fills` by brand (gross cost, not net; state that gross-to-net is unobservable here).
Tests: every mart has `not_null` on keys; a reconciliation test that the sum of decile claims equals the class total (the cross-source roll-up pattern from `nyc-health-dw`); share columns bounded [0, 1].

## Step 5. One notebook or script with the readout (1 h)
`analysis/readout.py` (pandas over DuckDB) producing 4 figures: brand share bar, decile concentration curve, state choropleth or bar, specialty mix. Save PNGs to `docs/`. Write the numbers into the README in plain sentences (e.g., "the top decile of prescribers writes X% of class claims"; "Brand A holds Y% share of class claims; its share ranges from a% to b% across states").

## Step 6. CI (20 min)
`.github/workflows/dbt.yml`: on push, install dbt-duckdb, `dbt seed && dbt build` against a small sample parquet checked into `data/sample/` (first 200k rows of the class), so CI runs in under a minute. Full data stays local.

## Step 7. README (30 min)
Sections: what the data is and is not (Medicare Part D only; projected nothing; suppression; no patient-level, no NBRx, gross cost); market definition (the seed); grain and keys; the five marts; the headline numbers; how to run; what a brand team would do next (link the ZS drill's question set: grain, keys, denominator, time, missing channels).

## Step 8. Attest (15 min, in career-ops)
Add a section to `article-digest.md` ("CMS Part D prescriber-level Rx market analysis") with every number and its mart; add the project to `cv.md` Projects with the role/period tag "Personal project (2026)"; update the memory `project-cms-part-d-prescriber-project-plan` to SHIPPED with the date.

## Step 9. Claim (10 min)
Only now: the resume project line and a sentence in the ZS crosswalk G1 answer ("I have since built a prescriber-level Rx market analysis on the public Part D file: class definition by product list, brand share, prescriber deciles, state and specialty cuts"). Never describe it as vendor data or as patient-level.

## Later (optional, separate project)
CMS DE-SynPUF (synthetic 2008-2010 Medicare beneficiary, inpatient, outpatient, carrier, and Part D event files) for patient-level persistence and adherence drills (PDC, time to discontinuation): patient-level and longitudinal, but synthetic and old; keep it a drill, not a resume line.
