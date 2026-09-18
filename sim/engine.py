"""Simülasyon motoru: oturum/çevrimdışı döngüsü, satın alma kararları, soygun.

Zaman olay güdümlü ilerliyor: gelir sabitken bir sonraki satın almaya kadar
geçen süre analitik olarak hesaplanıp atlanıyor. Saniye saniye döngü kurmaya
göre yüzlerce kat hızlı ve sonuç birebir aynı.
"""

from __future__ import annotations

import math
import random

from model import Config, Player, Policy

# Çevrimdışıyken kaç kez soyulduğu. Sunucu nüfusuna bağlı olduğu için
# varsayım; savunma yatırımının getirisini ölçmek için sabit tutuluyor.
OFFLINE_ROBBERIES_PER_HOUR = 0.5
MAX_OFFLINE_ROBBERIES = 3

# Soygun hedefi: benzer seviyede, yarım saatlik birikim biriktirmiş bir kasa.
TARGET_STASH_SECONDS = 1800


def steal_share(cfg: Config, carry_level: int, defense_score: float, owner_online: bool, perfect: bool) -> float:
    """Core/Heist.stealShare ile aynı formül."""
    heist = cfg.balance["Heist"]
    share = heist["baseStealShare"] + cfg.upgrade_effect("carry", carry_level)
    if perfect:
        share += heist["perfectBonus"]
    resistance = min(heist["defenseShareCap"], defense_score / heist["defenseShareDivisor"])
    share *= 1 - resistance
    if not owner_online:
        share *= heist["offlineDefenderShareMultiplier"]
    return max(0.01, min(share, heist["maxStealShare"]))


def _choose_crate(player: Player, rate: float) -> dict | None:
    """Beklemeyi göze aldığı en pahalı sandık; yoksa en ucuzu."""
    unlocked = player.unlocked_crates()
    if not unlocked:
        return None

    affordable_soon = []
    for crate in unlocked:
        need = max(0.0, crate["cost"] - player.coins)
        wait = 0.0 if need <= 0 else (need / rate if rate > 0 else math.inf)
        if wait <= player.policy.crate_patience_seconds:
            affordable_soon.append(crate)

    if affordable_soon:
        return max(affordable_soon, key=lambda c: c["cost"])
    return min(unlocked, key=lambda c: c["cost"])


def _next_upgrade(player: Player) -> tuple[str, float] | None:
    for upgrade_id in player.policy.upgrade_priority:
        level = player.upgrade_levels.get(upgrade_id, 0)
        if level < player.cfg.upgrade_max(upgrade_id):
            return upgrade_id, player.cfg.upgrade_cost(upgrade_id, level)
    return None


def _next_defense(player: Player) -> tuple[str, float] | None:
    for defense_id in player.policy.defense_priority:
        level = player.defense_levels.get(defense_id, 0)
        curve = player.cfg.defenses[defense_id]
        if level < curve["maxLevel"]:
            return defense_id, curve["costs"][level]
    return None


def _accrue(player: Player, seconds: float) -> None:
    """Çevrimiçi gelir. Oyuncu sık topladığı için tavan nadiren devreye girer."""
    if seconds <= 0:
        return
    rate = player.rate
    cap_seconds = player.cfg.balance["Vault"]["onlineStashSeconds"]
    earned = rate * min(seconds, cap_seconds)
    player.coins += earned
    player.flows.passive_income += earned


def _do_heist(player: Player, cfg: Config, rng: random.Random) -> float:
    """Bir soygun denemesi. Dönen değer: kaybedilen ek süre (hapis)."""
    policy = player.policy
    if rng.random() > policy.heist_success_rate:
        heist = cfg.balance["Heist"]
        jail = heist["jailSeconds"]
        if policy.gamepasses.get("vip"):
            jail *= heist["vipJailMultiplier"]
        return jail

    perfect = rng.random() < 0.35
    # Hedefin savunması, oyuncunun kendi savunmasına benzer kabul ediliyor
    # (aynı servet bandındaki oyuncular eşleşiyor).
    share = steal_share(
        cfg,
        carry_level=player.upgrade_levels.get("carry", 0),
        defense_score=player.defense_score(),
        owner_online=True,
        perfect=perfect,
    )
    gain = player.rate * TARGET_STASH_SECONDS * share
    player.coins += gain
    player.flows.heist_gain += gain
    return 0.0


