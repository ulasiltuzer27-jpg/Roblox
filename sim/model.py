"""Oyunun ekonomi modelinin Python kopyası.

Sayılar build/config.json'dan geliyor (tools/export_config.luau ile üretilir),
yani oyunun kendi denge dosyalarından. Buradaki tek şey *davranış*: formüller
Luau tarafındakilerle birebir aynı olmak zorunda.

Doğrulama: scripts/sim.sh --self-check, bu modülün loot ve gelir hesabını
oyunun beklenen değerleriyle karşılaştırır.
"""

from __future__ import annotations

import bisect
import math
import random

try:  # numpy yoksa simülasyon yine çalışır, sadece yavaşlar
    import numpy as _np
except ImportError:  # pragma: no cover
    _np = None
from dataclasses import dataclass, field


class Config:
    """build/config.json üzerine ince bir sarmalayıcı."""

    def __init__(self, raw: dict):
        self.raw = raw
        self.rarities = {r["id"]: r for r in raw["rarities"]}
        self.rarity_list = raw["rarities"]
        self.mutations = {m["id"]: m for m in raw["mutations"]}
        self.mutation_list = raw["mutations"]
        self.default_mutation = raw["defaultMutation"]
        self.crates = {c["id"]: c for c in raw["crates"]}
        self.crate_list = raw["crates"]
        self.zones = {z["id"]: z for z in raw["zones"]}
        self.upgrades = raw["upgrades"]
        self.defenses = raw["defenses"]
        self.rebirth = raw["rebirth"]
        self.balance = raw["balance"]
        self.sell_seconds = raw["sellSeconds"]
        self.luck_exponent = raw["luckExponent"]
        self.gamepasses = {g["id"]: g for g in raw["gamepasses"]}
        self.products = {p["id"]: p for p in raw["products"]}

    # --- loot ---

    def rarity_weights(self, crate_id: str, luck: float) -> dict[str, float]:
        """Core/Loot.weightsFor ile aynı: şans yalnızca Nadir ve üstünü büker."""
        crate = self.crates[crate_id]
        weights = {}
        for rarity_id, weight in crate["weights"].items():
            order = self.rarities[rarity_id]["order"]
            exponent = max(0, order - 2) * self.luck_exponent
            weights[rarity_id] = weight * max(luck, 0.01) ** exponent
        return weights

    def rarity_chance(self, crate_id: str, rarity_id: str, luck: float) -> float:
        weights = self.rarity_weights(crate_id, luck)
        total = sum(weights.values())
        return weights.get(rarity_id, 0.0) / total if total else 0.0

    def mutation_weights(self, mutation_luck: float) -> dict[str, float]:
        weights = {}
        for mutation in self.mutation_list:
            if mutation["id"] == self.default_mutation:
                weights[mutation["id"]] = mutation["weight"]
            else:
                weights[mutation["id"]] = mutation["weight"] * max(mutation_luck, 0.0)
        return weights

    def mutation_chance(self, mutation_id: str, mutation_luck: float) -> float:
        weights = self.mutation_weights(mutation_luck)
        total = sum(weights.values())
        return weights.get(mutation_id, 0.0) / total if total else 0.0

    # --- değer ---

    def treasure_income(self, rarity_id: str, mutation_id: str) -> float:
        return self.rarities[rarity_id]["baseIncome"] * self.mutations[mutation_id]["multiplier"]

    def treasure_value(self, rarity_id: str, mutation_id: str) -> float:
        return self.treasure_income(rarity_id, mutation_id) * self.sell_seconds

    # --- eğriler ---

    def upgrade_cost(self, upgrade_id: str, level: int) -> float:
        costs = self.upgrades[upgrade_id]["costs"]
        return costs[level] if level < len(costs) else math.inf

    def upgrade_max(self, upgrade_id: str) -> int:
        return self.upgrades[upgrade_id]["maxLevel"]

    def upgrade_effect(self, upgrade_id: str, level: int) -> float:
        return self.upgrades[upgrade_id]["perLevel"] * level

    def rebirth_requirement(self, rebirths: int) -> float:
        reqs = self.rebirth["requirements"]
        return reqs[rebirths] if rebirths < len(reqs) else math.inf

    def rebirth_multiplier(self, rebirths: int) -> float:
        mults = self.rebirth["multipliers"]
        return mults[rebirths] if rebirths < len(mults) else mults[-1]


