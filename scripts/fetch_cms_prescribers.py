#!/usr/bin/env python3
"""Pull New York rows from the CMS Medicare Part D Prescribers files (data.cms.gov API).

Two pulls per data year 2018-2024:
  by Provider           : every NY prescriber NPI (~100k rows/yr; LIS / non-LIS, MAPD / PDP, dual, race, ZIP, RUCA)
  by Provider and Drug  : NY rows for the Part D vaccine brands only (rows under 11 claims are suppressed by CMS)

Output: data/raw/cms/partd_prescriber/by_provider_ny_<year>.csv and by_provider_drug_ny_vaccines_<year>.csv
Idempotent: skips a year whose output already exists unless --force.
"""
import csv, sys, time, pathlib, requests

API = "https://data.cms.gov/data-api/v1/dataset/{}/data"
OUT = pathlib.Path(__file__).resolve().parents[1] / "data" / "raw" / "cms" / "partd_prescriber"

BY_PROVIDER = {
    2018: "0b4a3f5a-9cc0-4f61-a2a9-34945b85d84b", 2019: "1f0bef67-2dae-460d-ac47-02866bb3a4bb",
    2020: "265b3d0b-495d-424c-a204-5e3b86e4e6d0", 2021: "838f7a4c-0423-4370-8227-588ce9b94b93",
    2022: "adcdaca6-0c9c-485f-af21-1abc16104d6c", 2023: "42888afe-3b85-4a61-a4ee-091f00bd62bc",
    2024: "14d8e8a9-7e9b-4370-a044-bf97c46b4b44",
}
BY_PROVIDER_DRUG = {
    2018: "802fe556-311f-4962-8d75-d5f4ff405884", 2019: "2a6705e6-7a1e-460c-ba22-35249a531918",
    2020: "7795fe20-e80e-435a-a9ed-d2d65e05feeb", 2021: "f68114ed-f854-4ffc-9c6e-ed78b5e2f8d0",
    2022: "b101b457-ffa4-49bb-8fd9-27c1266086e2", 2023: "e54db557-cd82-4e91-a0fe-61aad5865d69",
    2024: "9552739e-3d05-4c1b-8eff-ecabf391e2e5",
}
# Brand names exactly as they appear in the Part D files (checked against the by-Geography-and-Drug files 2018-2024).
VACCINE_BRANDS = [
    "Shingrix", "Zostavax", "Arexvy", "Abrysvo", "Mresvia",
    "Boostrix Tdap", "Adacel Tdap", "Tenivac", "Tdvax",
    "Havrix", "Vaqta", "Engerix-B Adult", "Heplisav-B", "Recombivax Hb", "Twinrix", "Prehevbrio",
    "Gardasil 9", "Menveo A-C-Y-W-135-Dip", "Menquadfi", "Menactra", "Bexsero", "Trumenba", "Penbraya",
    "Typhim Vi", "Varivax Vaccine", "M-M-R Ii Vaccine", "Priorix", "Yf-Vax", "Stamaril", "Ixiaro",
    "Imovax Rabies Vaccine", "Rabavert",
]
PAGE = 5000


def fetch_all(dataset_id, params):
    rows, offset = [], 0
    while True:
        p = list(params) + [("size", PAGE), ("offset", offset)]
        for attempt in range(6):
            try:
                r = requests.get(API.format(dataset_id), params=p, timeout=600)
                r.raise_for_status()
                batch = r.json()
                break
            except Exception as e:  # noqa: BLE001
                print(f"    retry {attempt+1} offset {offset}: {e}", flush=True)
                time.sleep(10 * (attempt + 1))
        else:
            raise RuntimeError(f"gave up on {dataset_id} offset {offset}")
        rows.extend(batch)
        print(f"    offset {offset}: +{len(batch)} (total {len(rows)})", flush=True)
        if len(batch) < PAGE:
            return rows
        offset += PAGE


def write_csv(rows, path):
    cols = []
    for r in rows:
        for k in r:
            if k not in cols:
                cols.append(k)
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)


def main(force=False):
    OUT.mkdir(parents=True, exist_ok=True)
    for year in range(2018, 2025):
        # by Provider and Drug, vaccines only (smaller; do first so Phase C can start)
        out = OUT / f"by_provider_drug_ny_vaccines_{year}.csv"
        if force or not out.exists():
            print(f"== by Provider and Drug {year} (NY, vaccine brands)", flush=True)
            params = [
                ("filter[st][condition][path]", "Prscrbr_State_Abrvtn"), ("filter[st][condition][operator]", "="),
                ("filter[st][condition][value]", "NY"),
                ("filter[bn][condition][path]", "Brnd_Name"), ("filter[bn][condition][operator]", "IN"),
            ] + [("filter[bn][condition][value][]", b) for b in VACCINE_BRANDS]
            write_csv(fetch_all(BY_PROVIDER_DRUG[year], params), out)
    for year in range(2018, 2025):
        out = OUT / f"by_provider_ny_{year}.csv"
        if force or not out.exists():
            print(f"== by Provider {year} (NY)", flush=True)
            write_csv(fetch_all(BY_PROVIDER[year], [("filter[Prscrbr_State_Abrvtn]", "NY")]), out)
    print("done", flush=True)


if __name__ == "__main__":
    main(force="--force" in sys.argv)
