#!/usr/bin/env python3
"""Build seeds/ny_denominators.csv: population and enrollment denominators for New York (NY) and the US, 2018-2024.

Sources (no API key needed)
- Census Population Estimates Program (PEP), state single-year-of-age by sex, civilian population:
    2010-2020 vintage 2020: SC-EST2020-AGESEX-CIV.csv (POPEST2018_CIV, POPEST2019_CIV, POPEST2020_CIV)
    2020-2024 vintage 2024: sc-est2024-agesex-civ.csv (POPEST2021_CIV .. POPEST2024_CIV; 2020 taken from this vintage)
  -> pop_total, pop_45_64, pop_50_plus, pop_60_plus, pop_65_plus
- CMS Medicare Monthly Enrollment (data.cms.gov dataset d7fabe1e-d19b-4333-9eff-e80e0643f2fd), MONTH='Year' rows:
  -> medicare_total_benes, medicare_benes_65_plus, medicare_ma_benes, partd_enrollees, partd_pdp, partd_mapd, partd_lis, partd_no_lis
Optional (needs CENSUS_API_KEY in the environment; the Census API now rejects keyless requests):
- ACS 1-year B27004 (employer-based insurance by age) -> employer_ins_45_64; B27006 -> medicare_cov_65_plus.
Output columns: geo, year, measure, value, source, note
"""
import csv, io, os, pathlib, sys, time, requests

OUT = pathlib.Path(__file__).resolve().parents[1] / "seeds" / "ny_denominators.csv"
PEP_2020 = "https://www2.census.gov/programs-surveys/popest/datasets/2010-2020/state/asrh/SC-EST2020-AGESEX-CIV.csv"
PEP_2024 = "https://www2.census.gov/programs-surveys/popest/datasets/2020-2024/state/asrh/sc-est2024-agesex-civ.csv"
CMS_ENROLL = "d7fabe1e-d19b-4333-9eff-e80e0643f2fd"


def get(url, params=None, tries=5, as_json=True):
    for i in range(tries):
        try:
            r = requests.get(url, params=params, timeout=300)
            r.raise_for_status()
            return r.json() if as_json else r.text
        except Exception as e:  # noqa: BLE001
            print(f"retry {i+1} {url}: {e}", file=sys.stderr)
            time.sleep(5 * (i + 1))
    raise RuntimeError(url)


def pep_rows(url, years):
    """Return {(geo, year, measure): value} from a PEP agesex-civ file. SEX=0 both sexes; AGE 0..85, 999 total."""
    text = get(url, as_json=False)
    rdr = csv.DictReader(io.StringIO(text))
    acc = {}
    for r in rdr:
        if r["SEX"] != "0":
            continue
        if r["SUMLEV"] == "010":
            geo = "US"
        elif r["SUMLEV"] == "040" and r["NAME"] == "New York":
            geo = "NY"
        else:
            continue
        age = int(r["AGE"])
        for y in years:
            v = int(r[f"POPEST{y}_CIV"])
            key = (geo, y)
            a = acc.setdefault(key, {"pop_total": 0, "pop_45_64": 0, "pop_50_plus": 0, "pop_60_plus": 0, "pop_65_plus": 0})
            if age == 999:
                a["pop_total"] += v
            else:
                if 45 <= age <= 64: a["pop_45_64"] += v
                if age >= 50: a["pop_50_plus"] += v
                if age >= 60: a["pop_60_plus"] += v
                if age >= 65: a["pop_65_plus"] += v
    return acc


