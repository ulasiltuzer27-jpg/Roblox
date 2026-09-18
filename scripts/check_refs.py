#!/usr/bin/env python3
"""Require yolları ve remote kanal adları gerçekten var mı?

Yanlış yazılmış bir require yolu ya da kanal adı derlenir ama çalışma anında
patlar. Studio olmadan yakalanabilecek ikinci hata sınıfı bu.

    python3 scripts/check_refs.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

# Servis ağacındaki kök -> disk yolu
ROOTS = {
    "ReplicatedStorage.Shared": SRC / "shared",
    "ServerScriptService.Server": SRC / "server",
}


def module_exists(base: Path, parts: list[str]) -> bool:
    path = base.joinpath(*parts)
    return (path.with_suffix(".luau")).exists() or (path / "init.luau").exists()


def check_requires() -> list[str]:
    problems: list[str] = []
    for path in sorted(SRC.rglob("*.luau")):
        text = path.read_text(encoding="utf-8")
        relative = path.relative_to(ROOT)

        # Takma adlar: local Services = ServerScriptService.Server.Services
        aliases: dict[str, str] = {}
        for match in re.finditer(r"local\s+(\w+)\s*=\s*((?:ReplicatedStorage|ServerScriptService)[\w.]*)", text):
            aliases[match.group(1)] = match.group(2)

        for match in re.finditer(r"require\(\s*([\w.]+)\s*\)", text):
            expression = match.group(1)
            line = text.count("\n", 0, match.start()) + 1

            head = expression.split(".")[0]
            if head in aliases:
                expression = aliases[head] + expression[len(head):]
            elif head not in ("ReplicatedStorage", "ServerScriptService"):
                continue  # script.Parent... gibi yerel yollar bu denetimin dışında

            for prefix, base in ROOTS.items():
                if expression.startswith(prefix + "."):
                    parts = expression[len(prefix) + 1:].split(".")
                    if not module_exists(base, parts):
                        problems.append(f"{relative}:{line}: require yolu yok -> {expression}")
                    break
            else:
                problems.append(f"{relative}:{line}: tanınmayan require kökü -> {expression}")
    return problems


def check_remote_names() -> list[str]:
    """NetService.push/register çağrılarındaki adlar Remotes'ta tanımlı mı."""
    problems: list[str] = []
    remotes = (SRC / "shared" / "Net" / "Remotes.luau").read_text(encoding="utf-8")

    def names(section: str) -> set[str]:
        block = re.search(rf"Remotes\.{section}\s*=\s*\{{(.*?)\n\}}", remotes, re.S)
        if not block:
            return set()
        return set(re.findall(r'(\w+)\s*=\s*"(\w+)"', block.group(1)) and
                   [m[1] for m in re.findall(r'(\w+)\s*=\s*"(\w+)"', block.group(1))])

    channels, actions, inputs = names("Channels"), names("Actions"), names("Inputs")

    for path in sorted(SRC.rglob("*.luau")):
        text = path.read_text(encoding="utf-8")
        relative = path.relative_to(ROOT)

        for pattern, valid, label in (
            (r'NetService\.push\(\s*\w+\s*,\s*"(\w+)"', channels, "kanal"),
            (r'NetService\.pushAll\(\s*"(\w+)"', channels, "kanal"),
            (r'Net\.on\(\s*"(\w+)"', channels, "kanal"),
            (r'Net\.invoke\(\s*"(\w+)"', actions, "eylem"),
            (r'Net\.send\(\s*"(\w+)"', inputs, "girdi"),
        ):
            for match in re.finditer(pattern, text):
                name = match.group(1)
                if name not in valid:
                    line = text.count("\n", 0, match.start()) + 1
                    problems.append(f"{relative}:{line}: tanımsız {label} adı -> \"{name}\"")
    return problems


def main() -> int:
    problems = check_requires() + check_remote_names()
    if problems:
        print(f"{len(problems)} referans sorunu:")
        for problem in problems:
            print(f"  ✗ {problem}")
        return 1
    print("require yolları ve remote adları tutarlı")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
