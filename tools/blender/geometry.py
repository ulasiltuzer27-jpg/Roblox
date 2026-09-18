"""Low-poly model geometrisi -- saf Python, Blender gerektirmez.

Neden ayrı: bpy operatörleriyle model kurmak Blender olmadan test edilemez.
Köşe ve yüz listelerini burada üretip test ederek (kapalı yüzey mi, üçgen
sayısı Roblox sınırında mı, ölçek doğru mu) Blender'a sadece hazır veriyi
veriyoruz. make_models.py bu modülü çağırıyor.

Koordinat düzeni Blender'ın yerlisi: Z yukarı. FBX dışa aktarımında
Roblox için Y-up'a çevriliyor.

Ölçek: 1 birim = 1 stud.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

Vec3 = tuple[float, float, float]
Face = tuple[int, ...]


@dataclass
class Mesh:
    """Köşe/yüz listesi ve yüz başına malzeme indeksi."""

    verts: list[Vec3] = field(default_factory=list)
    faces: list[Face] = field(default_factory=list)
    face_materials: list[int] = field(default_factory=list)

    def add(
        self,
        verts: list[Vec3],
        faces: list[Face],
        material: int = 0,
        offset: Vec3 = (0.0, 0.0, 0.0),
        rotation_z: float = 0.0,
        scale: Vec3 | float = 1.0,
    ) -> None:
        """Bir parçayı ağa ekler; köşe indeksleri kaydırılır."""
        base = len(self.verts)
        if isinstance(scale, (int, float)):
            scale = (float(scale), float(scale), float(scale))

        cos_z, sin_z = math.cos(rotation_z), math.sin(rotation_z)
        for x, y, z in verts:
            x, y, z = x * scale[0], y * scale[1], z * scale[2]
            rx = x * cos_z - y * sin_z
            ry = x * sin_z + y * cos_z
            self.verts.append((rx + offset[0], ry + offset[1], z + offset[2]))

        for face in faces:
            self.faces.append(tuple(index + base for index in face))
            self.face_materials.append(material)

    def rotate_x(self, angle: float) -> None:
        """Tüm ağı X ekseninde döndürür (yatan diski ayağa kaldırmak için)."""
        cos_a, sin_a = math.cos(angle), math.sin(angle)
        self.verts = [(x, y * cos_a - z * sin_a, y * sin_a + z * cos_a) for x, y, z in self.verts]

    def ground(self) -> None:
        """En alt köşeyi z = 0'a oturtur."""
        lowest = min(v[2] for v in self.verts)
        if abs(lowest) > 1e-9:
            self.verts = [(x, y, z - lowest) for x, y, z in self.verts]

    def triangle_count(self) -> int:
        """Üçgenlenmiş hâlindeki üçgen sayısı (n-gen -> n-2 üçgen)."""
        return sum(len(face) - 2 for face in self.faces)

    def bounds(self) -> tuple[Vec3, Vec3]:
        xs = [v[0] for v in self.verts]
        ys = [v[1] for v in self.verts]
        zs = [v[2] for v in self.verts]
        return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))

    def size(self) -> Vec3:
        low, high = self.bounds()
        return (high[0] - low[0], high[1] - low[1], high[2] - low[2])


# ---------------------------------------------------------------------------
# İlkel şekiller
# ---------------------------------------------------------------------------


def box(width: float, depth: float, height: float, center: Vec3 = (0, 0, 0)):
    """Merkezi verilen kutu. 8 köşe, 6 dörtgen."""
    hw, hd, hh = width / 2, depth / 2, height / 2
    cx, cy, cz = center
    verts = [
        (cx - hw, cy - hd, cz - hh),
        (cx + hw, cy - hd, cz - hh),
        (cx + hw, cy + hd, cz - hh),
        (cx - hw, cy + hd, cz - hh),
        (cx - hw, cy - hd, cz + hh),
        (cx + hw, cy - hd, cz + hh),
        (cx + hw, cy + hd, cz + hh),
        (cx - hw, cy + hd, cz + hh),
    ]
    faces = [
        (0, 1, 2, 3),  # alt
        (7, 6, 5, 4),  # üst
        (0, 4, 5, 1),  # ön
        (1, 5, 6, 2),  # sağ
        (2, 6, 7, 3),  # arka
        (3, 7, 4, 0),  # sol
    ]
    return verts, faces


