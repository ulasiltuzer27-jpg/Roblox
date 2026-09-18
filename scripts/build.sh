#!/usr/bin/env bash
# Oynanabilir yer dosyasını üretir.
#
#   ./scripts/build.sh            VaultHeist.rbxl  (ikili, Studio'da çift tıkla aç)
#   ./scripts/build.sh --xml      VaultHeist.rbxlx (XML, git'te satır satır okunur)
#
# rojo PATH'te değilse: ROJO_BIN=/yol/rojo ./scripts/build.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROJO="${ROJO_BIN:-rojo}"

if ! command -v "$ROJO" >/dev/null 2>&1; then
	echo "rojo bulunamadı. Kurulum: rokit install  (ya da https://github.com/rojo-rbx/rojo/releases)" >&2
	exit 127
fi

OUTPUT="$ROOT/VaultHeist.rbxl"
if [ "${1:-}" = "--xml" ]; then
	OUTPUT="$ROOT/VaultHeist.rbxlx"
fi

"$ROJO" build "$ROOT/default.project.json" -o "$OUTPUT"

SIZE="$(du -h "$OUTPUT" | cut -f1)"
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo 'commit yok')"
echo "$(basename "$OUTPUT")  ·  $SIZE  ·  kaynak: $COMMIT"
echo ""
echo "Studio'da aç, F5 ile başlat. Açılış kontrolü Output'a düşecek."
echo "Kaynak değiştikten sonra bu dosyayı yeniden üretmeyi unutma."
