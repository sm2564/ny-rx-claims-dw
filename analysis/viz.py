"""Shared plotting conventions for the readouts (matplotlib).

Palette: the validated reference palette (blue, orange, aqua, yellow, magenta, green, violet, red), assigned by
entity in fixed order so a payer or series keeps its color across every figure. Thin marks, direct labels where
they fit, a legend whenever two or more series share a panel, one y-axis per panel, recessive grid.
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

SERIES = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#4a3aa7", "#e34948"]
TEXT, TEXT2, MUTED, GRID, SURFACE = "#0b0b0b", "#52514e", "#8a8984", "#e4e3df", "#fcfcfb"
PAYER_COLOR = {"COMMERCIAL": SERIES[0], "MEDICARE": SERIES[1], "NYS PROGRAMS": SERIES[2]}
PAYER_LABEL = {"COMMERCIAL": "Commercial", "MEDICARE": "Medicare", "NYS PROGRAMS": "NYS Programs (Medicaid)"}

plt.rcParams.update({
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE, "savefig.facecolor": SURFACE,
    "axes.edgecolor": GRID, "axes.labelcolor": TEXT2, "xtick.color": TEXT2, "ytick.color": TEXT2,
    "text.color": TEXT, "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.6,
    "axes.spines.top": False, "axes.spines.right": False, "axes.spines.left": False,
    "axes.axisbelow": True, "font.size": 10, "axes.titlesize": 11, "axes.titleweight": "bold",
    "axes.titlelocation": "left", "legend.frameon": False, "lines.linewidth": 2, "lines.markersize": 6,
    "xtick.major.size": 0, "ytick.major.size": 0,
})


def finish(fig, path, source):
    fig.text(0.01, 0.005, source, fontsize=8, color=MUTED, ha="left", va="bottom")
    fig.savefig(path, dpi=160, bbox_inches="tight")
    plt.close(fig)
    print("wrote", path)


def pct_axis(ax, decimals=0):
    ax.yaxis.set_major_formatter(matplotlib.ticker.PercentFormatter(1.0, decimals=decimals))


def shade_post(ax, start=2022.5, end=None, label="IRA $0 cost sharing (Part D)"):
    end = end if end is not None else ax.get_xlim()[1]
    ax.axvspan(start, end, color=GRID, alpha=0.45, lw=0, zorder=0)
    ax.text(start + 0.05, ax.get_ylim()[1], label, fontsize=8, color=TEXT2, va="top")


def direct_label(ax, x, y, text, color, dx=0.08, **kw):
    ax.annotate(text, (x, y), xytext=(dx, 0), textcoords="offset fontsize", color=color, fontsize=9,
                va="center", ha="left", **kw)
