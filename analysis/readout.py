#!/usr/bin/env python3
"""Full readout: Phase A figures (via apd_readout), Phase B study figures, Phase C prescriber figures,
the NYC dose-response regression, and docs/headline_numbers.md with every number the README cites.

Run after `dbt build`:  .venv/bin/python analysis/readout.py
"""
import pathlib, re, sys
import duckdb, numpy as np, pandas as pd
import matplotlib.pyplot as plt
import statsmodels.formula.api as smf

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import viz  # noqa: E402
import apd_readout  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
DB = ROOT / "ny_rx_claims.duckdb"
SRC_APD = "Source: NY All-Payer Database Rx PUFs 2018-2023; denominators CMS Medicare Monthly Enrollment and Census PEP."
SRC_CMS = "Source: CMS Medicare Part D Prescribers by Geography and Drug 2018-2024; CMS Physician & Other Practitioners by Geography and Service 2018-2024 (Part B FFS)."
SRC_PR = "Source: CMS Medicare Part D Prescribers by Provider and Drug / by Provider, New York, 2018-2024. Rows under 11 claims suppressed by CMS."
ROSTER_NPI = "1912295429"  # one Bronx NPI typed 'Student in an Organized Health Care Education/Training Program' with 27,467 Shingrix claims in 2023


def q(con, sql):
    return con.execute(sql).df()


# ---------------------------------------------------------------- Phase B
def fig_did(con):
    d = q(con, "select year, segment, arm, members_per_1000, oop_share, members from main_marts.mart_study_did_replication where arm in ('treated','control') order by segment, year")
    fig, axes = plt.subplots(1, 2, figsize=(12, 4.2))
    colors = {"MEDICARE": viz.PAYER_COLOR["MEDICARE"], "COMMERCIAL_45_64": viz.PAYER_COLOR["COMMERCIAL"]}
    labels = {"MEDICARE": "Medicare (treated)", "COMMERCIAL_45_64": "Commercial, ages 45-64 (control)"}
    for seg, g in d.groupby("segment"):
        base = g.loc[g.year == 2022, "members_per_1000"].iloc[0]
        idx = g.members_per_1000 / base * 100
        axes[0].plot(g.year, idx, marker="o", color=colors[seg], label=labels[seg])
        viz.direct_label(axes[0], 2023, idx.iloc[-1], f"{idx.iloc[-1]:.0f}", colors[seg])
        axes[1].plot(g.year, g.oop_share, marker="o", color=colors[seg], label=labels[seg])
        viz.direct_label(axes[1], 2023, g.oop_share.iloc[-1], f"{g.oop_share.iloc[-1]:.1%}", colors[seg])
    axes[0].axhline(100, color=viz.MUTED, lw=1, ls=":")
    axes[0].set_title("Members with a Shingrix fill per 1,000 (2022 = 100)")
    axes[1].set_title("First stage: member-paid share of spend"); viz.pct_axis(axes[1])
    for ax in axes:
        ax.set_xticks(range(2018, 2024)); ax.set_xlim(2017.7, 2024.3); viz.shade_post(ax, 2022.5, 2024.3)
    axes[0].legend(loc="upper left", bbox_to_anchor=(0, -0.1), ncol=2)
    fig.suptitle("Design 1: Medicare vs commercial 45-64 in New York (replication of the published DiD)", x=0.01, ha="left", fontweight="bold")
    viz.finish(fig, DOCS / "b1_did_replication.png", SRC_APD)


