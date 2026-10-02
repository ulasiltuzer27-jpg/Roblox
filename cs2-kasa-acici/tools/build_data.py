#!/usr/bin/env python3
"""
CS2 Kasa Açıcı - veri derleyici.

ByMykel/CSGO-API (https://github.com/ByMykel/CSGO-API) verisini indirip
uygulamanın kullandığı sıkıştırılmış js/data.js dosyasını üretir.

Kullanım:
    python3 tools/build_data.py            # verileri indirir ve js/data.js yazar
    python3 tools/build_data.py --cache D  # D klasöründeki json'ları kullanır / oraya kaydeder
"""
import argparse
import datetime
import json
import os
import re
import urllib.request

API = "https://raw.githubusercontent.com/ByMykel/CSGO-API/main/public/api/en/"
FILES = ["skins.json", "crates.json", "collections.json"]
ECON = "https://community.akamai.steamstatic.com/economy/image/"

TIER = {
    "Consumer Grade": 0, "Base Grade": 0, "Default": 0,
    "Industrial Grade": 1,
    "Mil-Spec Grade": 2, "High Grade": 2, "Distinguished": 2,
    "Restricted": 3, "Remarkable": 3, "Exceptional": 3,
    "Classified": 4, "Exotic": 4, "Superior": 4,
    "Covert": 5, "Extraordinary": 5, "Master": 5,
    "Contraband": 7,
}
KIND = {
    "skin": "s", "sticker": "k", "patch": "p", "music_kit": "m", "graffiti": "g",
    "collectible": "c", "keychain": "h", "agent": "a",
}
CAT = {
    "Rifles": "R", "Pistols": "P", "SMGs": "S", "Heavy": "H",
    "Knives": "K", "Gloves": "G", "Equipment": "E",
}
PHASE_RE = re.compile(r"^(.*?Doppler) (Phase \d|Ruby|Sapphire|Black Pearl|Emerald)$")


def load(cache):
    out = {}
    for f in FILES:
        path = os.path.join(cache, f) if cache else None
        if path and os.path.exists(path):
            with open(path, encoding="utf-8") as fh:
                out[f] = json.load(fh)
            continue
        print("indiriliyor:", API + f)
        with urllib.request.urlopen(API + f) as r:
            raw = r.read()
        if path:
            os.makedirs(cache, exist_ok=True)
            with open(path, "wb") as fh:
                fh.write(raw)
        out[f] = json.loads(raw)
    return out


def img(u):
    if not u:
        return ""
    if u.startswith(ECON):
        return "~" + u[len(ECON):]
    return u


def norm_date(d):
    """'2015/4/15' -> '2015-04-15' (sıralanabilir biçim)."""
    parts = re.split(r"[-/]", d or "")
    if len(parts) != 3:
        return d or ""
    y, m, dd = parts
    return "%s-%02d-%02d" % (y, int(m), int(dd))