def frustum(
    bottom_radius: float,
    top_radius: float,
    height: float,
    segments: int = 10,
    center: Vec3 = (0, 0, 0),
):
    """Kesik koni (top_radius = bottom_radius ise silindir)."""
    cx, cy, cz = center
    hh = height / 2
    verts: list[Vec3] = []

    for index in range(segments):
        angle = index / segments * math.tau
        verts.append((cx + math.cos(angle) * bottom_radius, cy + math.sin(angle) * bottom_radius, cz - hh))
    for index in range(segments):
        angle = index / segments * math.tau
        verts.append((cx + math.cos(angle) * top_radius, cy + math.sin(angle) * top_radius, cz + hh))

    faces: list[Face] = []
    for index in range(segments):
        nxt = (index + 1) % segments
        faces.append((index, nxt, segments + nxt, segments + index))

    # Kapaklar n-gen: her kenar tam iki yüz tarafından paylaşılır.
    faces.append(tuple(reversed(range(segments))))
    faces.append(tuple(range(segments, segments * 2)))
    return verts, faces


def cylinder(radius: float, height: float, segments: int = 10, center: Vec3 = (0, 0, 0)):
    return frustum(radius, radius, height, segments, center)


def bipyramid(radius: float, top_height: float, bottom_height: float, segments: int = 6, center: Vec3 = (0, 0, 0)):
    """Kristal/mücevher şekli: ortada halka, üstte ve altta tepe noktası."""
    cx, cy, cz = center
    verts: list[Vec3] = []
    for index in range(segments):
        angle = index / segments * math.tau
        verts.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius, cz))
    apex_top = len(verts)
    verts.append((cx, cy, cz + top_height))
    apex_bottom = len(verts)
    verts.append((cx, cy, cz - bottom_height))

    faces: list[Face] = []
    for index in range(segments):
        nxt = (index + 1) % segments
        faces.append((index, nxt, apex_top))
        faces.append((nxt, index, apex_bottom))
    return verts, faces


def ring(outer: float, inner: float, height: float, segments: int = 12, center: Vec3 = (0, 0, 0)):
    """İçi boş halka (kasa kapısının çerçevesi)."""
    cx, cy, cz = center
    hh = height / 2
    verts: list[Vec3] = []
    for radius in (outer, inner):
        for level in (-hh, hh):
            for index in range(segments):
                angle = index / segments * math.tau
                verts.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius, cz + level))

    def idx(radius_index: int, level_index: int, segment: int) -> int:
        return (radius_index * 2 + level_index) * segments + segment % segments

    faces: list[Face] = []
    for index in range(segments):
        nxt = (index + 1) % segments
        # dış yüzey
        faces.append((idx(0, 0, index), idx(0, 0, nxt), idx(0, 1, nxt), idx(0, 1, index)))
        # iç yüzey (ters yön)
        faces.append((idx(1, 1, index), idx(1, 1, nxt), idx(1, 0, nxt), idx(1, 0, index)))
        # alt ve üst yüzükler
        faces.append((idx(0, 0, nxt), idx(0, 0, index), idx(1, 0, index), idx(1, 0, nxt)))
        faces.append((idx(0, 1, index), idx(0, 1, nxt), idx(1, 1, nxt), idx(1, 1, index)))
    return verts, faces


# ---------------------------------------------------------------------------
# Modeller
# ---------------------------------------------------------------------------

# Malzeme indeksleri (make_models.py bunları renklere bağlıyor)
MAT_DARK = 0
MAT_METAL = 1
MAT_ACCENT = 2
MAT_GLOW = 3