def run_session(player: Player, cfg: Config, seconds: float, rng: random.Random, on_rebirth=None) -> None:
    """Bir oturum.

    Oyuncu önce sandığa odaklanıyor; yükseltme ve savunmayı ancak parayı
    zorlamadığında alıyor. Rebirth eşiği geçilir geçilmez yapılıyor -- oturum
    sonunu beklemek uzun oturumlu arketipleri haksız yere yavaş gösteriyordu.
    """
    policy = player.policy
    elapsed = 0.0
    next_heist = policy.heist_interval_seconds if policy.heist_interval_seconds > 0 else math.inf
    guard = 0

    while elapsed < seconds:
        guard += 1
        if guard > 12000:  # sonsuz döngüye karşı emniyet
            break

        rate = player.rate
        crate = _choose_crate(player, rate)
        if crate is None:
            _accrue(player, seconds - elapsed)
            break

        need = max(0.0, crate["cost"] - player.coins)
        wait = 0.0 if need <= 0 else (need / rate if rate > 0 else math.inf)
        if wait == math.inf:
            _accrue(player, seconds - elapsed)
            break

        step = min(wait, seconds - elapsed, next_heist - elapsed)
        _accrue(player, step)
        elapsed += step

        if elapsed >= next_heist - 1e-9 and policy.heist_interval_seconds > 0:
            elapsed += _do_heist(player, cfg, rng)
            next_heist = elapsed + policy.heist_interval_seconds
            continue

        if elapsed >= seconds - 1e-9:
            break

        if step >= wait - 1e-9:
            # Toplu aç: tek tek açmakla aynı sonuç, açma animasyonu da
            # oturumdan zaman yiyor -- gerçek tempoyu bu belirliyor.
            bulk = int(cfg.balance["Crates"]["bulkOpenLimit"])
            affordable = int(player.coins // crate["cost"])
            amount = max(1, min(bulk, affordable))
            player.open_crates(crate["id"], amount)
            open_cost = crate["openTime"] * (amount / bulk)
            _accrue(player, open_cost)
            elapsed += open_cost

            _buy_opportunistically(player)

            while player.can_rebirth():
                player.do_rebirth(0.0)
                if on_rebirth:
                    on_rebirth(elapsed)


def _buy_opportunistically(player: Player) -> None:
    """Parayı zorlamayan yükseltme ve savunmaları al."""
    policy = player.policy

    for _ in range(4):
        upgrade = _next_upgrade(player)
        if not upgrade or upgrade[1] > player.coins * policy.upgrade_budget_share:
            break
        if not player.buy_upgrade(upgrade[0]):
            break

    for _ in range(4):
        defense = _next_defense(player)
        if not defense or defense[1] > player.coins * policy.defense_budget_share:
            break
        if not player.buy_defense(defense[0]):
            break


def run_offline(player: Player, cfg: Config, seconds: float, rng: random.Random) -> None:
    """Çevrimdışı kazanç birikir ve bu birikim soyulabilir."""
    rate = player.rate
    if rate <= 0:
        return

    offline = cfg.balance["Offline"]
    cap_hours = (
        offline["capHoursWithGamepass"]
        if player.policy.gamepasses.get("auto_collect")
        else offline["capHours"]
    )
    stash = rate * min(seconds, cap_hours * 3600) * offline["efficiency"]

    robberies = min(MAX_OFFLINE_ROBBERIES, int(seconds / 3600 * OFFLINE_ROBBERIES_PER_HOUR))
    for _ in range(robberies):
        if stash <= cfg.balance["Vault"]["minStashToRob"]:
            break
        share = steal_share(
            cfg,
            carry_level=0,
            defense_score=player.defense_score() * (1 + cfg.balance["Heist"]["offlineDefenseBonus"]),
            owner_online=False,
            perfect=False,
        )
        loss = stash * share
        stash -= loss
        player.flows.heist_loss += loss

    player.coins += stash
    player.flows.offline_income += stash


def simulate(cfg: Config, policy: Policy, days: int, rng: random.Random) -> dict:
    """Bir oyuncuyu `days` gün boyunca simüle eder ve günlük ölçümleri döndürür."""
    player = Player(cfg, policy, rng)

    session_seconds = policy.session_minutes * 60
    offline_seconds = (86400 - policy.online_seconds_per_day) / policy.sessions_per_day

    now = 0.0        # duvar saati
    playtime = 0.0   # gerçekten oyunda geçen süre -- asıl anlamlı olan bu
    daily = []
    rebirth_playtimes: list[float] = []

    for _ in range(days):
        for _ in range(policy.sessions_per_day):
            session_start_wall = now
            session_start_play = playtime

            def note_rebirth(session_elapsed: float) -> None:
                player.rebirth_times.append(session_start_wall + session_elapsed)
                rebirth_playtimes.append(session_start_play + session_elapsed)

            run_session(player, cfg, session_seconds, rng, on_rebirth=note_rebirth)
            now += session_seconds
            playtime += session_seconds

            run_offline(player, cfg, offline_seconds, rng)
            now += offline_seconds

        daily.append(
            {
                "day": len(daily) + 1,
                "net_worth": player.net_worth,
                "rate": player.rate,
                "rebirths": player.rebirths,
                "crates": player.crates_opened,
            }
        )

    return {
        "player": player,
        "daily": daily,
        "first_rebirth_hours": (player.rebirth_times[0] / 3600) if player.rebirth_times else None,
        "rebirth_hours": [t / 3600 for t in player.rebirth_times],
        "first_rebirth_playtime_minutes": (rebirth_playtimes[0] / 60) if rebirth_playtimes else None,
        "rebirth_playtime_minutes": [t / 60 for t in rebirth_playtimes],
        "playtime_hours": playtime / 3600,
    }
