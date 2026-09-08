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
INFO=$(xcrun devicectl list devices --json-output /dev/stdout --quiet 2>/dev/null \
    | /usr/bin/python3 -c '
import json, sys

# Qué cuenta como «ese iPhone está delante». Ha costado dos intentos:
#
#   · `physical` descarta los simuladores, que también son iPhone para
#     devicectl y aparecen conectados. Sin esto se instala en el simulador y el
#     error habla de rutas que no existen.
#   · `tunnelState` **no** vale por sí solo: es el túnel de depuración, se
#     duerme y solo despierta cuando algo le habla. Por cable suele estar
#     dormido, y un teléfono enchufado se declaraba ausente.
#   · `transportType == wired` tampoco: por Wi-Fi el mismo teléfono aparece
#     como `localNetwork`, y volvía a declararse ausente con la app en la mano.
#
# Lo que decide es que esté **emparejado** y alcanzable de alguna forma. El
# cable primero, que es más rápido y no depende de la red.
def puntos(x):
    c = x.get("connectionProperties", {})
    return (2 if c.get("transportType") == "wired" else
            1 if c.get("tunnelState") == "connected" else 0)

candidatos = [x for x in json.load(sys.stdin)["result"]["devices"]
              if x.get("hardwareProperties", {}).get("deviceType") == "iPhone"
              and x.get("hardwareProperties", {}).get("reality") == "physical"
              and x.get("connectionProperties", {}).get("pairingState") == "paired"
              and puntos(x) > 0]
if candidatos:
    mejor = max(candidatos, key=puntos)
    print(mejor["hardwareProperties"]["udid"],
          mejor.get("deviceProperties", {}).get("name", "iPhone"),
          mejor.get("connectionProperties", {}).get("transportType", "?"))
')
UDID=${INFO%% *}
[[ -n "$UDID" ]] || {
    echo "no veo ningún iPhone emparejado y alcanzable" >&2
    echo "  (enchúfalo, o compruébalo con: xcrun devicectl list devices)" >&2
    exit 1
}
echo "▸ ${INFO#* }  ·  $UDID"

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
