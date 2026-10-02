#!/usr/bin/env python3
"""Phase A readout: four figures from the NY APD marts to docs/.

Run after `dbt build`:  .venv/bin/python analysis/apd_readout.py
"""
import pathlib, sys
import duckdb, pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mt

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import viz  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
DB = ROOT / "ny_rx_claims.duckdb"
SRC = "Source: NY All-Payer Database prescription PUFs 2018-2023 (health.data.ny.gov), insurer-submitted claims aggregated by NYS DOH."


def q(con, sql):
    return con.execute(sql).df()


def fig_payer_market(con):
    d = q(con, "select year, payer_type, rx_count, total_paid, member_paid_share from main_marts.mart_payer_market order by payer_type, year")
    fig, axes = plt.subplots(1, 3, figsize=(13, 4))
    for payer, g in d.groupby("payer_type"):
        c = viz.PAYER_COLOR[payer]
        axes[0].plot(g.year, g.rx_count / 1e6, marker="o", color=c, label=viz.PAYER_LABEL[payer])
        axes[1].plot(g.year, g.total_paid / 1e9, marker="o", color=c)
        axes[2].plot(g.year, g.member_paid_share, marker="o", color=c)
        for ax, col, fmt in ((axes[0], g.rx_count / 1e6, "{:.1f}M"), (axes[1], g.total_paid / 1e9, "${:.1f}B"), (axes[2], g.member_paid_share, "{:.1%}")):
            viz.direct_label(ax, 2023, col.iloc[-1], fmt.format(col.iloc[-1]), c)
    axes[0].set_title("Prescriptions filled (millions)")
    axes[1].set_title("Total paid (plan + member, $ billions)")
    axes[2].set_title("Member-paid share of total paid")
    viz.pct_axis(axes[2])
    for ax in axes:
        ax.set_xlim(2017.7, 2024.2); ax.set_xticks(range(2018, 2024))
    axes[0].legend(loc="upper left", bbox_to_anchor=(0, -0.12), ncol=3)
    fig.suptitle("NY pharmacy claims by payer segment, 2018-2023", x=0.01, ha="left", fontweight="bold")
    viz.finish(fig, DOCS / "a1_payer_market.png", SRC + " Commercial 2019 drop is a submission break, not a market event.")


def fig_brand_generic(con):
    d = q(con, "select year, drug_category, rx_share, spend_share from main_marts.mart_brand_generic_by_payer where payer_type='COMMERCIAL' order by year")
    cats = [("GENERIC", viz.SERIES[0], "Generic"), ("BRAND", viz.SERIES[1], "Brand"), ("SUPPRESSED", viz.MUTED, "Suppressed (<11 members)")]
    fig, axes = plt.subplots(1, 2, figsize=(11, 4), sharey=True)
    for ax, col, title in ((axes[0], "rx_share", "Share of prescriptions"), (axes[1], "spend_share", "Share of spend")):
        bottom = pd.Series(0.0, index=sorted(d.year.unique()))
        for cat, color, label in cats:
            g = d[d.drug_category == cat].set_index("year")[col].reindex(bottom.index).fillna(0)
            ax.bar(g.index, g.values, bottom=bottom.values, color=color, width=0.7, label=label, edgecolor=viz.SURFACE, linewidth=2)
            for x, (b, v) in enumerate(zip(bottom.values, g.values)):
                if v > 0.08:
                    ax.text(g.index[x], b + v / 2, f"{v:.0%}", ha="center", va="center", fontsize=9, color=viz.SURFACE if cat != "SUPPRESSED" else viz.TEXT)
            bottom = bottom + g
        ax.set_title(title); ax.set_xticks(range(2018, 2024)); ax.set_ylim(0, 1); viz.pct_axis(ax)
    axes[0].legend(loc="upper left", bbox_to_anchor=(0, -0.1), ncol=3)
    fig.suptitle("Commercial segment: generics are 4 of 5 fills but 1 of 8 dollars", x=0.01, ha="left", fontweight="bold")
    viz.finish(fig, DOCS / "a2_commercial_brand_generic.png", SRC + " NDC-9 detail file, drug_category as published.")


def fig_class_oop(con):
    d = q(con, """select therapeutic_class, rx_count, member_paid_share, payer_share_of_class_rx
                  from main_marts.mart_class_by_payer where year = 2023 and payer_type = 'COMMERCIAL'
                  and therapeutic_class not like 'VARIOUS%' order by rx_count desc limit 14""")
    d = d.sort_values("member_paid_share")
    fig, ax = plt.subplots(figsize=(9, 5.5))
    ax.barh(d.therapeutic_class.str.title(), d.member_paid_share, color=viz.SERIES[0], height=0.62)
    for y, (s, rx) in enumerate(zip(d.member_paid_share, d.rx_count)):
        ax.text(s + 0.004, y, f"{s:.1%}  ({rx/1e6:.1f}M Rx)", va="center", fontsize=9, color=viz.TEXT2)
    ax.set_xlim(0, d.member_paid_share.max() * 1.35); ax.xaxis.set_major_formatter(mt.PercentFormatter(1.0, decimals=0)); ax.grid(axis="y", visible=False)
    ax.set_title("Member-paid share of spend by therapeutic class, commercial, 2023 (14 largest classes by fills)")
    viz.finish(fig, DOCS / "a3_commercial_oop_share_by_class.png", SRC + " Shares from summed paid amounts, never from per-claim means.")


def fig_vaccine_oop(con):
    d = q(con, """select year, payer_type, vaccine_group, oop_share, oop_per_fill from main_marts.mart_vaccine_by_payer_year
                  where (vaccine_group = 'shingles' and nonproprietary_name <> 'ZOSTER VACCINE LIVE') or vaccine_group = 'tdap'
                  order by vaccine_group, payer_type, year""")
    fig, axes = plt.subplots(1, 2, figsize=(11, 4), sharey=True)
    for ax, grp, title in ((axes[0], "shingles", "Shingrix (zoster, recombinant)"), (axes[1], "tdap", "Tdap (Boostrix + Adacel)")):
        g0 = d[d.vaccine_group == grp]
        for payer, g in g0.groupby("payer_type"):
            c = viz.PAYER_COLOR[payer]
            ax.plot(g.year, g.oop_share, marker="o", color=c, label=viz.PAYER_LABEL[payer])
            viz.direct_label(ax, 2023, g.oop_share.iloc[-1], f"{g.oop_share.iloc[-1]:.1%}", c)
        ax.set_title(title); ax.set_xticks(range(2018, 2024)); ax.set_xlim(2017.7, 2024.3); viz.pct_axis(ax)
        ax.set_ylim(0, 0.6); viz.shade_post(ax, 2022.5, 2024.3)
    axes[0].set_ylabel("Member-paid share of vaccine spend")
    axes[0].legend(loc="upper left", bbox_to_anchor=(0, -0.1), ncol=3)
    fig.suptitle("Vaccine out-of-pocket share by payer: the Medicare first stage", x=0.01, ha="left", fontweight="bold")
    viz.finish(fig, DOCS / "a4_vaccine_oop_share_by_payer.png", SRC + " Medicare = Part D plans (PDP + MA-PD) covering NY residents.")


def main():
    DOCS.mkdir(exist_ok=True)
    con = duckdb.connect(str(DB), read_only=True)
    fig_payer_market(con); fig_brand_generic(con); fig_class_oop(con); fig_vaccine_oop(con)


if __name__ == "__main__":
    main()
