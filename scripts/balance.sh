#!/usr/bin/env bash
# Denge raporu: sandık beklenen değerleri, rebirth eşikleri, maliyet tabloları.
#   ./scripts/balance.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LUAU="${LUAU_BIN:-luau}"

if ! command -v "$LUAU" >/dev/null 2>&1; then
	echo "luau bulunamadı. Kurulum: rokit install" >&2
	exit 127
fi

python3 "$ROOT/scripts/prepare_tests.py" >/dev/null
"$LUAU" "$ROOT/build/test/tools/balance_report.luau"
