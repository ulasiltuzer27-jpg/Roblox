#!/usr/bin/env python3
"""Vault Heist ekonomi simülasyonu.

Oyunun kendi denge dosyalarını (build/config.json) okur ve dört oyuncu
arketipini Monte Carlo ile koşturur. Amaç tek bir soru: bu sayılarla oyuncu
ilk saatinde, ilk gününde ve ilk haftasında nerede oluyor?

    ./scripts/sim.sh                     tam rapor + grafikler
    ./scripts/sim.sh --no-charts         sadece metin
    ./scripts/sim.sh --runs 200 --days 14
    ./scripts/sim.sh --self-check        model ile oyunun matematiğini karşılaştır
"""

from __future__ import annotations

import argparse
import json
import math
import random
import statistics
import sys
from pathlib import Path

from archetypes import ARCHETYPES
from engine import TARGET_STASH_SECONDS, simulate, steal_share
from model import Config

# Dengede "bir bakayım" dedirtmesi gereken eşikler. Rapor bunları ihlal
# ederse uyarı basıyor -- sayıya bakıp gözden kaçırmayı önlüyor.
GUARDRAILS = {
    "first_rebirth_hours_min": 0.15,
    "first_rebirth_hours_max": 1.5,
    "day7_rebirths_min": 3,
    # Soygun gelirinin payı. Aktif oynamanın idle'dan iyi olması doğru;
    # ama bu oran çok yükselirse kimse kasa kurmaz ve kapalı ekonomide
    # çalacak bir şey kalmaz. Simülasyon bu dengeyi tek başına çözemez
    # (sonsuz dolu hedef varsayıyor), bu yüzden eşik bir uyarı sınırı.
    "heist_share_of_income_max": 0.6,
    # Çevrimiçi kaynaklar (pasif üretim + soygun) gelirin en az bu kadarı
    # olmalı; aksi halde en verimli strateji "gir, topla, çık".
    "online_income_share_min": 0.25,
    # Bölge çarpanıyla ölçeklenmiş geri ödeme: oyuncunun gerçekten
    # hissettiği süre. Ham değer geç oyun sandıklarında yanıltıcı.
    "crate_payback_seconds_max": 2700,
    # Son bölgenin açılması bu günden önce olursa içerik çok çabuk tükeniyor.
    "last_zone_day_min": 5,
    # Sandık alıp hazineyi satmak kâr ettirmemeli.
    "sell_flip_ratio_max": 0.6,
}


