#!/usr/bin/env python3
"""Vault Heist low-poly modellerini Blender'da kurar ve FBX olarak çıkarır.

    blender --background --python tools/blender/make_models.py -- --out tools/blender/out

Geometri geometry.py'den geliyor ve Blender olmadan test edilebiliyor
(python3 tools/blender/test_geometry.py). Bu dosya yalnızca o veriyi
Blender'a aktarıp malzeme atıyor ve dışa aktarıyor -- yani Blender'a bağımlı
kısım bilerek ince tutuldu.

Çıkan dosyaları Studio'da: Avatar sekmesi → 3D Importer → FBX'i seç.
Import ayarları için README.md'ye bak.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    import bmesh
    import bpy
except ImportError:  # pragma: no cover
    print("Bu script Blender içinde çalışır:")
    print("  blender --background --python tools/blender/make_models.py -- --out <dizin>")
    raise SystemExit(1)

sys.path.insert(0, str(Path(__file__).resolve().parent))

from geometry import MAT_ACCENT, MAT_DARK, MAT_GLOW, MAT_METAL, Mesh, build_all

# Oyunun paletiyle aynı (src/shared/Config).
MATERIALS = {
    MAT_DARK: ("Koyu", (0.09, 0.10, 0.13, 1.0), 0.0, 0.85),
    MAT_METAL: ("Metal", (0.42, 0.45, 0.52, 1.0), 0.9, 0.35),
    MAT_ACCENT: ("Vurgu", (1.0, 0.69, 0.19, 1.0), 0.3, 0.45),
    MAT_GLOW: ("Isik", (0.48, 0.24, 1.0, 1.0), 0.0, 0.25),
}

EMISSIVE = {MAT_GLOW}


def clear_scene() -> None:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for material in list(bpy.data.materials):
        bpy.data.materials.remove(material)


def build_materials() -> dict[int, "bpy.types.Material"]:
    built = {}
    for index, (name, color, metallic, roughness) in MATERIALS.items():
        material = bpy.data.materials.new(name=f"VH_{name}")
        material.use_nodes = True
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = color
            bsdf.inputs["Metallic"].default_value = metallic
            bsdf.inputs["Roughness"].default_value = roughness
            if index in EMISSIVE:
                # Blender 4.x'te "Emission Color", eskisinde "Emission".
                emission = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
                if emission:
                    emission.default_value = color
                strength = bsdf.inputs.get("Emission Strength")
                if strength:
                    strength.default_value = 2.0
        material.diffuse_color = color
        built[index] = material
    return built


def create_object(name: str, mesh_data: Mesh, materials: dict) -> "bpy.types.Object":
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([list(v) for v in mesh_data.verts], [], [list(f) for f in mesh_data.faces])
    mesh.validate(verbose=False)

    # Kullanılan malzemeleri slotlara ekle ve yüzlere ata.
    used = sorted(set(mesh_data.face_materials))
    slot_of = {}
    for slot_index, material_index in enumerate(used):
        mesh.materials.append(materials[material_index])
        slot_of[material_index] = slot_index

    for polygon, material_index in zip(mesh.polygons, mesh_data.face_materials):
        polygon.material_index = slot_of[material_index]
        polygon.use_smooth = False  # low-poly görünüm: düz gölgeleme

    # from_pydata normalleri tutarsız bırakabiliyor; bmesh ile düzelt.
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def export_fbx(path: Path, objects: list) -> None:
    for obj in bpy.data.objects:
        obj.select_set(obj in objects)
    bpy.context.view_layer.objects.active = objects[0] if objects else None

    bpy.ops.export_scene.fbx(
        filepath=str(path),
        use_selection=True,
        apply_unit_scale=True,
        global_scale=1.0,
        apply_scale_options="FBX_SCALE_ALL",
        object_types={"MESH"},
        mesh_smooth_type="FACE",
        use_mesh_modifiers=True,
        use_triangles=True,  # Roblox zaten üçgenliyor; sürprizi burada gör
        add_leaf_bones=False,
        bake_anim=False,
        # Roblox Y-up; Blender Z-up.
        axis_forward="-Z",
        axis_up="Y",
        path_mode="COPY",
    )


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Vault Heist low-poly model üretimi")
    parser.add_argument("--out", default="tools/blender/out", help="çıktı dizini")
    parser.add_argument("--combined", action="store_true", help="hepsini tek FBX'e de yaz")
    parser.add_argument("--only", help="yalnızca bu modeli üret (ör. sandik)")
    args = parser.parse_args(argv)

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    clear_scene()
    materials = build_materials()

    meshes = build_all()
    if args.only:
        if args.only not in meshes:
            print(f"bilinmeyen model: {args.only}. Seçenekler: {', '.join(meshes)}")
            return 2
        meshes = {args.only: meshes[args.only]}

    created = []
    print("")
    print(f"{'model':16s}{'üçgen':>8s}   çıktı")
    print("-" * 56)

    for index, (name, mesh_data) in enumerate(meshes.items()):
        obj = create_object(name, mesh_data, materials)
        # Modeller üst üste binmesin (birleşik dosyada da ayrı dursun).
        obj.location = (index * 16.0, 0.0, 0.0)
        created.append(obj)

        path = out_dir / f"{name}.fbx"
        obj.location = (0.0, 0.0, 0.0)
        export_fbx(path, [obj])
        obj.location = (index * 16.0, 0.0, 0.0)
        print(f"{name:16s}{mesh_data.triangle_count():>8d}   {path}")

    if args.combined and created:
        combined = out_dir / "vault_heist_hepsi.fbx"
        export_fbx(combined, created)
        print(f"\nBirleşik dosya: {combined}")

    print(f"\n{len(created)} model yazıldı → {out_dir}")
    print("Studio: Avatar → 3D Importer → dosyayı seç (ayarlar için README.md)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
