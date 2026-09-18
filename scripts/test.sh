#!/usr/bin/env bash
# Saf oynanış matematiğinin testleri. Roblox Studio gerekmez.
#   ./scripts/test.sh
# Luau ikilisi PATH'te değilse: LUAU_BIN=/yol/luau ./scripts/test.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LUAU="${LUAU_BIN:-luau}"

if ! command -v "$LUAU" >/dev/null 2>&1; then
	echo "luau bulunamadı. Kurulum: rokit install  (ya da https://github.com/luau-lang/luau/releases)" >&2
	exit 127
fi

python3 "$ROOT/scripts/prepare_tests.py"
"$LUAU" "$ROOT/build/test/run.luau"

# Blender model geometrisi (Blender gerekmez)
echo ""
python3 "$ROOT/tools/blender/test_geometry.py"