def short(value: float) -> str:
    if value is None:
        return "-"
    for limit, suffix in ((1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")):
        if abs(value) >= limit:
            scaled = value / limit
            text = f"{scaled:.2f}".rstrip("0").rstrip(".")
            return f"{text}{suffix}"
    return f"{value:.0f}"


def duration(hours: float | None) -> str:
    if hours is None:
        return "ulaşamadı"
    if hours < 1:
        return f"{hours * 60:.0f} dk"
    if hours < 48:
        return f"{hours:.1f} saat"
    return f"{hours / 24:.1f} gün"


# --------------------------------------------------------------------------
# Analitik tablolar (simülasyona gerek olmayan, doğrudan config'ten çıkanlar)
# --------------------------------------------------------------------------


def expected_mutation_multiplier(cfg: Config) -> float:
    return sum(
        cfg.mutation_chance(m["id"], 1.0) * m["multiplier"] for m in cfg.mutation_list
    )


def expected_crate_income(cfg: Config, crate_id: str, luck: float = 1.0) -> float:
    rarity_part = sum(
        cfg.rarity_chance(crate_id, r["id"], luck) * r["baseIncome"] for r in cfg.rarity_list
    )
    return rarity_part * expected_mutation_multiplier(cfg)


def crate_table(cfg: Config) -> list[dict]:
    rows = []
    for crate in cfg.crate_list:
        income = expected_crate_income(cfg, crate["id"])
        zone = cfg.zones[crate["zone"]]
        zone_multiplier = (1 + zone["incomeBonus"]) * cfg.rebirth_multiplier(
            zone["requiredRebirths"]
        )
        payback = crate["cost"] / income if crate["currency"] == "coins" and income > 0 else None
        rows.append(
            {
                "name": crate["name"],
                "cost": crate["cost"],
                "currency": crate["currency"],
                "income": income,
                "payback": payback,
                "payback_scaled": payback / zone_multiplier if payback else None,
            }
        )
    return rows


def rarity_odds(cfg: Config, crate_id: str, luck: float = 1.0) -> list[tuple[str, float]]:
    rows = []
    for rarity in cfg.rarity_list:
        chance = cfg.rarity_chance(crate_id, rarity["id"], luck)
        if chance > 0:
            rows.append((rarity["name"], 1 / chance))
    return rows


# --------------------------------------------------------------------------
# Kendi kendini doğrulama
# --------------------------------------------------------------------------


def self_check(cfg: Config) -> int:
    """Python modelinin oyunun matematiğiyle aynı sonucu verdiğini doğrular."""
    failures = []

    for crate in cfg.crate_list:
        total = sum(cfg.rarity_chance(crate["id"], r["id"], 1.0) for r in cfg.rarity_list)
        if abs(total - 1) > 1e-9:
            failures.append(f"{crate['name']}: nadirlik ihtimalleri toplamı {total}")

    total_mutation = sum(cfg.mutation_chance(m["id"], 1.0) for m in cfg.mutation_list)
    if abs(total_mutation - 1) > 1e-9:
        failures.append(f"mutasyon ihtimalleri toplamı {total_mutation}")

    prism = cfg.mutation_chance("prism", 1.0)
    if abs(prism - 0.0002) > 1e-9:
        failures.append(f"Prizma şansı {prism}, beklenen 0.0002")

    # Şans yalnızca Nadir ve üstünü bükmeli
    base = cfg.rarity_weights("iron", 1.0)
    lucky = cfg.rarity_weights("iron", 3.0)
    if abs(base["common"] - lucky["common"]) > 1e-9:
        failures.append("şans çarpanı Sıradan ağırlığını değiştiriyor")
    if lucky["legendary"] <= base["legendary"]:
        failures.append("şans çarpanı Efsanevi ağırlığını artırmıyor")

    # Çalınan pay tavanı
    share = steal_share(cfg, carry_level=0, defense_score=1e9, owner_online=True, perfect=False)
    expected = cfg.balance["Heist"]["baseStealShare"] * (
        1 - cfg.balance["Heist"]["defenseShareCap"]
    )
    if abs(share - expected) > 1e-9:
        failures.append(f"savunma direnci tavanı: {share} != {expected}")

    if failures:
        print("MODEL DOĞRULAMASI BAŞARISIZ")
        for failure in failures:
            print(f"  ✗ {failure}")
        return 1

    print("Model doğrulaması tamam: loot, şans ve soygun matematiği oyunla aynı.")
    return 0


# --------------------------------------------------------------------------
# Simülasyon
# --------------------------------------------------------------------------


def run_archetype(cfg: Config, policy, runs: int, days: int, seed: int) -> dict:
    daily_by_day = [[] for _ in range(days)]
    rebirth_hours = []
    rebirth_playtimes = []
    first_rebirths = []
    first_playtimes = []
    flows_total = {}
    crates_total = []
    rarity_totals = {}

    for run in range(runs):
        rng = random.Random(seed + run * 7919)
        result = simulate(cfg, policy, days, rng)
        player = result["player"]

        for index, day in enumerate(result["daily"]):
            daily_by_day[index].append(day)

        rebirth_hours.append(result["rebirth_hours"])
        rebirth_playtimes.append(result["rebirth_playtime_minutes"])
        first_rebirths.append(result["first_rebirth_hours"])
        first_playtimes.append(result["first_rebirth_playtime_minutes"])
        crates_total.append(player.crates_opened)

        for key, value in vars(player.flows).items():
            flows_total[key] = flows_total.get(key, 0.0) + value
        for rarity_id, count in player.rarity_counts.items():
            rarity_totals[rarity_id] = rarity_totals.get(rarity_id, 0) + count

    def median_of(day_index: int, key: str) -> float:
        return statistics.median(d[key] for d in daily_by_day[day_index])

    median_daily = [
        {
            "day": index + 1,
            "net_worth": median_of(index, "net_worth"),
            "rate": median_of(index, "rate"),
            "rebirths": median_of(index, "rebirths"),
            "crates": median_of(index, "crates"),
        }
        for index in range(days)
    ]

    # n'inci rebirth'e kaç saatte ulaşıldığının ortancası
    max_rebirths = max((len(h) for h in rebirth_hours), default=0)
    median_rebirth_hours = []
    for index in range(max_rebirths):
        reached = [h[index] for h in rebirth_hours if len(h) > index]
        if len(reached) >= runs / 2:
            median_rebirth_hours.append(statistics.median(reached))

    reached_first = [h for h in first_rebirths if h is not None]
    reached_playtime = [m for m in first_playtimes if m is not None]

    max_rb = max((len(p) for p in rebirth_playtimes), default=0)
    median_rebirth_playtime = []
    for index in range(max_rb):
        got = [p[index] for p in rebirth_playtimes if len(p) > index]
        if len(got) >= runs / 2:
            median_rebirth_playtime.append(statistics.median(got))

    return {
        "name": policy.name,
        "label": policy.label,
        "policy": policy,
        "median_daily": median_daily,
        "median_rebirth_hours": median_rebirth_hours,
        "first_rebirth_median": statistics.median(reached_first) if reached_first else None,
        "first_rebirth_p25": (
            statistics.quantiles(reached_first, n=4)[0] if len(reached_first) >= 4 else None
        ),
        "first_rebirth_p75": (
            statistics.quantiles(reached_first, n=4)[2] if len(reached_first) >= 4 else None
        ),
        "first_rebirth_reached_ratio": len(reached_first) / runs,
        "first_rebirth_playtime_median": (
            statistics.median(reached_playtime) if reached_playtime else None
        ),
        "median_rebirth_playtime": median_rebirth_playtime,
        "flows": {key: value / runs for key, value in flows_total.items()},
        "crates_median": statistics.median(crates_total),
        "rarity_totals": {key: value / runs for key, value in rarity_totals.items()},
    }


# --------------------------------------------------------------------------
# Rapor
# --------------------------------------------------------------------------


def build_report(cfg: Config, results: list[dict], runs: int, days: int) -> tuple[str, list[str]]:
    lines = []
    warnings = []

    def out(text: str = "") -> None:
        lines.append(text)

    out(f"# Ekonomi Simülasyonu Raporu")
    out()
    out(f"{runs} koşu × {days} gün, arketip başına. Sayılar ortanca oyuncu.")
    out()

    # --- sandıklar ---
    out("## Sandık beklenen değerleri")
    out()
    out("| Sandık | Fiyat | Beklenen gelir/sn | Geri ödeme | Bölge çarpanıyla |")
    out("|---|---|---|---|---|")
    for row in crate_table(cfg):
        cost = f"{row['cost']} jeton" if row["currency"] == "tokens" else short(row["cost"])
        payback = f"{row['payback'] / 60:.1f} dk" if row["payback"] else "-"
        scaled = f"{row['payback_scaled'] / 60:.1f} dk" if row["payback_scaled"] else "-"
        out(f"| {row['name']} | {cost} | {short(row['income'])} | {payback} | {scaled} |")
        scaled = row["payback_scaled"]
        if scaled and scaled > GUARDRAILS["crate_payback_seconds_max"]:
            warnings.append(
                f"{row['name']}: o bölgeye ulaşan oyuncu için bile {scaled / 60:.0f} dakikada "
                f"kendini ödüyor (eşik {GUARDRAILS['crate_payback_seconds_max'] / 60:.0f} dk)"
            )
    out()
    out(f"Beklenen mutasyon çarpanı: **x{expected_mutation_multiplier(cfg):.3f}**")
    out()

    # --- nadirlik ---
    out("## Nadirlik oranları (Demir Sandık, şans x1)")
    out()
    out("| Nadirlik | Kaç sandıkta bir |")
    out("|---|---|")
    for name, per in rarity_odds(cfg, "iron"):
        out(f"| {name} | 1 / {short(per)} |")
    out()

    # --- arketipler ---
    out("## Arketipler")
    out()
    out("| Arketip | Günlük süre | İlk rebirth (oyun içi) | İlk rebirth (takvim) | 7. gün geliri | 7. gün rebirth |")
    out("|---|---|---|---|---|---|")
    for result in results:
        policy = result["policy"]
        daily = result["median_daily"]
        day7 = daily[min(6, len(daily) - 1)]
        playtime = result["first_rebirth_playtime_median"]
        out(
            f"| {result['label']} | {policy.online_seconds_per_day / 60:.0f} dk | "
            f"{f'{playtime:.0f} dk' if playtime else '-'} | "
            f"{duration(result['first_rebirth_median'])} | "
            f"{short(day7['rate'])}/sn | {day7['rebirths']:.0f} |"
        )

        median_first = result["first_rebirth_playtime_median"]
        median_first = median_first / 60 if median_first is not None else None
        if median_first is not None:
            if median_first < GUARDRAILS["first_rebirth_hours_min"]:
                warnings.append(
                    f"{result['label']}: ilk rebirth {duration(median_first)} — çok hızlı, "
                    "oyuncu temel döngüyü görmeden rebirth yapıyor"
                )
            elif median_first > GUARDRAILS["first_rebirth_hours_max"]:
                warnings.append(
                    f"{result['label']}: ilk rebirth {duration(median_first)} — çok yavaş, "
                    "ilk oturumda ilerleme hissi yok"
                )
        else:
            warnings.append(f"{result['label']}: {days} günde ilk rebirth'e hiç ulaşamadı")

        if day7["rebirths"] < GUARDRAILS["day7_rebirths_min"] and policy.name in ("core", "grinder"):
            warnings.append(
                f"{result['label']}: 7. günde yalnızca {day7['rebirths']:.0f} rebirth — "
                "ilerleme duvara toslamış olabilir"
            )
    out()

    out("İlk rebirth, takvim saati olarak (alt çeyrek / ortanca / üst çeyrek):")
    out()
    for result in results:
        out(
            f"- **{result['label']}**: {duration(result['first_rebirth_p25'])} / "
            f"{duration(result['first_rebirth_median'])} / {duration(result['first_rebirth_p75'])}"
        )
    out()

    out("Rebirth temposu (oyun içinde geçen dakika):")
    out()
    for result in results:
        pace = result["median_rebirth_playtime"][:5]
        if pace:
            out(f"- **{result['label']}**: " + " → ".join(f"{m:.0f} dk" for m in pace))
        else:
            out(f"- **{result['label']}**: rebirth'e ulaşamadı")
    out()

    # --- para akışı ---
    out("## Para akışı")
    out()
    out(f"Arketip başına {days} günlük toplam (ortalama koşu).")
    out()
    out("| Arketip | Pasif | Çevrimdışı | Soygun kazancı | Soygun kaybı | Hazine satışı | Sandık | Yükseltme | Savunma |")
    out("|---|---|---|---|---|---|---|---|---|")
    for result in results:
        flows = result["flows"]
        out(
            f"| {result['label']} | {short(flows['passive_income'])} | "
            f"{short(flows['offline_income'])} | {short(flows['heist_gain'])} | "
            f"−{short(flows['heist_loss'])} | {short(flows['treasure_sales'])} | "
            f"−{short(flows['crate_spend'])} | −{short(flows['upgrade_spend'])} | "
            f"−{short(flows['defense_spend'])} |"
        )

        total_in = flows["passive_income"] + flows["offline_income"] + flows["heist_gain"] + flows["treasure_sales"]
        if total_in > 0:
            heist_share = flows["heist_gain"] / total_in
            if heist_share > GUARDRAILS["heist_share_of_income_max"]:
                warnings.append(
                    f"{result['label']}: gelirin %{heist_share * 100:.0f}'i soygundan geliyor — "
                    "kasa kurmak anlamsızlaşıyor"
                )

            # Ara sıra giren oyuncunun gelirinin çoğu doğal olarak
            # çevrimdışından gelir; ölçüt bağlanan oyuncular için.
            online_share = (flows["passive_income"] + flows["heist_gain"]) / total_in
            if online_share < GUARDRAILS["online_income_share_min"] and result["name"] != "casual":
                warnings.append(
                    f"{result['label']}: gelirin yalnızca %{online_share * 100:.0f}'i oyundayken "
                    "kazanılıyor — en verimli strateji \"gir, topla, çık\" oluyor"
                )
    out()

    # --- içerik tüketimi ---
    last_zone = max(cfg.raw["zones"], key=lambda z: z["requiredRebirths"])
    out("## İçerik tüketimi")
    out()
    out(f"Son bölge (**{last_zone['name']}**) {last_zone['requiredRebirths']} rebirth istiyor.")
    out()
    out("| Arketip | Son bölgenin açıldığı gün |")
    out("|---|---|")
    for result in results:
        day = None
        for entry in result["median_daily"]:
            if entry["rebirths"] >= last_zone["requiredRebirths"]:
                day = entry["day"]
                break
        out(f"| {result['label']} | {day if day else f'{days}+ gün'} |")
        if day is not None and day < GUARDRAILS["last_zone_day_min"] and result["name"] != "casual":
            warnings.append(
                f"{result['label']}: son bölge {day}. günde açılıyor — "
                "haftalık güncelleme temposu buna yetişemez, bölge eşikleri artırılmalı "
                "ya da yeni bölge eklenmeli"
            )
    out()

    # --- al-sat kontrolü ---
    out("## Sandık al-sat kontrolü")
    out()
    out("Beklenen satış iadesinin sandık fiyatına oranı. 1.0'ı geçerse sandık")
    out("alıp hazineyi satmak tek başına para basar ve kasaya hazine koymanın")
    out("anlamı kalmaz.")
    out()
    out("| Sandık | Fiyat | Beklenen iade | Oran |")
    out("|---|---|---|---|")
    refund_share = cfg.balance["Economy"]["sellRefundShare"]
    for crate in cfg.crate_list:
        if crate["currency"] != "coins":
            continue
        income = expected_crate_income(cfg, crate["id"])
        refund = income * cfg.sell_seconds * refund_share
        ratio = refund / crate["cost"]
        out(f"| {crate['name']} | {short(crate['cost'])} | {short(refund)} | {ratio:.2f} |")
        if ratio > GUARDRAILS["sell_flip_ratio_max"]:
            warnings.append(
                f"{crate['name']}: al-sat oranı {ratio:.2f} — sandık alıp satmak kârlı, "
                "fiyatı yükselt ya da sellRefundShare'i düşür"
            )
    out()

    # --- savunma getirisi ---
    out("## Savunma yatırımının getirisi")
    out()
    out("Çevrimdışıyken soyulunca kaybedilen pay (birikimin yüzdesi):")
    out()
    out("| Savunma puanı | Kaybedilen pay | Yorum |")
    out("|---|---|---|")
    for score, comment in [
        (0, "hiç savunma yok"),
        (100, "birkaç seviye lazer"),
        (250, "orta düzey kasa"),
        (400, "direnç tavanına ulaşıldı"),
        (800, "tavan dolu, fazlası boşa"),
    ]:
        share = steal_share(cfg, 0, score, owner_online=False, perfect=False)
        out(f"| {score} | %{share * 100:.1f} | {comment} |")
    out()
    cap_score = cfg.balance["Heist"]["defenseShareDivisor"] * cfg.balance["Heist"]["defenseShareCap"]
    out(
        f"Direnç {cap_score:.0f} puanda tavana vuruyor; bunun üstündeki savunma yatırımı "
        "çalınan payı daha fazla düşürmüyor (yalnızca koridoru zorlaştırıyor)."
    )
    out()

    return "\n".join(lines), warnings


def main() -> int:
    parser = argparse.ArgumentParser(description="Vault Heist ekonomi simülasyonu")
    parser.add_argument("--config", default="build/config.json", help="dışa aktarılmış denge JSON'u")
    parser.add_argument("--runs", type=int, default=120, help="arketip başına koşu sayısı")
    parser.add_argument("--days", type=int, default=14, help="simüle edilecek gün")
    parser.add_argument("--seed", type=int, default=20260918)
    parser.add_argument("--no-charts", action="store_true", help="grafik üretme")
    parser.add_argument("--self-check", action="store_true", help="yalnızca model doğrulaması")
    parser.add_argument("--out", default="build/sim", help="çıktı dizini")
    args = parser.parse_args()

    config_path = Path(args.config)
    if not config_path.exists():
        print(f"denge dosyası yok: {config_path}\n./scripts/sim.sh ile çalıştır", file=sys.stderr)
        return 2

    cfg = Config(json.loads(config_path.read_text()))

    if args.self_check:
        return self_check(cfg)

    if self_check(cfg) != 0:
        return 1
    print()

    results = []
    for policy in ARCHETYPES:
        results.append(run_archetype(cfg, policy, args.runs, args.days, args.seed))

    report, warnings = build_report(cfg, results, args.runs, args.days)
    print(report)

    if warnings:
        print("## ⚠️ Denge uyarıları")
        print()
        for warning in warnings:
            print(f"- {warning}")
        print()
    else:
        print("## ✓ Denge uyarısı yok")
        print()

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    report_path = out_dir / "rapor.md"
    full = report
    if warnings:
        full += "\n## ⚠️ Denge uyarıları\n\n" + "\n".join(f"- {w}" for w in warnings) + "\n"
    report_path.write_text(full, encoding="utf-8")
    print(f"Rapor: {report_path}")

    if not args.no_charts:
        try:
            import charts

            reference = next(r for r in results if r["name"] == "core")
            flows = reference["flows"]
            payload = {
                "archetypes": results,
                "flow_reference": {
                    "label": reference["label"],
                    "days": args.days,
                    "rows": [
                        ("Pasif gelir", flows["passive_income"]),
                        ("Çevrimdışı gelir", flows["offline_income"]),
                        ("Hazine satışı", flows["treasure_sales"]),
                        ("Soygun kazancı", flows["heist_gain"]),
                        ("Soygun kaybı", -flows["heist_loss"]),
                        ("Sandık harcaması", -flows["crate_spend"]),
                        ("Yükseltme", -flows["upgrade_spend"]),
                        ("Savunma", -flows["defense_spend"]),
                    ],
                },
            }
            written = charts.render_all(payload, out_dir)
            for path in written:
                print(f"Grafik: {path}")
        except ImportError as error:
            print(f"Grafikler atlandı ({error}). Kurulum: pip install -r sim/requirements.txt")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