class Sampler:
    """Önceden hesaplanmış kümülatif ağırlık tabloları.

    Sıcak döngüde saniyede on binlerce zar atılıyor; tabloyu her seferinde
    kurmak simülasyonun en pahalı işiydi.
    """

    def __init__(self, cfg: "Config"):
        self.cfg = cfg
        self._rarity_cache: dict[tuple[str, int], tuple[list[str], list[float], float]] = {}
        ids = [m["id"] for m in cfg.mutation_list]
        weights = cfg.mutation_weights(1.0)
        self._mutation_ids = ids
        self._mutation_cum = []
        total = 0.0
        for mutation_id in ids:
            total += weights[mutation_id]
            self._mutation_cum.append(total)
        self._mutation_total = total

    def rarity(self, crate_id: str, luck: float, rng: random.Random) -> str:
        key = (crate_id, int(luck * 1000))
        entry = self._rarity_cache.get(key)
        if entry is None:
            weights = self.cfg.rarity_weights(crate_id, luck)
            ids = list(weights)
            cum = []
            total = 0.0
            for rarity_id in ids:
                total += weights[rarity_id]
                cum.append(total)
            entry = (ids, cum, total)
            self._rarity_cache[key] = entry
        ids, cum, total = entry
        return ids[bisect.bisect_right(cum, rng.random() * total)]

    def mutation(self, rng: random.Random) -> str:
        return self._mutation_ids[
            bisect.bisect_right(self._mutation_cum, rng.random() * self._mutation_total)
        ]

    def _rarity_table(self, crate_id: str, luck: float):
        key = (crate_id, int(luck * 1000))
        entry = self._rarity_cache.get(key)
        if entry is None:
            weights = self.cfg.rarity_weights(crate_id, luck)
            ids = list(weights)
            cum = []
            total = 0.0
            for rarity_id in ids:
                total += weights[rarity_id]
                cum.append(total)
            entry = (ids, cum, total)
            self._rarity_cache[key] = entry
        return entry

    def batch(self, crate_id: str, luck: float, amount: int, rng: random.Random):
        """`amount` zar birden. (gelirler, nadirlik id'leri) döndürür.

        Sıcak döngünün tamamı burası: tek tek nesne yaratmak yerine önce
        sayıları üretip sonra yalnızca kasada kalacaklar için nesne kuruyoruz.
        """
        rarity_ids, rarity_cum, rarity_total = self._rarity_table(crate_id, luck)
        income_of = self.cfg.treasure_income

        incomes = []
        rarities = []
        mutation_ids = self._mutation_ids
        mutation_cum = self._mutation_cum
        mutation_total = self._mutation_total
        random_value = rng.random

        for _ in range(amount):
            rarity = rarity_ids[bisect.bisect_right(rarity_cum, random_value() * rarity_total)]
            mutation = mutation_ids[
                bisect.bisect_right(mutation_cum, random_value() * mutation_total)
            ]
            rarities.append((rarity, mutation))
            incomes.append(income_of(rarity, mutation))
        return incomes, rarities


@dataclass
class Treasure:
    rarity: str
    mutation: str
    income: float
    value: float


@dataclass
class Flows:
    """Nereden gelip nereye gittiğinin muhasebesi."""

    passive_income: float = 0.0
    offline_income: float = 0.0
    heist_gain: float = 0.0
    heist_loss: float = 0.0
    treasure_sales: float = 0.0
    crate_spend: float = 0.0
    upgrade_spend: float = 0.0
    defense_spend: float = 0.0
    rebirth_burned: float = 0.0