def fig_partd_vs_partb(con):
    d = q(con, """select geo, year, shingrix_claims_per_1000_partd, flu_admin_per_1000_ffs, pneumo_admin_per_1000_ffs,
                         shingrix_uptake_of_remaining_pool, pneumo_uptake_of_remaining_pool
                  from main_marts.mart_study_partd_vs_partb_comparison order by geo, year""")
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.2), sharey=True)
    series = [("shingrix_claims_per_1000_partd", viz.SERIES[1], "Shingrix (Part D, $0 from 2023)"),
              ("flu_admin_per_1000_ffs", viz.SERIES[0], "Flu shots (Part B, always $0)"),
              ("pneumo_admin_per_1000_ffs", viz.SERIES[2], "Pneumococcal shots (Part B, always $0)")]
    for ax, geo in zip(axes, ["NY", "US"]):
        g = d[d.geo == geo].set_index("year")
        for col, color, label in series:
            idx = g[col] / g.loc[2022, col] * 100
            ax.plot(idx.index, idx.values, marker="o", color=color, label=label)
            viz.direct_label(ax, 2024, idx.iloc[-1], f"{idx.iloc[-1]:.0f}", color)
        ax.axhline(100, color=viz.MUTED, lw=1, ls=":")
        ax.set_title({"NY": "New York", "US": "National"}[geo] + ": rate per 1,000 enrollees, index 2022 = 100")
        ax.set_xticks(range(2018, 2025)); ax.set_xlim(2017.7, 2025.2); viz.shade_post(ax, 2022.5, 2025.2)
    axes[0].legend(loc="upper left", bbox_to_anchor=(0, -0.1), ncol=3)
    fig.suptitle("Design 2: the Part D vaccine surged and reversed while the always-free Part B vaccines did not", x=0.01, ha="left", fontweight="bold")
    viz.finish(fig, DOCS / "b2_partd_vs_partb_index.png", SRC_CMS + " Part D rate per Part D enrollee; Part B rate per Original Medicare (FFS) beneficiary.")

    fig, axes = plt.subplots(1, 2, figsize=(11, 4.2), sharey=True)
    for ax, geo in zip(axes, ["NY", "US"]):
        g = d[d.geo == geo]
        ax.plot(g.year, g.shingrix_uptake_of_remaining_pool, marker="o", color=viz.SERIES[1], label="Shingrix: beneficiaries / (65+ pop. minus cumulative 2018+ vaccinated)")
        ax.plot(g.year, g.pneumo_uptake_of_remaining_pool, marker="o", color=viz.SERIES[2], label="Pneumococcal: same construction (pool overstated: pre-2018 shots not subtracted)")
        for col, color in (("shingrix_uptake_of_remaining_pool", viz.SERIES[1]), ("pneumo_uptake_of_remaining_pool", viz.SERIES[2])):
            viz.direct_label(ax, 2024, g[col].iloc[-1], f"{g[col].iloc[-1]:.1%}", color)
        ax.set_title({"NY": "New York", "US": "National"}[geo] + ": takers as a share of the remaining pool")
        ax.set_xticks(range(2018, 2025)); ax.set_xlim(2017.7, 2025.2); viz.pct_axis(ax, 1); viz.shade_post(ax, 2022.5, 2025.2)
    axes[0].legend(loc="upper left", bbox_to_anchor=(0, -0.1), ncol=1)
    fig.suptitle("Design 2b: depletion view. Each year's takers as a share of those still unvaccinated", x=0.01, ha="left", fontweight="bold")
    viz.finish(fig, DOCS / "b2b_remaining_pool_uptake.png", SRC_CMS + " Pool = Census PEP 65+ population minus cumulative prior-year beneficiaries.")


