#!/bin/bash
# Recompila y relanza Pauta.
set -euo pipefail
cd "$(dirname "$0")"
./build.sh "${1:-release}"
pkill -x Pauta 2>/dev/null || true
open build/Pauta.app
