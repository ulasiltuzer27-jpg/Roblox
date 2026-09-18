"""Rapor grafikleri.

Palet: dataviz referans paletinin ilk dört kategorik yuvası (mavi, turuncu,
aqua, sarı). Doğrulandı -- en kötü komşu çifti CVD ΔE 9.1, normal görüş 22.9.
Kontrast uyarısı taşıyan iki renk için kural gereği doğrudan etiket var.

Bilinçli kararlar:
- Servet eğrisinde log eksen var; çizgi konumla kodladığı için sorun değil.
- Çubuklarda log eksen YOK: çubuk uzunluğu sıfırdan başlayan bir büyüklük
  kodlar, log eksende bu ilişki bozulur ve grafik yalan söyler. Altı
  büyüklük mertebesine yayılan para akışı bu yüzden yüzde olarak çiziliyor.
"""

from __future__ import annotations

from pathlib import Path

SERIES = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100"]
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK_DIM = "#52514e"
GRID = "#e4e3de"
AXIS = "#c9c8c2"


def _style(ax, title: str, xlabel: str, ylabel: str, subtitle: str | None = None) -> None:
    ax.set_facecolor(SURFACE)
    ax.set_title(title, color=INK, fontsize=13, fontweight="bold", loc="left",
                 pad=22 if subtitle else 14)
    if subtitle:
        ax.text(0, 1.02, subtitle, transform=ax.transAxes, color=INK_DIM, fontsize=9.5,
                va="bottom", ha="left")
    ax.set_xlabel(xlabel, color=INK_DIM, fontsize=10)
    ax.set_ylabel(ylabel, color=INK_DIM, fontsize=10)
    ax.tick_params(colors=INK_DIM, labelsize=9, length=0)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color(AXIS)
        ax.spines[side].set_linewidth(0.8)
    ax.grid(axis="y", color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)


def _short(value: float) -> str:
    for limit, suffix in ((1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")):
        if abs(value) >= limit:
            scaled = value / limit
            text = f"{scaled:.1f}".rstrip("0").rstrip(".")
            return f"{text}{suffix}"
    return f"{value:.0f}"


def _net_worth_chart(results, out_dir, plt, FuncFormatter):
    fig, ax = plt.subplots(figsize=(9.5, 5.2), facecolor=SURFACE)
    max_day = max(d["day"] for d in results[0]["median_daily"])

    for index, arch in enumerate(results):
        days = [d["day"] for d in arch["median_daily"]]
        worths = [d["net_worth"] for d in arch["median_daily"]]
        ax.plot(days, worths, color=SERIES[index], linewidth=2, label=arch["label"],
                marker="o", markersize=4, markevery=[len(days) - 1])
        ax.annotate(arch["label"], (days[-1], worths[-1]), xytext=(7, 0),
                    textcoords="offset points", color=INK_DIM, fontsize=9, va="center")

    ax.set_yscale("log")
    ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: _short(v)))
    _style(ax, "Servet eğrisi (ortanca oyuncu)", "Gün", "Servet",
           "Eğrideki düşüşler rebirth sıfırlaması")
    ax.set_xlim(1, max_day * 1.22)
    ax.set_xticks(range(2, max_day + 1, 2))
    ax.legend(frameon=False, labelcolor=INK_DIM, fontsize=9, loc="upper left")
    fig.tight_layout()
    path = out_dir / "01_servet_egrisi.png"
    fig.savefig(path, dpi=140, facecolor=SURFACE)
    plt.close(fig)
    return path


