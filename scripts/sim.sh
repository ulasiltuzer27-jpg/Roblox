#!/usr/bin/env bash
# Ekonomi simülasyonu. Oyunun kendi denge dosyalarını JSON'a aktarır ve
# Python'da Monte Carlo koşar.
#
#   ./scripts/sim.sh                 tam rapor + grafikler
#   ./scripts/sim.sh --no-charts     sadece metin raporu
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LUAU="${LUAU_BIN:-luau}"

if ! command -v "$LUAU" >/dev/null 2>&1; then
	echo "luau bulunamadı. Kurulum: rokit install" >&2
	exit 127
fi

python3 "$ROOT/scripts/prepare_tests.py" >/dev/null
mkdir -p "$ROOT/build"
"$LUAU" "$ROOT/build/test/tools/export_config.luau" > "$ROOT/build/config.json"

python3 "$ROOT/sim/economy_sim.py" --config "$ROOT/build/config.json" "$@"