def cms_enrollment(geo):
    params = [("size", 100), ("filter[MONTH]", "Year")]
    if geo == "NY":
        params += [("filter[BENE_GEO_LVL]", "State"), ("filter[BENE_STATE_DESC]", "New York")]
    else:
        params += [("filter[BENE_GEO_LVL]", "National")]
    rows = get(f"https://data.cms.gov/data-api/v1/dataset/{CMS_ENROLL}/data", params)
    out, src = [], "CMS Medicare Monthly Enrollment, MONTH=Year"
    for r in rows:
        y = int(r["YEAR"])
        if not 2018 <= y <= 2024:
            continue
        i = lambda k: int(r[k]) if r.get(k) not in (None, "", "*") else None  # noqa: E731
        lis = sum(x for x in [i("PRSCRPTN_DRUG_DEEMED_ELIGIBLE_FULL_LIS_BENES"), i("PRSCRPTN_DRUG_FULL_LIS_BENES"), i("PRSCRPTN_DRUG_PARTIAL_LIS_BENES")] if x is not None)
        aged65 = sum(x for x in [i(k) for k in ["AGE_65_TO_69_BENES", "AGE_70_TO_74_BENES", "AGE_75_TO_79_BENES", "AGE_80_TO_84_BENES", "AGE_85_TO_89_BENES", "AGE_90_TO_94_BENES", "AGE_GT_94_BENES"]] if x is not None)
        out += [
            (geo, y, "medicare_total_benes", i("TOT_BENES"), src, ""),
            (geo, y, "medicare_benes_65_plus", aged65, src, "sum of AGE_65_TO_69 .. AGE_GT_94"),
            (geo, y, "medicare_ma_benes", i("MA_AND_OTH_BENES"), src, ""),
            (geo, y, "partd_enrollees", i("PRSCRPTN_DRUG_TOT_BENES"), src, "PDP + MA-PD enrollees"),
            (geo, y, "partd_pdp", i("PRSCRPTN_DRUG_PDP_BENES"), src, ""),
            (geo, y, "partd_mapd", i("PRSCRPTN_DRUG_MAPD_BENES"), src, ""),
            (geo, y, "partd_lis", lis, src, "deemed + full + partial LIS"),
            (geo, y, "partd_no_lis", i("PRSCRPTN_DRUG_NO_LIS_BENES"), src, ""),
        ]
    return out


def acs_optional(key):
    """ACS 1-year employer-based insurance 45-64 and Medicare coverage 65+, when a Census API key is available."""
    emp = ["019", "022", "047", "050"]; mdc = ["025", "028", "053", "056"]
    vars_ = [f"B27004_{s}E" for s in emp] + [f"B27006_{s}E" for s in mdc]
    out = []
    for geo, where in (("NY", {"for": "state:36"}), ("US", {"for": "us:1"})):
        for y in [2018, 2019, 2021, 2022, 2023, 2024]:
            data = get(f"https://api.census.gov/data/{y}/acs/acs1", {"get": ",".join(vars_), "key": key, **where})
            row = dict(zip(data[0], data[1]))
            src = f"ACS 1-year {y}"
            out.append((geo, y, "employer_ins_45_64", sum(int(row[f"B27004_{s}E"]) for s in emp), src, "B27004 with employer-based insurance, ages 45-64"))
            out.append((geo, y, "medicare_cov_65_plus", sum(int(row[f"B27006_{s}E"]) for s in mdc), src, "B27006 with Medicare coverage, ages 65+"))
    return out


def main():
    rows = []
    print("PEP 2010-2020 vintage", flush=True)
    p20 = pep_rows(PEP_2020, [2018, 2019])
    print("PEP 2020-2024 vintage", flush=True)
    p24 = pep_rows(PEP_2024, [2020, 2021, 2022, 2023, 2024])
    for acc, src in ((p20, "Census PEP vintage 2020, SC-EST2020-AGESEX-CIV"), (p24, "Census PEP vintage 2024, sc-est2024-agesex-civ")):
        for (geo, y), m in acc.items():
            for k, v in m.items():
                rows.append((geo, y, k, v, src, "civilian population, July 1 estimate"))
    for geo in ("NY", "US"):
        print(f"CMS enrollment {geo}", flush=True)
        rows += cms_enrollment(geo)
    key = os.environ.get("CENSUS_API_KEY")
    if key:
        print("ACS (key present)", flush=True)
        rows += acs_optional(key)
    else:
        print("ACS skipped: set CENSUS_API_KEY to add employer_ins_45_64 and medicare_cov_65_plus", flush=True)
    rows.sort(key=lambda r: (r[0], r[2], r[1]))
    with open(OUT, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["geo", "year", "measure", "value", "source", "note"])
        w.writerows(rows)
    print(f"wrote {OUT} ({len(rows)} rows)")


if __name__ == "__main__":
    main()
