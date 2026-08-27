#!/bin/bash
# Recompila y relanza Pauta.
set -euo pipefail
cd "$(dirname "$0")"
./build.sh "${1:-release}"
pkill -x Pauta 2>/dev/null || true
# Espera a que el proceso muera del todo: `open` inmediato tras `pkill` falla
# a veces con -600 (LaunchServices aún ve la instancia anterior).
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x Pauta >/dev/null || break
    sleep 0.2
done
open build/Pauta.app || { sleep 1; open build/Pauta.app; }
