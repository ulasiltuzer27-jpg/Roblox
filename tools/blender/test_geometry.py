#!/usr/bin/env python3
"""Geometri testleri. Blender gerekmez:

    python3 tools/blender/test_geometry.py

Neyi doğruluyor:
  - yüz indeksleri geçerli, tekrar eden köşe yok
  - her kenar tam iki yüz tarafından paylaşılıyor (kapalı yüzey)
    -> açık kenar, Roblox'ta içi görünen/ışığı kaçıran model demek
  - üçgen sayısı Roblox'un mesh sınırının altında
  - ölçek makul (stud cinsinden)
"""

from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from geometry import Mesh, build_all

# Roblox tek mesh sınırı 10.000 üçgen; low-poly hedefimiz çok altında.
ROBLOX_TRIANGLE_LIMIT = 10_000
LOW_POLY_TARGET = 1_500
MIN_SIZE_STUDS = 0.4
MAX_SIZE_STUDS = 24.0

failures: list[str] = []


def check(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


def check_mesh(name: str, mesh: Mesh) -> None:
    vert_count = len(mesh.verts)

    check(vert_count > 0, f"{name}: köşe yok")
    check(len(mesh.faces) > 0, f"{name}: yüz yok")
    check(
        len(mesh.faces) == len(mesh.face_materials),
        f"{name}: yüz sayısı ({len(mesh.faces)}) malzeme sayısıyla ({len(mesh.face_materials)}) uyuşmuyor",
    )

    for face_index, face in enumerate(mesh.faces):
        check(len(face) >= 3, f"{name}: yüz {face_index} üç köşeden az")
        check(
            len(set(face)) == len(face),
            f"{name}: yüz {face_index} aynı köşeyi tekrar kullanıyor -> dejenere",
        )
        for index in face:
            check(
                0 <= index < vert_count,
                f"{name}: yüz {face_index} geçersiz köşe indeksi {index}",
            )

    # Kapalı yüzey: her kenar tam iki yüzde geçmeli.
    edges: Counter = Counter()
    for face in mesh.faces:
        for position in range(len(face)):
            a, b = face[position], face[(position + 1) % len(face)]
            edges[(min(a, b), max(a, b))] += 1

    open_edges = [edge for edge, count in edges.items() if count != 2]
    check(
        not open_edges,
        f"{name}: {len(open_edges)} kenar iki yüz tarafından paylaşılmıyor (açık yüzey)",
    )

    triangles = mesh.triangle_count()
    check(
        triangles <= ROBLOX_TRIANGLE_LIMIT,
        f"{name}: {triangles} üçgen, Roblox sınırı {ROBLOX_TRIANGLE_LIMIT}",
    )
    check(triangles <= LOW_POLY_TARGET, f"{name}: {triangles} üçgen, low-poly hedefi {LOW_POLY_TARGET}")

    size = mesh.size()
    # Kapan gibi düz nesneler bilerek ince; kural en büyük boyut için.
    check(
        MIN_SIZE_STUDS <= max(size) <= MAX_SIZE_STUDS,
        f"{name}: en büyük boyut {max(size):.2f} stud, beklenen aralık {MIN_SIZE_STUDS}-{MAX_SIZE_STUDS}",
    )
    for axis, value in zip("XYZ", size):
        check(value > 0.05, f"{name}: {axis} boyutu {value:.2f} -- neredeyse sıfır kalınlık")

    # Modeller zeminin altına sarkmamalı (kaide, sandık vb. y=0'a oturuyor).
    lowest_z = min(v[2] for v in mesh.verts)
    check(lowest_z >= -0.05, f"{name}: en alt köşe z={lowest_z:.2f}, zeminin altında")


def main() -> int:
    meshes = build_all()
    print(f"{len(meshes)} model kontrol ediliyor\n")
    print(f"{'model':16s}{'köşe':>7s}{'yüz':>7s}{'üçgen':>8s}   boyut (stud)")
    print("-" * 62)
    for name, mesh in meshes.items():
        check_mesh(name, mesh)
        size = " × ".join(f"{value:.1f}" for value in mesh.size())
        print(f"{name:16s}{len(mesh.verts):>7d}{len(mesh.faces):>7d}{mesh.triangle_count():>8d}   {size}")

    print()
    if failures:
        print(f"{len(failures)} sorun:")
        for failure in failures:
            print(f"  ✗ {failure}")
        return 1

    print("Tüm modeller kapalı yüzey, low-poly ve ölçek aralığında.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