class Player:
    """Tek bir oyuncunun kasası ve cüzdanı."""

    def __init__(self, cfg: Config, policy: "Policy", rng: random.Random, sampler: "Sampler | None" = None):
        self.cfg = cfg
        self.policy = policy
        self.rng = rng
        self.sampler = sampler or Sampler(cfg)

        self.coins = cfg.balance["Economy"]["startingCoins"]
        # Gelire göre artan sırada tutuluyor: en zayıf hazine hep başta.
        self.placed: list[Treasure] = []
        self._income_sum = 0.0
        self.upgrade_levels: dict[str, int] = {}
        self.defense_levels: dict[str, int] = {}
        self.rebirths = 0
        self.zone = "hub"

        self.flows = Flows()
        self.crates_opened = 0
        self.rarity_counts: dict[str, int] = {}
        self.mutation_counts: dict[str, int] = {}
        self.rebirth_times: list[float] = []

        for crate_id, amount in cfg.balance["Economy"]["starterCrates"].items():
            for _ in range(int(amount)):
                self.open_crate(crate_id, free=True)

    # --- türetilmiş değerler ---

    @property
    def slots(self) -> int:
        balance = self.cfg.balance["Vault"]
        slots = balance["baseSlots"] + self.upgrade_levels.get("slots", 0)
        if self.policy.gamepasses.get("extra_slots"):
            slots += balance["extraSlotsGamepass"]
        return int(min(slots, balance["maxSlots"]))

    @property
    def income_multiplier(self) -> float:
        cfg = self.cfg
        upgrade = 1 + cfg.upgrade_effect("income", self.upgrade_levels.get("income", 0))
        rebirth = cfg.rebirth_multiplier(self.rebirths)
        zone = 1 + cfg.zones[self.zone]["incomeBonus"]
        double = 2 if self.policy.gamepasses.get("double_income") else 1
        return upgrade * rebirth * zone * double

    @property
    def rate(self) -> float:
        """Saniyelik gelir."""
        return sum(t.income for t in self.placed) * self.income_multiplier

    @property
    def luck(self) -> float:
        luck = 1 + self.cfg.upgrade_effect("luck", self.upgrade_levels.get("luck", 0))
        if self.policy.gamepasses.get("vip"):
            luck *= 1.1
        return luck

    @property
    def net_worth(self) -> float:
        return self.coins + self._income_sum * self.cfg.sell_seconds

    # --- eylemler ---

    def roll(self, crate_id: str) -> Treasure:
        rarity = self.sampler.rarity(crate_id, self.luck, self.rng)
        mutation = self.sampler.mutation(self.rng)
        income = self.cfg.treasure_income(rarity, mutation)
        return Treasure(
            rarity=rarity,
            mutation=mutation,
            income=income,
            value=income * self.cfg.sell_seconds,
        )

    def open_crate(self, crate_id: str, free: bool = False) -> Treasure:
        """Tek sandık. Toplu açma için open_crates kullanılıyor."""
        if not free:
            cost = self.cfg.crates[crate_id]["cost"]
            self.coins -= cost
            self.flows.crate_spend += cost

        treasure = self.roll(crate_id)
        self.crates_opened += 1
        self.rarity_counts[treasure.rarity] = self.rarity_counts.get(treasure.rarity, 0) + 1
        self.mutation_counts[treasure.mutation] = self.mutation_counts.get(treasure.mutation, 0) + 1
        self._absorb([treasure.income])
        return treasure

    def open_crates(self, crate_id: str, amount: int) -> None:
        """Toplu açma -- oyundaki "10 AÇ" düğmesinin karşılığı.

        Sırayla "en zayıfı daha iyisiyle değiştir" ile birebir aynı sonucu
        verir: kasada, eski yuvalar ile yeni çıkanların birleşiminin en iyi
        `slots` tanesi kalır.
        """
        if amount <= 0:
            return
        cost = self.cfg.crates[crate_id]["cost"] * amount
        self.coins -= cost
        self.flows.crate_spend += cost
        self.crates_opened += amount

        incomes, rolls = self.sampler.batch(crate_id, self.luck, amount, self.rng)
        for rarity, mutation in rolls:
            self.rarity_counts[rarity] = self.rarity_counts.get(rarity, 0) + 1
            self.mutation_counts[mutation] = self.mutation_counts.get(mutation, 0) + 1
        self._absorb(incomes)

    def _absorb(self, incomes: list[float]) -> None:
        """Yeni gelirleri kasaya kat; yuvaya sığmayanları sat.

        Satış oyundaki oranla: varlık değerinin sellRefundShare kadarı.
        """
        slots = self.slots
        sell_seconds = self.cfg.sell_seconds
        refund_share = self.cfg.balance["Economy"]["sellRefundShare"]

        pool = [t.income for t in self.placed]
        pool.extend(incomes)
        pool.sort()

        if len(pool) > slots:
            sold = pool[: len(pool) - slots]
            keep = pool[len(pool) - slots :]
        else:
            sold = []
            keep = pool

        self.placed = [
            Treasure(rarity="", mutation="", income=income, value=income * sell_seconds)
            for income in keep
        ]
        self._income_sum = sum(keep)

        if sold:
            refund = sum(sold) * sell_seconds * refund_share
            self.coins += refund
            self.flows.treasure_sales += refund

    def buy_upgrade(self, upgrade_id: str) -> bool:
        level = self.upgrade_levels.get(upgrade_id, 0)
        if level >= self.cfg.upgrade_max(upgrade_id):
            return False
        cost = self.cfg.upgrade_cost(upgrade_id, level)
        if self.coins < cost:
            return False
        self.coins -= cost
        self.flows.upgrade_spend += cost
        self.upgrade_levels[upgrade_id] = level + 1
        return True

    def buy_defense(self, defense_id: str) -> bool:
        level = self.defense_levels.get(defense_id, 0)
        curve = self.cfg.defenses[defense_id]
        if level >= curve["maxLevel"]:
            return False
        cost = curve["costs"][level]
        if self.coins < cost:
            return False
        self.coins -= cost
        self.flows.defense_spend += cost
        self.defense_levels[defense_id] = level + 1
        return True

    def defense_score(self) -> float:
        score = 0.0
        for defense_id, level in self.defense_levels.items():
            score += level * self.cfg.defenses[defense_id]["scoreWeight"] * 10
        multiplier = 1 + self.cfg.upgrade_effect("defense_power", self.upgrade_levels.get("defense_power", 0))
        if self.policy.gamepasses.get("vip_lock"):
            multiplier *= 1.35
        return score * multiplier

    def can_rebirth(self) -> bool:
        return self.net_worth >= self.cfg.rebirth_requirement(self.rebirths)

    def do_rebirth(self, now: float) -> None:
        burned = self.net_worth
        self.rebirths += 1
        self.flows.rebirth_burned += burned

        self.coins = self.cfg.balance["Economy"]["startingCoins"]
        self.placed = []
        self.upgrade_levels = {}
        # Savunmalar kalır (oyundaki kuralla aynı).

        # Açılan en iyi bölgeye taşın.
        for zone in sorted(self.cfg.raw["zones"], key=lambda z: z["requiredRebirths"]):
            if self.rebirths >= zone["requiredRebirths"]:
                self.zone = zone["id"]

        for crate_id, amount in self.cfg.balance["Economy"]["starterCrates"].items():
            for _ in range(int(amount)):
                self.open_crate(crate_id, free=True)

    def unlocked_crates(self) -> list[dict]:
        return [
            crate
            for crate in self.cfg.crate_list
            if crate["currency"] == "coins"
            and self.rebirths >= self.cfg.zones[crate["zone"]]["requiredRebirths"]
        ]


@dataclass
class Policy:
    """Oyuncu arketipi: ne kadar oynuyor, neye para harcıyor, nasıl soyuyor."""

    name: str
    label: str
    sessions_per_day: int
    session_minutes: float
    # Sandık seçimi: bu kadar saniye beklemeyi göze alıyorsa daha pahalısını alır.
    crate_patience_seconds: float
    upgrade_priority: list[str] = field(default_factory=list)
    defense_priority: list[str] = field(default_factory=list)
    # Yükseltme/savunma, parayı zorlamıyorsa alınır: maliyeti kasadaki
    # paranın bu oranını aşıyorsa oyuncu önce sandığa devam eder.
    # ("en ucuz ne varsa al" modeli hardcore oyuncuyu casual'dan yavaş
    # gösteriyordu -- gerçek oyuncu böyle oynamıyor.)
    upgrade_budget_share: float = 0.35
    defense_budget_share: float = 0.2
    gamepasses: dict[str, bool] = field(default_factory=dict)
    # Soygun davranışı
    heist_interval_seconds: float = 0.0
    heist_success_rate: float = 0.0
    robbed_interval_seconds: float = 1800.0

    @property
    def online_seconds_per_day(self) -> float:
        return self.sessions_per_day * self.session_minutes * 60