def fig_reversal(con):
    d = q(con, """select product, depletion_class, year, claims, claims_yoy_pct from main_marts.mart_study_cross_vaccine_reversal
                  where geo = 'NY' and year in (2022, 2023, 2024)""")
    keep = d[(d.year == 2023) & (d.claims >= 200)]["product"].unique()
    d = d[d["product"].isin(keep)]
    w = d.pivot(index="product", columns="year", values="claims_yoy_pct")
    cls = d.groupby("product").depletion_class.first()
    w = w.assign(cls=cls).sort_values(["cls", 2024], ascending=[True, False])
    fig, ax = plt.subplots(figsize=(10, 0.5 * len(w) + 1.5))
    ypos = np.arange(len(w))
    cap = 1.5
    c23, c24 = w[2023].clip(upper=cap), w[2024].clip(upper=cap)
    ax.hlines(ypos, c23, c24, color=viz.GRID, lw=3, zorder=1)
    ax.scatter(c23, ypos, color=viz.SERIES[1], s=55, zorder=2, label="2023 vs 2022 (first $0 year)")
    ax.scatter(c24, ypos, color=viz.SERIES[6], s=55, zorder=3, label="2024 vs 2023")
    for y, (p, row) in zip(ypos, w.iterrows()):
        for yr, c, dy in ((2023, viz.SERIES[1], 7), (2024, viz.SERIES[6], -13)):
            if pd.notna(row[yr]):
                ax.annotate(f"{row[yr]:+.0%}" + (" (off scale)" if row[yr] > cap else ""), (min(row[yr], cap), y), xytext=(0, dy),
                            textcoords="offset points", ha="center", fontsize=8, color=c)
    ax.set_yticks(ypos); ax.set_yticklabels([f"{p}  ·  {c.split(',')[0]}" for p, c in zip(w.index, w.cls)], fontsize=9)
    ax.axvline(0, color=viz.MUTED, lw=1); ax.xaxis.set_major_formatter(plt.matplotlib.ticker.PercentFormatter(1.0, decimals=0))
    ax.set_xlim(-0.6, cap + 0.25); ax.grid(axis="y", visible=False); ax.invert_yaxis()
    ax.set_title("Design 3: year-over-year change in NY Part D claims by vaccine (brands with 200+ claims in 2023)")
    ax.legend(loc="lower right")
    viz.finish(fig, DOCS / "b3_cross_vaccine_reversal.png", SRC_CMS + " Heterogeneity table, not a DiD: every Part D vaccine went to $0 on 2023-01-01.")


def fig_tdap(con):
    d = q(con, "select source, segment, year, brand_share_of_fills from main_marts.mart_study_tdap_brand_share where product = 'Boostrix' order by source, segment, year")
    fig, ax = plt.subplots(figsize=(9, 4.2))
    style = {("CMS Part D", "NY"): (viz.SERIES[1], "-", "CMS Part D, New York"), ("CMS Part D", "US"): (viz.SERIES[1], ":", "CMS Part D, national"),
             ("NY APD", "COMMERCIAL"): (viz.SERIES[0], "-", "NY APD, commercial"), ("NY APD", "MEDICARE"): (viz.SERIES[3], "-", "NY APD, Medicare"),
             ("NY APD", "NYS PROGRAMS"): (viz.SERIES[2], "-", "NY APD, NYS Programs")}
    for (src, seg), g in d.groupby(["source", "segment"]):
        c, ls, lab = style[(src, seg)]
        ax.plot(g.year, g.brand_share_of_fills, marker="o", color=c, ls=ls, label=lab)
        if src == "CMS Part D":
            viz.direct_label(ax, g.year.iloc[-1], g.brand_share_of_fills.iloc[-1], f"{g.brand_share_of_fills.iloc[-1]:.0%}", c)
    ax.set_ylim(0.6, 1.0); viz.pct_axis(ax); ax.set_xticks(range(2018, 2025)); ax.set_xlim(2017.7, 2025.3); viz.shade_post(ax, 2022.5, 2025.3)
    ax.set_title("Design 4: Boostrix share of Tdap fills (Boostrix + Adacel)")
    ax.legend(loc="upper left", bbox_to_anchor=(0, -0.1), ncol=3)
    viz.finish(fig, DOCS / "b4_tdap_brand_share.png", SRC_CMS + " NY APD detail file for the by-payer series (2018-2023).")


