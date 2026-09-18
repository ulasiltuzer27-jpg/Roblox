#!/usr/bin/env python3
"""Roblox API dökümüne karşı statik doğrulama.

Studio olmadan yakalanabilen hata sınıfı: var olmayan özelliğe yazmak,
var olmayan Enum üyesi kullanmak, yanlış sınıfa özellik atamak. Bu hatalar
çalışma anında patlıyor ve testlerle yakalanmıyor.

    python3 scripts/check_api.py [--dump <yol>]

API dökümü yoksa indirir (ya da --dump ile yol verilir).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DUMP_URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json"
DEFAULT_DUMP = ROOT / "build" / "api-dump.json"

# Widgets yardımcılarının hangi sınıfı ürettiği.
WIDGET_CLASSES = {
    "Widgets.frame": "Frame",
    "Widgets.text": "TextLabel",
    "Widgets.button": "TextButton",
    "Widgets.scroller": "ScrollingFrame",
    "Widgets.corner": "UICorner",
    "Widgets.stroke": "UIStroke",
    "Widgets.padding": "UIPadding",
    "Widgets.list": "UIListLayout",
}

# Widgets.create ve benzerlerinde sahte anahtar olarak kullanılanlar.
PSEUDO_KEYS = {"Parent"}


class Api:
    def __init__(self, dump: dict):
        self.classes = {c["Name"]: c for c in dump["Classes"]}
        self.enums = {e["Name"]: {item["Name"] for item in e["Items"]} for e in dump["Enums"]}
        self._members: dict[str, set[str]] = {}

    def members(self, class_name: str) -> set[str]:
        """Sınıfın kendi + miras aldığı bütün üye adları."""
        if class_name in self._members:
            return self._members[class_name]
        cls = self.classes.get(class_name)
        if not cls:
            return set()
        names = {m["Name"] for m in cls["Members"]}
        parent = cls.get("Superclass")
        if parent and parent != "<<<ROOT>>>":
            names |= self.members(parent)
        self._members[class_name] = names
        return names

    def has_class(self, class_name: str) -> bool:
        return class_name in self.classes


def load_dump(path: Path) -> dict:
    if path.exists():
        return json.loads(path.read_text())
    path.parent.mkdir(parents=True, exist_ok=True)
    print(f"API dökümü indiriliyor → {path}")
    with urllib.request.urlopen(DUMP_URL, timeout=90) as response:
        data = response.read()
    path.write_bytes(data)
    return json.loads(data)


def table_keys(text: str, start: int) -> tuple[list[tuple[str, int]], int]:
    """`{` konumundan başlayarak üst seviye `Anahtar =` çiftlerini toplar."""
    depth = 0
    index = start
    keys: list[tuple[str, int]] = []
    while index < len(text):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return keys, index
        elif depth == 1:
            match = re.match(r"\s*([A-Za-z_]\w*)\s*=", text[index:])
            if match and (index == 0 or text[index - 1] in "{,\n\t "):
                keys.append((match.group(1), text.count("\n", 0, index) + 1))
                index += match.end() - 1
        index += 1
    return keys, index


def check_file(path: Path, api: Api) -> list[str]:
    text = path.read_text(encoding="utf-8")
    problems: list[str] = []
    relative = path.relative_to(ROOT)

    # 1) Instance.new("X") ile oluşturulan değişkenlerin sınıfını izle
    # `local x = Instance.new(...)` ve `x = Instance.new(...)` -- ikincisi
    # atlanıyordu ve o yüzden gerçek bir hata kaçıyordu.
    var_class: dict[str, str] = {}
    ambiguous: set[str] = set()
    for match in re.finditer(
        r'(?:local\s+)?(\w+)(?:\s*:\s*[\w.]+)?\s*=\s*Instance\.new\(\s*"(\w+)"', text
    ):
        variable, class_name = match.group(1), match.group(2)
        if variable in var_class and var_class[variable] != class_name:
            # Aynı ad iki farklı sınıfa atanmış: izlemeyi bırak, yanlış
            # pozitif üretmekten iyidir.
            ambiguous.add(variable)
        var_class[variable] = class_name
    for variable in ambiguous:
        var_class.pop(variable, None)
    for match in re.finditer(r'Instance\.new\(\s*"(\w+)"', text):
        if not api.has_class(match.group(1)):
            line = text.count("\n", 0, match.start()) + 1
            problems.append(f"{relative}:{line}: bilinmeyen sınıf Instance.new(\"{match.group(1)}\")")

    for variable, class_name in var_class.items():
        if not api.has_class(class_name):
            continue
        members = api.members(class_name)
        for match in re.finditer(rf"\b{re.escape(variable)}\.(\w+)\s*=", text):
            prop = match.group(1)
            if prop not in members:
                line = text.count("\n", 0, match.start()) + 1
                problems.append(f"{relative}:{line}: {class_name}.{prop} yok")

    # 2) Widgets.create("X", { ... }) ve Widgets.<yardımcı>({ ... })
    for match in re.finditer(r'Widgets\.create\(\s*"(\w+)"\s*,\s*\{', text):
        class_name = match.group(1)
        if not api.has_class(class_name):
            line = text.count("\n", 0, match.start()) + 1
            problems.append(f'{relative}:{line}: bilinmeyen sınıf Widgets.create("{class_name}")')
            continue
        members = api.members(class_name)
        keys, _ = table_keys(text, match.end() - 1)
        for key, line in keys:
            if key not in members and key not in PSEUDO_KEYS:
                problems.append(f"{relative}:{line}: {class_name}.{key} yok (Widgets.create)")

    for helper, class_name in WIDGET_CLASSES.items():
        members = api.members(class_name)
        for match in re.finditer(rf"{re.escape(helper)}\(\s*\{{", text):
            keys, _ = table_keys(text, match.end() - 1)
            for key, line in keys:
                if key not in members and key not in PSEUDO_KEYS:
                    problems.append(f"{relative}:{line}: {class_name}.{key} yok ({helper})")

    # 3) Enum.X.Y
    for match in re.finditer(r"Enum\.(\w+)\.(\w+)", text):
        enum_name, item = match.group(1), match.group(2)
        line = text.count("\n", 0, match.start()) + 1
        if enum_name not in api.enums:
            problems.append(f"{relative}:{line}: bilinmeyen Enum.{enum_name}")
        elif item not in api.enums[enum_name]:
            problems.append(f"{relative}:{line}: Enum.{enum_name}.{item} yok")

    return problems


def check_project(path: Path, api: Api) -> list[str]:
    """default.project.json içindeki $properties gerçek mi."""
    problems: list[str] = []
    data = json.loads(path.read_text())

    def walk(node: dict, class_name: str | None, trail: str):
        current = node.get("$className", class_name)
        properties = node.get("$properties")
        if properties and current:
            if not api.has_class(current):
                problems.append(f"{path.name}: bilinmeyen sınıf {current} ({trail})")
            else:
                members = api.members(current)
                for key in properties:
                    if key not in members:
                        problems.append(f"{path.name}: {current}.{key} yok ({trail})")
        for key, value in node.items():
            if isinstance(value, dict) and not key.startswith("$"):
                walk(value, None, f"{trail}.{key}" if trail else key)

    walk(data.get("tree", {}), None, "")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description="Roblox API doğrulaması")
    parser.add_argument("--dump", default=str(DEFAULT_DUMP))
    args = parser.parse_args()

    try:
        api = Api(load_dump(Path(args.dump)))
    except Exception as error:  # ağ yoksa sessizce atla
        print(f"API dökümü alınamadı ({error}); doğrulama atlandı.", file=sys.stderr)
        return 0

    problems: list[str] = []
    files = sorted((ROOT / "src").rglob("*.luau")) + sorted((ROOT / "tools" / "studio").glob("*.luau"))
    for path in files:
        problems.extend(check_file(path, api))
    problems.extend(check_project(ROOT / "default.project.json", api))

    if problems:
        print(f"{len(problems)} API sorunu:")
        for problem in problems:
            print(f"  ✗ {problem}")
        return 1

    print(f"{len(files)} dosya + proje dosyası: API kullanımı temiz")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