def crate() -> Mesh:
    """Sandık: gövde + kapak + metal bantlar + kilit. ~4 stud."""
    mesh = Mesh()
    mesh.add(*box(4.0, 3.0, 2.2, (0, 0, 1.1)), material=MAT_DARK)
    mesh.add(*box(4.1, 3.1, 0.9, (0, 0, 2.6)), material=MAT_DARK)

    # Bantlar gövdenin altından kapağın üstüne: 0 -> 3.05
    for offset in (-1.3, 1.3):
        mesh.add(*box(0.35, 3.2, 3.05, (offset, 0, 1.525)), material=MAT_METAL)
    mesh.add(*box(4.2, 0.3, 0.35, (0, 0, 2.15)), material=MAT_METAL)

    # Kilit
    mesh.add(*box(0.8, 0.35, 0.8, (0, -1.6, 2.3)), material=MAT_ACCENT)
    return mesh


def vault_door() -> Mesh:
    """Kasa kapısı: çerçeve halkası + kapı diski + çark + ışıklı göstergeler."""
    mesh = Mesh()
    mesh.add(*ring(6.0, 4.6, 1.6, 16), material=MAT_METAL, rotation_z=0)
    mesh.add(*cylinder(4.6, 1.0, 16, (0, 0, 0)), material=MAT_DARK)
    mesh.add(*cylinder(1.5, 1.3, 12, (0, 0, 0.5)), material=MAT_METAL)

    # Çark kolları
    for index in range(4):
        angle = index / 4 * math.tau
        mesh.add(
            *box(2.6, 0.4, 0.4, (0, 0, 0)),
            material=MAT_METAL,
            offset=(math.cos(angle) * 1.3, math.sin(angle) * 1.3, 0.9),
            rotation_z=angle,
        )

    # Göstergeler
    for index in range(6):
        angle = index / 6 * math.tau
        mesh.add(
            *cylinder(0.28, 0.3, 8, (0, 0, 0)),
            material=MAT_GLOW,
            offset=(math.cos(angle) * 3.4, math.sin(angle) * 3.4, 0.6),
        )

    # Disk olarak kuruldu; kapı olarak kullanılacağı için ayağa kaldırılıp
    # zemine oturtuluyor. Studio'da olduğu gibi yerleştirilebilsin.
    mesh.rotate_x(math.pi / 2)
    mesh.ground()
    return mesh


def laser_emitter() -> Mesh:
    """Lazer yayıcı: duvara monte kaide + namlu + lens."""
    mesh = Mesh()
    mesh.add(*box(1.4, 1.4, 0.5, (0, 0, 0.25)), material=MAT_DARK)
    mesh.add(*frustum(0.55, 0.32, 1.1, 10, (0, 0, 1.05)), material=MAT_METAL)
    mesh.add(*cylinder(0.3, 0.16, 10, (0, 0, 1.68)), material=MAT_GLOW)
    return mesh


def crystal() -> Mesh:
    """Hazine kristali. Nadirliğe göre renklendirilecek tek parça."""
    mesh = Mesh()
    mesh.add(*bipyramid(0.85, 1.5, 0.9, 6, (0, 0, 1.0)), material=MAT_GLOW)
    return mesh


def pedestal() -> Mesh:
    """Hazine kaidesi: taban + gövde + üst tabla + ışık şeridi."""
    mesh = Mesh()
    mesh.add(*cylinder(1.1, 0.35, 12, (0, 0, 0.175)), material=MAT_DARK)
    mesh.add(*frustum(0.75, 0.55, 1.6, 12, (0, 0, 1.15)), material=MAT_DARK)
    mesh.add(*cylinder(0.95, 0.25, 12, (0, 0, 2.08)), material=MAT_METAL)
    mesh.add(*cylinder(0.98, 0.08, 12, (0, 0, 2.24)), material=MAT_GLOW)
    return mesh


def trap_plate() -> Mesh:
    """Basınç kapanı: zemine gömülü plaka + çerçeve."""
    mesh = Mesh()
    mesh.add(*ring(1.9, 1.5, 0.2, 12, (0, 0, 0.1)), material=MAT_METAL)
    mesh.add(*cylinder(1.5, 0.14, 12, (0, 0, 0.07)), material=MAT_ACCENT)
    return mesh


MODELS = {
    "sandik": crate,
    "kasa_kapisi": vault_door,
    "lazer_yayici": laser_emitter,
    "kristal": crystal,
    "kaide": pedestal,
    "kapan": trap_plate,
}


def build_all() -> dict[str, Mesh]:
    return {name: builder() for name, builder in MODELS.items()}