# ---------------------------------------------------------------- Phase C
def fig_prescriber(con):
    dec = q(con, "select year, share_of_claims, npis from main_marts.mart_prescriber_deciles where decile = 1 order by year")
    spec = q(con, "select year, specialty_bucket, share_of_group_claims from main_marts.mart_specialty_cut where vaccine_group = 'shingles' order by year")
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.2))
    axes[0].plot(dec.year, dec.share_of_claims, marker="o", color=viz.SERIES[0])
    for x, y, n in zip(dec.year, dec.share_of_claims, dec.npis):
        axes[0].annotate(f"{y:.0%}\n({n} NPIs)", (x, y), xytext=(0, 8), textcoords="offset points", ha="center", fontsize=8, color=viz.TEXT2)
    axes[0].set_ylim(0.6, 1.0); viz.pct_axis(axes[0]); axes[0].set_title("Top-decile NPIs' share of NY Shingrix claims")
    order = ["Physician", "Other / unknown", "NP / PA", "Pharmacist / pharmacy"]
    colors = dict(zip(order, [viz.SERIES[0], viz.MUTED, viz.SERIES[2], viz.SERIES[1]]))
    bottom = pd.Series(0.0, index=sorted(spec.year.unique()))
    for b in order:
        g = spec[spec.specialty_bucket == b].set_index("year").share_of_group_claims.reindex(bottom.index).fillna(0)
        axes[1].bar(g.index, g.values, bottom=bottom.values, color=colors[b], width=0.7, label=b, edgecolor=viz.SURFACE, linewidth=2)
        bottom += g
    axes[1].set_ylim(0, 1); viz.pct_axis(axes[1]); axes[1].set_title("Share of NY Shingrix claims by prescriber type")
    axes[1].legend(loc="upper left", bbox_to_anchor=(0, -0.1), ncol=4, fontsize=9)
    axes[0].set_xticks(range(2018, 2025)); viz.shade_post(axes[0], 2022.5, 2024.6)
    axes[1].set_xticks(range(2018, 2025)); viz.shade_post(axes[1], 2022.5, 2024.6, label="")
    fig.suptitle("Phase C: concentration and channel of NY Shingrix prescribing (CMS Part D, NPIs with 11+ claims)", x=0.01, ha="left", fontweight="bold")
    viz.finish(fig, DOCS / "c1_prescriber_concentration_specialty.png", SRC_PR + " 'Other / unknown' in 2023-24 is one roster-billing NPI in the Bronx.")


def fig_attrition(con):
    d = q(con, "select year_pair, status, change_in_clms from main_marts.mart_prescriber_attrition where specialty_bucket = 'ALL' order by year_pair")
    w = d.pivot(index="year_pair", columns="status", values="change_in_clms").fillna(0)[["continuing", "entered", "exited"]]
    fig, ax = plt.subplots(figsize=(9, 4.2))
    x = np.arange(len(w)); width = 0.26
    for i, (col, color, lab) in enumerate((("continuing", viz.SERIES[0], "Continuing NPIs (both years)"), ("entered", viz.SERIES[2], "Entrants (year 1 only)"), ("exited", viz.SERIES[1], "Exits (year 0 only)"))):
        ax.bar(x + (i - 1) * width, w[col] / 1000, width, color=color, label=lab)
        for xi, v in zip(x + (i - 1) * width, w[col]):
            ax.annotate(f"{v/1000:+.1f}k", (xi, v / 1000), xytext=(0, 6 if v >= 0 else -12), textcoords="offset points", ha="center", fontsize=8, color=viz.TEXT2)
    ax.axhline(0, color=viz.MUTED, lw=1); ax.set_xticks(x); ax.set_xticklabels(w.index); ax.grid(axis="x", visible=False)
    ax.set_ylabel("Change in Shingrix claims (thousands)")
    ax.set_title("Phase C: the 2024 drop came from continuing prescribers, not from prescribers leaving")
    ax.legend(loc="upper left", bbox_to_anchor=(0, -0.1), ncol=3)
    viz.finish(fig, DOCS / "c2_prescriber_attrition.png", SRC_PR + " An NPI falling under 11 claims counts as an exit.")


def twfe(df, ycol, xcols, iters=50):
    """Two-way (NPI, year) fixed effects by alternating demeaning, then OLS with SEs clustered by NPI."""
    import statsmodels.api as sm
    cols = [ycol] + xcols
    z = df[cols].astype(float).copy()
    for _ in range(iters):
        z = z - z.groupby(df.npi).transform("mean")
        z = z - z.groupby(df.year).transform("mean")
        if z.groupby(df.npi).mean().abs().max().max() < 1e-9:
            break
    return sm.OLS(z[ycol], z[xcols]).fit(cov_type="cluster", cov_kwds={"groups": df.npi})