def _rebirth_chart(results, out_dir, plt):
    """Oyun içinde geçen dakika. Takvim saati arketipleri kıyaslanamaz
    kılıyordu: ara sıra giren oyuncunun saatlerinin çoğu çevrimdışı."""
    fig, ax = plt.subplots(figsize=(9.5, 5.2), facecolor=SURFACE)
    count = min(max((len(a["median_rebirth_playtime"]) for a in results), default=0), 6)

    if count:
        width = 0.8 / len(results)
        for index, arch in enumerate(results):
            minutes = arch["median_rebirth_playtime"][:count]
            positions = [i + index * width - 0.4 + width / 2 for i in range(len(minutes))]
            bars = ax.bar(positions, minutes, width=width * 0.86, color=SERIES[index],
                          label=arch["label"], linewidth=0)
            for rect, value in zip(bars, minutes):
                ax.annotate(f"{value:.0f}", (rect.get_x() + rect.get_width() / 2, value),
                            xytext=(0, 3), textcoords="offset points", ha="center",
                            color=INK_DIM, fontsize=8)
        ax.set_xticks(range(count))
        ax.set_xticklabels([f"{i + 1}. rebirth" for i in range(count)])

    _style(ax, "Rebirth temposu", "", "Oyun içinde geçen dakika",
           "Takvim saati değil oynanan süre — arketipler ancak böyle kıyaslanır")
    ax.legend(frameon=False, labelcolor=INK_DIM, fontsize=9)
    fig.tight_layout()
    path = out_dir / "02_rebirth_temposu.png"
    fig.savefig(path, dpi=140, facecolor=SURFACE)
    plt.close(fig)
    return path


def _flow_chart(flows, out_dir, plt):
    """Para akışı, kendi grubunun yüzdesi olarak.

    Mutlak değerler altı büyüklük mertebesine yayılıyor; doğrusal eksende
    küçükler görünmez, log eksende çubuk uzunluğu yalan söyler. Sorunun
    kendisi zaten oransal: "para nereden geliyor, nereye gidiyor?"
    """
    sources = [(name, value) for name, value in flows["rows"] if value >= 0]
    sinks = [(name, -value) for name, value in flows["rows"] if value < 0]
    source_total = sum(v for _, v in sources) or 1
    sink_total = sum(v for _, v in sinks) or 1

    fig, axes = plt.subplots(1, 2, figsize=(11, 4.4), facecolor=SURFACE)

    for ax, rows, total, title, color in (
        (axes[0], sources, source_total, "Para nereden geliyor", SERIES[0]),
        (axes[1], sinks, sink_total, "Para nereye gidiyor", SERIES[1]),
    ):
        rows = sorted(rows, key=lambda r: r[1], reverse=True)
        names = [r[0] for r in rows]
        shares = [r[1] / total * 100 for r in rows]
        bars = ax.barh(names, shares, color=color, linewidth=0, height=0.62)
        for rect, (name, value), share in zip(bars, rows, shares):
            ax.annotate(f"%{share:.1f} · {_short(value)}",
                        (rect.get_width(), rect.get_y() + rect.get_height() / 2),
                        xytext=(6, 0), textcoords="offset points", va="center",
                        color=INK_DIM, fontsize=9)
        ax.invert_yaxis()
        ax.set_xlim(0, 118)
        _style(ax, title, "Grubun yüzdesi", "")
        ax.grid(axis="x", color=GRID, linewidth=0.8)
        ax.grid(axis="y", visible=False)

    fig.suptitle(f"Para akışı — {flows['label']}, {flows['days']} gün",
                 color=INK, fontsize=13, fontweight="bold", x=0.012, ha="left", y=0.99)
    fig.tight_layout(rect=(0, 0, 1, 0.94))
    path = out_dir / "03_para_akisi.png"
    fig.savefig(path, dpi=140, facecolor=SURFACE)
    plt.close(fig)
    return path


def render_all(results: dict, out_dir: Path) -> list[Path]:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.ticker import FuncFormatter

    out_dir.mkdir(parents=True, exist_ok=True)

    # Nadirlik oranları bilerek grafik değil: yedi satırlık bir tablo,
    # çubuk grafiğe çevirmek hiçbir şey eklemiyor. Rapordaki tabloda duruyor.
    return [
        _net_worth_chart(results["archetypes"], out_dir, plt, FuncFormatter),
        _rebirth_chart(results["archetypes"], out_dir, plt),
        _flow_chart(results["flow_reference"], out_dir, plt),
    ]
