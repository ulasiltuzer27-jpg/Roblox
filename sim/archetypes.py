"""Oyuncu arketipleri.

Bunlar tahmin değil, denge tartışmasının ortak dili: "hardcore oyuncu 3. günde
nerede olacak" sorusunun tek bir cevabı olsun diye sabitlendiler. Oynanış
verisi geldiğinde buradaki süreler gerçek dağılımla değiştirilmeli.
"""

from __future__ import annotations

from model import Policy

ARCHETYPES = [
    Policy(
        name="casual",
        label="Ara sıra giren",
        sessions_per_day=2,
        session_minutes=12,
        crate_patience_seconds=90,
        upgrade_priority=["income", "slots"],
        defense_priority=[],
        upgrade_budget_share=0.5,
        defense_budget_share=0.0,
        heist_interval_seconds=0,  # soygun yapmıyor
        heist_success_rate=0.0,
    ),
    Policy(
        name="core",
        label="Düzenli oyuncu",
        sessions_per_day=3,
        session_minutes=25,
        crate_patience_seconds=180,
        upgrade_priority=["slots", "income", "luck"],
        defense_priority=["laser", "sensor"],
        upgrade_budget_share=0.4,
        defense_budget_share=0.2,
        heist_interval_seconds=360,
        heist_success_rate=0.65,
    ),
    Policy(
        name="grinder",
        label="Hardcore",
        sessions_per_day=2,
        session_minutes=120,
        crate_patience_seconds=300,
        upgrade_priority=["slots", "luck", "income", "carry", "stealth"],
        defense_priority=["laser", "trap", "sensor", "guard"],
        upgrade_budget_share=0.35,
        defense_budget_share=0.2,
        heist_interval_seconds=240,
        heist_success_rate=0.85,
    ),
    Policy(
        name="payer",
        label="Ödeme yapan",
        sessions_per_day=3,
        session_minutes=25,
        crate_patience_seconds=180,
        upgrade_priority=["slots", "income", "luck"],
        defense_priority=["laser", "sensor", "guard"],
        upgrade_budget_share=0.4,
        defense_budget_share=0.2,
        gamepasses={
            "double_income": True,
            "auto_collect": True,
            "extra_slots": True,
            "vip": True,
            "vip_lock": True,
        },
        heist_interval_seconds=360,
        heist_success_rate=0.65,
    ),
]

BY_NAME = {policy.name: policy for policy in ARCHETYPES}