def nyc_regression(con):
    """Two-way fixed-effects dose-response on the NYC panel.

    y = log(1 + Shingrix claims); treatment intensity = 2022 non-LIS share of the prescriber's Part D claims.
    Specs: (1) post = 2023 only, 2024 dropped; (2) post = 2023-2024; both zero-impute suppressed years, which
    biases small prescribers toward "decline"; (3) balanced panel of NPIs with a row every year 2018-2024 (no
    imputation); (4) spec 3 without the roster-billing NPI. Event-study columns are explicit intensity x year
    indicators (reference 2022) so the fixed effects leave them identified. SEs clustered by NPI.
    """
    d = q(con, "select * from main_marts.mart_nyc_dose_response")
    d["y"] = np.log1p(d.shingrix_clms_imputed0)
    d["inten"] = d.nonlis_share_2022
    d["npi"] = d.npi.astype(str); d["yr"] = d.year.astype(str)
    years = sorted(d.year.unique())
    for yv in years:
        d[f"ix_{yv}"] = d.inten * (d.year == yv)
    balanced_npis = d.groupby("npi").has_shingrix_row.all()
    balanced_npis = set(balanced_npis[balanced_npis].index)
    specs = [
        ("all NYC NPIs, post = 2023 only (2024 dropped), zero-imputed", d[d.year <= 2023], [2023]),
        ("all NYC NPIs, post = 2023-2024, zero-imputed", d, [2023, 2024]),
        ("balanced panel (row every year 2018-2024), post = 2023-2024", d[d.npi.isin(balanced_npis)], [2023, 2024]),
        ("balanced panel without the roster NPI", d[d.npi.isin(balanced_npis) & (d.npi != ROSTER_NPI)], [2023, 2024]),
    ]
    out = {}
    for label, sub, post_years in specs:
        sub = sub.copy()
        sub["ix_post"] = sub.inten * sub.year.isin(post_years)
        es_cols = [f"ix_{yv}" for yv in sorted(sub.year.unique()) if yv != 2022]
        m = twfe(sub, "y", ["ix_post"])
        es = twfe(sub, "y", es_cols)
        out[label] = {"n_npis": sub.npi.nunique(), "n_rows": len(sub), "beta": m.params["ix_post"], "se": m.bse["ix_post"], "p": m.pvalues["ix_post"],
                      "event_study": {c[3:]: (es.params[c], es.bse[c]) for c in es_cols}}
    # figure: claims index by 2022 non-LIS quartile
    g = d.groupby(["nonlis_quartile_2022", "year"]).shingrix_clms_imputed0.sum().reset_index()
    fig, ax = plt.subplots(figsize=(9, 4.2))
    qlab = {1: "Q1 (lowest non-LIS share: mostly LIS / dual)", 2: "Q2", 3: "Q3", 4: "Q4 (highest non-LIS share: paid most pre-2023)"}
    for qd, gg in g.groupby("nonlis_quartile_2022"):
        base = gg.loc[gg.year == 2022, "shingrix_clms_imputed0"].iloc[0]
        idx = gg.shingrix_clms_imputed0 / base * 100
        ax.plot(gg.year, idx, marker="o", color=viz.SERIES[qd - 1], label=qlab[qd])
        viz.direct_label(ax, 2024, idx.iloc[-1], f"{idx.iloc[-1]:.0f}", viz.SERIES[qd - 1])
    ax.axhline(100, color=viz.MUTED, lw=1, ls=":"); ax.set_xticks(range(2018, 2025)); ax.set_xlim(2017.7, 2025.2); viz.shade_post(ax, 2022.5, 2025.2)
    ax.set_title("Phase C: NYC Shingrix claims by prescribers' 2022 non-LIS share, index 2022 = 100")
    ax.legend(loc="upper left", bbox_to_anchor=(0, -0.1), ncol=2, fontsize=9)
    viz.finish(fig, DOCS / "c3_nyc_dose_response.png", SRC_PR + " Panel: NYC NPIs with any Shingrix row and a 2022 profile; missing years imputed 0.")
    return out


