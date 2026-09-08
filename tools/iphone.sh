#!/bin/zsh
# Instala la app en un iPhone conectado por cable.
#
# A diferencia del simulador, un dispositivo exige firma: certificado de
# desarrollo, un perfil de aprovisionamiento con el UDID del teléfono dentro, y
# el modo de desarrollador activado en el propio teléfono
# (Ajustes ▸ Privacidad y seguridad ▸ Modo de desarrollador).
#
# El perfil lo crea Xcode contra la cuenta que tengas registrada. Con un equipo
# **gratuito** dura siete días: pasados, la app deja de abrirse y hay que volver
# a ejecutar esto. Sin límite, con la cuenta de pago.
set -euo pipefail
cd "$(dirname "$0")/.."

: ${DEVELOPER_DIR:=/Applications/Xcode-beta.app/Contents/Developer}
export DEVELOPER_DIR
: ${DERIVED:=build/ios-device}

command -v xcodegen >/dev/null || {
    echo "hace falta xcodegen:  brew install xcodegen" >&2; exit 1; }

# El primer iPhone físico y conectado. El UDID no se escribe a mano: cambia de
# teléfono y de cable, y un UDID pegado en un guion caduca sin avisar.
UDID=$(xcrun devicectl list devices --json-output /dev/stdout --quiet 2>/dev/null \
    | /usr/bin/python3 -c '
import json, sys
for x in json.load(sys.stdin)["result"]["devices"]:
    h = x.get("hardwareProperties", {})
    c = x.get("connectionProperties", {})
    # «physical» descarta los simuladores, que también son iPhone para devicectl
    # y aparecen conectados: sin este filtro se instala en el simulador y el
    # error que sale habla de rutas que no existen.
    if (h.get("deviceType") == "iPhone" and h.get("reality") == "physical"
            and c.get("tunnelState") == "connected"):
        print(h["udid"]); break
')
[[ -n "$UDID" ]] || { echo "no veo ningún iPhone conectado" >&2; exit 1; }
echo "▸ iPhone $UDID"

xcodegen generate --quiet
xcodebuild -project Pauta.xcodeproj -scheme Pauta -destination "id=$UDID" \
    -derivedDataPath "$DERIVED" -allowProvisioningUpdates -quiet build

APP="$DERIVED/Build/Products/Debug-iphoneos/Pauta.app"
xcrun devicectl device install app --device "$UDID" "$APP" | grep -E "bundleID|App installed"
# Lanzar exige el teléfono desbloqueado; si está bloqueado, se abre a mano.
xcrun devicectl device process launch --device "$UDID" dev.jadrdev.pauta >/dev/null 2>&1 \
    && echo "· abierta en el teléfono" \
    || echo "· instalada; ábrela tú (el teléfono estaba bloqueado)"

echo
echo "⚠︎ Con equipo gratuito el perfil caduca en 7 días: al octavo, vuelve a"
echo "  ejecutar esto o la app dejará de abrirse."
