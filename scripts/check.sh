#!/usr/bin/env bash
# Bütün .luau dosyalarının sözdizimini derleyerek doğrular.
#   ./scripts/check.sh
# luau-compile PATH'te değilse: LUAU_COMPILE_BIN=/yol/luau-compile ./scripts/check.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPILER="${LUAU_COMPILE_BIN:-luau-compile}"

if ! command -v "$COMPILER" >/dev/null 2>&1; then
	echo "luau-compile bulunamadı. Kurulum: rokit install  (ya da https://github.com/luau-lang/luau/releases)" >&2
	exit 127
fi

failed=0
count=0
while IFS= read -r -d '' file; do
	count=$((count + 1))
	if ! output="$("$COMPILER" --binary "$file" 2>&1 >/dev/null)"; then
		echo "✗ ${file#"$ROOT"/}"
		echo "$output"
		failed=$((failed + 1))
	fi
done < <(find "$ROOT/src" "$ROOT/tests" -name '*.luau' -print0 | sort -z)

if [ "$failed" -gt 0 ]; then
	echo "$failed / $count dosya derlenemedi"
	exit 1
fi
echo "$count dosyanın tamamı derlendi"

# Roblox API kullanımı ve referanslar: Studio olmadan yakalanabilen
# hata sınıfları (olmayan özellik, yanlış Enum, kırık require yolu).
python3 "$ROOT/scripts/check_api.py" || failed=$((failed + 1))
python3 "$ROOT/scripts/check_refs.py" || failed=$((failed + 1))

if [ "$failed" -gt 0 ]; then
	exit 1
fi

# Depodaki yer dosyası bir derleme çıktısı: kaynak değişip o yenilenmezse
# sessizce eskir ve Studio'da eski kodu açarsın. Uyar, ama hata verme.
PLACE="$ROOT/VaultHeist.rbxl"
if [ -f "$PLACE" ]; then
	NEWER="$(find "$ROOT/src" "$ROOT/default.project.json" -newer "$PLACE" -print -quit 2>/dev/null || true)"
	if [ -n "$NEWER" ]; then
		echo ""
		echo "uyarı: VaultHeist.rbxl kaynaktan eski görünüyor (${NEWER#"$ROOT"/} daha yeni)"
		echo "       ./scripts/build.sh ile yenile"
	fi
fi