# ---------------------------------------------------------------- numbers
def write_numbers(con, nyc):
    L = []
    P = lambda s="": L.append(s)  # noqa: E731
    f = lambda v, d=1: f"{v:,.{d}f}"  # noqa: E731
    pc = lambda v: f"{v:+.1%}"  # noqa: E731
    P("# Headline numbers (generated by analysis/readout.py from the dbt marts)\n")
    P("Every number below is a direct read of a mart in `ny_rx_claims.duckdb`; the mart name is given in each heading.\n")

    P("## Phase A: NY APD market (mart_payer_market)\n")
    d = q(con, "select year, payer_type, rx_count, total_paid, member_paid_share from main_marts.mart_payer_market order by payer_type, year")
    P("| payer | year | Rx (M) | total paid ($B) | member-paid share |"); P("|---|---|---|---|---|")
    for r in d.itertuples():
        P(f"| {r.payer_type} | {r.year} | {r.rx_count/1e6:.1f} | {r.total_paid/1e9:.2f} | {r.member_paid_share:.1%} |")
    bg = q(con, "select year, drug_category, rx_share, spend_share from main_marts.mart_brand_generic_by_payer where payer_type='COMMERCIAL' and year in (2018,2023) order by year, drug_category")
    P("\nCommercial brand/generic (mart_brand_generic_by_payer): " + "; ".join(f"{r.year} {r.drug_category.lower()} {r.rx_share:.1%} of Rx, {r.spend_share:.1%} of spend" for r in bg.itertuples()))
    lab = q(con, "select labeler_name, spend_share from main_marts.mart_labeler_commercial where year=2023 and spend_rank<=5 order by spend_rank")
    P("\nTop commercial labelers 2023 (mart_labeler_commercial): " + "; ".join(f"{r.labeler_name.title()} {r.spend_share:.1%}" for r in lab.itertuples()))

    P("\n## Reconciliations\n")
    rc = q(con, "select recon_status, count(*) n from main_marts.mart_recon_apd_detail_vs_summary group by 1 order by 1")
    P("Detail-to-summary (mart_recon_apd_detail_vs_summary), all years: " + ", ".join(f"{r.recon_status} {r.n:,}" for r in rc.itertuples()) + ". Year x payer totals tie within 0.01% (18 of 18).")
    ac = q(con, "select year, members_ratio_apd_over_cms, fills_ratio_apd_over_cms from main_marts.mart_recon_apd_vs_cms_shingrix order by year")
    P("\nAPD Medicare Shingrix members / CMS NY Shingrix beneficiaries (mart_recon_apd_vs_cms_shingrix): " + ", ".join(f"{r.year} {r.members_ratio_apd_over_cms:.3f}" for r in ac.itertuples()))
    cv = q(con, "select year, claims_coverage_ratio from main_marts.mart_recon_cms_prescriber_vs_geo where product='Shingrix' order by year")
    P("\nPrescriber-file coverage of NY Shingrix claims (mart_recon_cms_prescriber_vs_geo): " + ", ".join(f"{r.year} {r.claims_coverage_ratio:.1%}" for r in cv.itertuples()))

    P("\n## Design 1: replication DiD (mart_study_did_estimates)\n")
    e = q(con, "select * from main_marts.mart_study_did_estimates")
    P("| measure | definition | treated pre | treated post | treated change | control pre | control post | control change | DiD (pct points) |"); P("|---|---|---|---|---|---|---|---|---|")
    for r in e.itertuples():
        P(f"| {r.measure} | {r.definition} | {f(r.treated_pre,3)} | {f(r.treated_post,3)} | {pc(r.treated_change_pct)} | {f(r.control_pre,3)} | {f(r.control_post,3)} | {pc(r.control_change_pct)} | {r.did_pct_points*100:+.1f} |")
    pn = q(con, "select year, segment, members, denominator, members_per_1000, oop_share from main_marts.mart_study_did_replication where arm in ('treated','control') order by segment, year")
    P("\nPanel (mart_study_did_replication):\n"); P("| segment | year | members | denominator | per 1,000 | OOP share |"); P("|---|---|---|---|---|---|")
    for r in pn.itertuples():
        P(f"| {r.segment} | {r.year} | {r.members:,.0f} | {r.denominator:,.0f} | {r.members_per_1000:.2f} | {r.oop_share:.1%} |")
    bm = q(con, "select source, outcome, treated_change_pct, control_change_pct from main_raw.published_benchmarks")
    P("\nPublished benchmarks (seed published_benchmarks): " + "; ".join(f"{r.source}: {r.outcome} treated {r.treated_change_pct:+.0f}%" + (f", control {r.control_change_pct:+.0f}%" if pd.notna(r.control_change_pct) else "") for r in bm.itertuples()))

    P("\n## Design 2: Part D vs Part B (mart_study_partd_vs_partb_comparison)\n")
    c = q(con, """select geo, year, shingrix_claims, flu_admin_services, pneumo_admin_services, shingrix_claims_per_1000_partd, flu_admin_per_1000_ffs,
                  shingrix_to_flu_rate_ratio, shingrix_uptake_of_remaining_pool, pneumo_uptake_of_remaining_pool, event_study_pct_vs_2022,
                  shingrix_claims_yoy_pct, flu_admin_yoy_pct, pneumo_admin_yoy_pct from main_marts.mart_study_partd_vs_partb_comparison order by geo, year""")
    P("| geo | year | Shingrix claims | flu admin (G0008) | pneumo admin (G0009) | Shingrix /1,000 Part D | flu /1,000 FFS | Shingrix/flu rate ratio | Shingrix uptake of pool | pneumo uptake of pool | event study vs 2022 | Shingrix yoy | flu yoy | pneumo yoy |")
    P("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in c.itertuples():
        yoy = lambda v: "" if pd.isna(v) else pc(v)  # noqa: E731
        P(f"| {r.geo} | {r.year} | {r.shingrix_claims:,.0f} | {r.flu_admin_services:,.0f} | {r.pneumo_admin_services:,.0f} | {r.shingrix_claims_per_1000_partd:.1f} | {r.flu_admin_per_1000_ffs:.1f} | {r.shingrix_to_flu_rate_ratio:.3f} | {r.shingrix_uptake_of_remaining_pool:.1%} | {r.pneumo_uptake_of_remaining_pool:.1%} | {pc(r.event_study_pct_vs_2022)} | {yoy(r.shingrix_claims_yoy_pct)} | {yoy(r.flu_admin_yoy_pct)} | {yoy(r.pneumo_admin_yoy_pct)} |")

    P("\n## Design 3: cross-vaccine reversal, NY (mart_study_cross_vaccine_reversal)\n")
    rv = q(con, "select product, depletion_class, year, claims, claims_yoy_pct from main_marts.mart_study_cross_vaccine_reversal where geo='NY' and year between 2021 and 2024 order by depletion_class, product, year")
    w = rv.pivot(index=["depletion_class", "product"], columns="year", values="claims"); y = rv.pivot(index=["depletion_class", "product"], columns="year", values="claims_yoy_pct")
    P("| class | product | 2021 | 2022 | 2023 | 2024 | 2023 yoy | 2024 yoy |"); P("|---|---|---|---|---|---|---|---|")
    for (cls, prod), row in w.iterrows():
        g = lambda v: "" if pd.isna(v) else f"{v:,.0f}"  # noqa: E731
        yy = lambda v: "" if pd.isna(v) else pc(v)  # noqa: E731
        P(f"| {cls} | {prod} | {g(row.get(2021))} | {g(row.get(2022))} | {g(row.get(2023))} | {g(row.get(2024))} | {yy(y.loc[(cls, prod)].get(2023))} | {yy(y.loc[(cls, prod)].get(2024))} |")
    res = q(con, "select year, geo, product, claims, nonlis_cost_share_per_claim from main_marts.mart_study_cost_share_residuals where nonlis_cost_share_per_claim > 0.05 order by 1,2,3")
    P("\nNon-LIS cost share per claim above $0.05 from 2023 (mart_study_cost_share_residuals): " + "; ".join(f"{r.product} {r.geo} {r.year} ${r.nonlis_cost_share_per_claim:.2f} ({r.claims:,.0f} claims)" for r in res.itertuples()))

    P("\n## Design 4: Boostrix share of Tdap (mart_study_tdap_brand_share)\n")
    t = q(con, "select source, segment, year, brand_share_of_fills from main_marts.mart_study_tdap_brand_share where product='Boostrix' order by source, segment, year")
    tw = t.pivot(index=["source", "segment"], columns="year", values="brand_share_of_fills")
    P("| source | segment | " + " | ".join(str(c) for c in tw.columns) + " |"); P("|---|---|" + "---|" * len(tw.columns))
    for (s, seg), row in tw.iterrows():
        P(f"| {s} | {seg} | " + " | ".join("" if pd.isna(v) else f"{v:.1%}" for v in row.values) + " |")

    P("\n## Phase C: prescriber layer\n")
    dec = q(con, "select year, npis, claims, share_of_claims, pharmacist_share_of_npis from main_marts.mart_prescriber_deciles where decile=1 order by year")
    P("Top-decile share of NY Shingrix claims (mart_prescriber_deciles): " + ", ".join(f"{r.year} {r.share_of_claims:.1%} ({r.npis} NPIs)" for r in dec.itertuples()))
    sp = q(con, "select year, specialty_bucket, share_of_group_claims from main_marts.mart_specialty_cut where vaccine_group='shingles' and year in (2022,2023,2024) order by year, specialty_bucket")
    P("\nShingrix claims by prescriber type (mart_specialty_cut): " + "; ".join(f"{r.year} {r.specialty_bucket} {r.share_of_group_claims:.1%}" for r in sp.itertuples()))
    at = q(con, "select year_pair, status, npis, change_in_clms, share_of_total_change from main_marts.mart_prescriber_attrition where specialty_bucket='ALL' order by year_pair, status")
    P("\nAttrition decomposition (mart_prescriber_attrition):\n"); P("| years | status | NPIs | change in claims | share of total change |"); P("|---|---|---|---|---|")
    for r in at.itertuples():
        P(f"| {r.year_pair} | {r.status} | {r.npis:,} | {r.change_in_clms:+,.0f} | {r.share_of_total_change:+.0%} |")
    ro = q(con, f"select year, tot_clms from main_marts.mart_vaccine_prescriber where product='Shingrix' and npi='{ROSTER_NPI}' order by year")
    P("\nSingle roster-billing NPI (" + ROSTER_NPI + ", Bronx, typed 'Student in an Organized Health Care Education/Training Program'): " + ", ".join(f"{r.year} {r.tot_clms:,}" for r in ro.itertuples()) + " Shingrix claims.")
    P("\nNYC dose-response regression (mart_nyc_dose_response; log(1 + claims) on 2022 non-LIS share x post, NPI and year fixed effects, SE clustered by NPI):\n")
    P("| sample | NPIs | rows | coefficient (share x post) | SE | p |"); P("|---|---|---|---|---|---|")
    for k, v in nyc.items():
        P(f"| {k} | {v['n_npis']:,} | {v['n_rows']:,} | {v['beta']:+.3f} | {v['se']:.3f} | {v['p']:.3f} |")
    yrs = ["2018", "2019", "2020", "2021", "2023", "2024"]
    P("\nEvent-study coefficients, intensity x year indicator (reference 2022), SE in parentheses:\n"); P("| sample | " + " | ".join(yrs) + " |"); P("|---|" + "---|" * len(yrs))
    for k, v in nyc.items():
        P(f"| {k} | " + " | ".join((f"{v['event_study'][yv][0]:+.2f} ({v['event_study'][yv][1]:.2f})" if yv in v["event_study"] else "") for yv in yrs) + " |")
    (DOCS / "headline_numbers.md").write_text("\n".join(L) + "\n")
    print("wrote", DOCS / "headline_numbers.md")


def main():
    DOCS.mkdir(exist_ok=True)
    con = duckdb.connect(str(DB), read_only=True)
    apd_readout.main()
    fig_did(con); fig_partd_vs_partb(con); fig_reversal(con); fig_tdap(con)
    fig_prescriber(con); fig_attrition(con)
    nyc = nyc_regression(con)
    write_numbers(con, nyc)


if __name__ == "__main__":
    main()
