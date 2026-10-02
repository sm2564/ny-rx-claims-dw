#!/usr/bin/env python3
"""Build data/sample/ so CI can run the full dbt build and test suite without the raw downloads.

Contents (kept small enough to commit):
  apd/apd_rx_summary_2018..2023.csv  : the six summary files in full (~1.2 MB each)
  apd/apd_rx_detail_2018.csv, _2023  : two detail files in full (every NDC-9 in seeds/vaccine_products.csv appears in one of them)
  cms/partd_geo/*.csv                : National + New York rows for the Part D vaccine brands and eight flat-demand generics, 2018-2024
  cms/phys_geo/*.csv                 : National + New York rows for the Part B vaccine HCPCS codes, 2018-2024
  cms/partd_prescriber/by_provider_drug_ny_vaccines_*.csv : in full (vaccine rows only, ~0.4 MB each)
  cms/partd_prescriber/by_provider_ny_*.csv               : only NPIs that appear in the vaccine rows that year
Run from the repo root after scripts/fetch_*.py: .venv/bin/python scripts/make_samples.py
"""
import csv, pathlib, shutil
import duckdb

ROOT = pathlib.Path(__file__).resolve().parents[1]
RAW, SAMPLE = ROOT / "data" / "raw", ROOT / "data" / "sample"
FLAT = ["Levothyroxine Sodium", "Atorvastatin Calcium", "Amlodipine Besylate", "Metformin Hcl", "Lisinopril", "Losartan Potassium", "Metoprolol Succinate", "Omeprazole"]


def main():
    brands = [r["cms_partd_brand_name"] for r in csv.DictReader(open(ROOT / "seeds" / "vaccine_products.csv")) if r["cms_partd_brand_name"]]
    hcpcs = [r["hcpcs_cd"] for r in csv.DictReader(open(ROOT / "seeds" / "vaccine_hcpcs.csv"))]
    for sub in ["apd", "cms/partd_geo", "cms/phys_geo", "cms/partd_prescriber"]:
        (SAMPLE / sub).mkdir(parents=True, exist_ok=True)
    for y in range(2018, 2024):
        shutil.copy(RAW / "apd" / f"apd_rx_summary_{y}.csv", SAMPLE / "apd")
    for y in (2018, 2023):
        shutil.copy(RAW / "apd" / f"apd_rx_detail_{y}.csv", SAMPLE / "apd")
    con = duckdb.connect()
    bl = ",".join(f"'{b}'" for b in brands); hl = ",".join(f"'{h}'" for h in hcpcs); fl = ",".join(f"'{f}'" for f in FLAT)
    for y in range(2018, 2025):
        con.execute(f"""copy (select * from read_csv_auto('{RAW}/cms/partd_geo/partd_geo_{y}.csv', all_varchar=true, header=true)
                         where Prscrbr_Geo_Desc in ('National','New York') and (Brnd_Name in ({bl}) or Gnrc_Name in ({fl})))
                        to '{SAMPLE}/cms/partd_geo/partd_geo_{y}.csv' (header, delimiter ',')""")
        con.execute(f"""copy (select * from read_csv_auto('{RAW}/cms/phys_geo/phys_geo_{y}.csv', all_varchar=true, header=true)
                         where Rndrng_Prvdr_Geo_Desc in ('National','New York') and HCPCS_Cd in ({hl}))
                        to '{SAMPLE}/cms/phys_geo/phys_geo_{y}.csv' (header, delimiter ',')""")
        shutil.copy(RAW / "cms" / "partd_prescriber" / f"by_provider_drug_ny_vaccines_{y}.csv", SAMPLE / "cms" / "partd_prescriber")
        con.execute(f"""copy (select p.* from read_csv_auto('{RAW}/cms/partd_prescriber/by_provider_ny_{y}.csv', all_varchar=true, header=true) p
                         where p.Prscrbr_NPI in (select Prscrbr_NPI from read_csv_auto('{RAW}/cms/partd_prescriber/by_provider_drug_ny_vaccines_{y}.csv', all_varchar=true, header=true)))
                        to '{SAMPLE}/cms/partd_prescriber/by_provider_ny_{y}.csv' (header, delimiter ',')""")
    total = sum(f.stat().st_size for f in SAMPLE.rglob("*.csv"))
    print(f"sample built: {sum(1 for _ in SAMPLE.rglob('*.csv'))} files, {total/1e6:.1f} MB")


if __name__ == "__main__":
    main()
