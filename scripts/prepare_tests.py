#!/usr/bin/env python3
"""src/shared ve tests/ dosyalarını build/test/ altına kopyalar ve
Roblox'a özgü require'ları standalone Luau'nun anladığı göreli yollara çevirir.

    local ReplicatedStorage = game:GetService("ReplicatedStorage")   -> kaldırılır
    require(ReplicatedStorage.Shared.Core.Loot)                      -> require("../shared/Core/Loot")

Kaynak dosyalar olduğu gibi kalır; dönüşüm yalnızca test kopyasına uygulanır.
Dönüşüm bozulursa testler yüklenemez ve gürültülü şekilde patlar.
"""

from __future__ import annotations

import os
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build" / "test"

SERVICE_LINE = re.compile(
    r"^\s*local\s+\w+\s*=\s*game:GetService\(\"[^\"]+\"\)\s*$", re.MULTILINE
)
ALIAS_LINE = re.compile(
    r"^\s*local\s+\w+\s*=\s*ReplicatedStorage\.[\w.]+\s*$", re.MULTILINE
)
REQUIRE_CALL = re.compile(r"require\(\s*(?:ReplicatedStorage\.Shared|ConfigFolder)\.([\w.]+)\s*\)")


def rewrite(text: str, from_dir: Path) -> str:
    def to_relative(match: re.Match[str]) -> str:
        segments = match.group(1).split(".")
        if from_dir.name == "shared" and segments[0] != "Config" and (BUILD / "shared" / "Config" / segments[0]).with_suffix(".luau").exists():
            segments.insert(0, "Config")  # ConfigFolder kısayolu
        target = BUILD / "shared" / Path(*segments)
        relative = os.path.relpath(target, from_dir)
        if not relative.startswith("."):
            relative = f"./{relative}"
        return f'require("{relative}")'

    text = REQUIRE_CALL.sub(to_relative, text)
    text = SERVICE_LINE.sub("-- [test] Roblox servisi test kopyasında kullanılmıyor", text)
    text = ALIAS_LINE.sub("-- [test] servis ağacı kısayolu test kopyasında kullanılmıyor", text)
    return text


def copy_tree(source: Path, destination: Path) -> int:
    count = 0
    for path in sorted(source.rglob("*.luau")):
        target = destination / path.relative_to(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        # Luau'da init.luau klasörünün kendisini temsil eder: göreli yollar
        # bir üst dizinden çözülür.
        base = target.parent.parent if target.name == "init.luau" else target.parent
        target.write_text(rewrite(path.read_text(encoding="utf-8"), base), encoding="utf-8")
        count += 1
    return count


def main() -> int:
    if BUILD.exists():
        shutil.rmtree(BUILD)
    BUILD.mkdir(parents=True)

    modules = copy_tree(ROOT / "src" / "shared", BUILD / "shared")
    specs = copy_tree(ROOT / "tests" / "specs", BUILD / "specs")
    copy_tree(ROOT / "tools", BUILD / "tools")

    for name in ("framework.luau", "run.luau"):
        source = ROOT / "tests" / name
        (BUILD / name).write_text(
            rewrite(source.read_text(encoding="utf-8"), BUILD), encoding="utf-8"
        )

    remaining = [
        str(path.relative_to(BUILD))
        for path in BUILD.rglob("*.luau")
        if "game:GetService" in path.read_text(encoding="utf-8")
    ]
    if remaining:
        print("uyarı: çevrilemeyen game:GetService kullanımı var:", ", ".join(remaining), file=sys.stderr)

    print(f"build/test hazır: {modules} modül, {specs} test dosyası")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