def crate_type(c):
    t = c.get("type")
    kinds = {i["id"].split("-")[0] for i in (c.get("contains") or [])}
    if t == "Case":
        return "case"
    if t in ("Souvenir", "Souvenir Highlight"):
        return "souvenir"
    if t == "Sticker Capsule":
        return "sticker"
    if t == "Autograph Capsule":
        return "autograph"
    if t is None:
        if kinds == {"skin"}:
            return "case"
        if kinds == {"sticker"}:
            return "sticker"
    return "other"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", default=None)
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument("--out", default=os.path.join(here, "..", "js", "data.js"))
    a = ap.parse_args()
    d = load(a.cache)
    skins, crates, cols = d["skins.json"], d["crates.json"], d["collections.json"]

    items, index = [], {}

    def add_item(key, row):
        if key not in index:
            index[key] = len(items)
            items.append(row)
        return index[key]

    skin_ids = {}
    for s in skins:
        name = s["name"]
        tier = 6 if name.startswith("★") else TIER.get(s["rarity"]["name"], 0)
        phase = s.get("phase") or ""
        m = PHASE_RE.match(name)
        if m:
            name, phase = m.group(1), m.group(2)
        vanilla = "|" not in s["name"]
        mn = s.get("min_float")
        mx = s.get("max_float")
        if vanilla or mn is None or mx is None:
            mn, mx = -1, -1
        flags = (1 if s.get("stattrak") else 0) | (2 if s.get("souvenir") else 0)
        cat = CAT.get((s.get("category") or {}).get("name"), "E")
        row = [s["id"], name, "s", tier, img(s.get("image")), mn, mx, flags, cat, phase]
        skin_ids[s["id"]] = add_item(s["id"], row)

    def ref(it):
        iid = it["id"]
        if iid in skin_ids:
            return skin_ids[iid]
        kind = KIND.get(iid.split("-")[0], "o")
        name = it["name"]
        tier = TIER.get(it["rarity"]["name"], 0)
        flags = 1 if name.startswith("StatTrak") else 0
        key = iid + "|" + name
        return add_item(key, [key, name, kind, tier, img(it.get("image")), -1, -1, flags, "", ""])

    out_cases = []
    crate_index = {}
    for c in crates:
        cont = c.get("contains") or []
        rare = c.get("contains_rare") or []
        if not cont and not rare:
            continue
        t = crate_type(c)
        crate_index[c["id"]] = len(out_cases)
        out_cases.append({
            "i": c["id"], "n": c["name"], "t": t, "img": img(c.get("image")),
            "d": norm_date(c.get("first_sale_date")),
            "c": [ref(i) for i in cont], "r": [ref(i) for i in rare],
        })

    out_cols = []
    col_index = {}
    for col in cols:
        cont = col.get("contains") or []
        if not cont:
            continue
        kinds = {i["id"].split("-")[0] for i in cont}
        if kinds == {"graffiti"}:
            continue  # yüzlerce sprey içeren koleksiyonları atla
        refs = [ref(i) for i in cont]
        case_links = [crate_index[c["id"]] for c in col.get("crates") or [] if c["id"] in crate_index]
        col_index[col["id"]] = len(out_cols)
        out_cols.append({
            "i": col["id"], "n": col["name"], "img": img(col.get("image")),
            "d": col.get("release_date") or "", "it": refs, "cs": case_links,
        })
        has_case = any(out_cases[ci]["t"] == "case" for ci in case_links)
        if not has_case:
            out_cases.append({
                "i": "box-" + col["id"], "n": col["name"], "t": "collection",
                "img": img(col.get("image")), "d": col.get("release_date") or "",
                "c": refs, "r": [], "col": len(out_cols) - 1,
            })

    # skin -> koleksiyon eşlemesi (takas sözleşmesi için)
    item_cols = {}
    for s in skins:
        for col in s.get("collections") or []:
            if col["id"] in col_index:
                item_cols.setdefault(skin_ids[s["id"]], []).append(col_index[col["id"]])

    data = {
        "v": datetime.date.today().isoformat(),
        "econ": ECON,
        "items": items,
        "cases": out_cases,
        "cols": out_cols,
        "itemCols": item_cols,
    }
    js = "/* Otomatik üretildi: tools/build_data.py - kaynak: ByMykel/CSGO-API */\n"
    js += "window.CS2_DATA=" + json.dumps(data, ensure_ascii=False, separators=(",", ":")) + ";\n"
    with open(a.out, "w", encoding="utf-8") as fh:
        fh.write(js)
    from collections import Counter
    print("eşya:", len(items), Counter(i[2] for i in items))
    print("kasa:", len(out_cases), Counter(c["t"] for c in out_cases))
    print("koleksiyon:", len(out_cols))
    print("boyut: %.2f MB" % (len(js.encode("utf-8")) / 1e6))


if __name__ == "__main__":
    main()
