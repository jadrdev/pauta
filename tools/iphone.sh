#!/bin/zsh
# Instala la app en un iPhone conectado por cable.
#
# A diferencia del simulador, un dispositivo exige firma: certificado de
# desarrollo, un perfil de aprovisionamiento con el UDID del teléfono dentro, y
# el modo de desarrollador activado en el propio teléfono
# (Ajustes ▸ Privacidad y seguridad ▸ Modo de desarrollador).
#
# El perfil lo crea Xcode contra la cuenta que tengas registrada, y cuánto dura
# depende de ella: con un equipo gratuito, siete días; con membresía de pago, un
# año. No se afirma aquí cuál es tu caso —se lee del perfil que quedó dentro del
# paquete y se dice al final—, que un comentario con una fecha inventada es
# exactamente cómo se acaba creyendo que la app caduca el martes.
set -euo pipefail
cd "$(dirname "$0")/.."

. tools/xcode.sh
: ${DERIVED:=build/ios-device}

command -v xcodegen >/dev/null || {
    echo "hace falta xcodegen:  brew install xcodegen" >&2; exit 1; }

# El primer iPhone físico y conectado. El UDID no se escribe a mano: cambia de
# teléfono y de cable, y un UDID pegado en un guion caduca sin avisar.
INFO=$(xcrun devicectl list devices --json-output /dev/stdout --quiet 2>/dev/null \
    | /usr/bin/python3 -c '
import json, sys

# Vale **cualquier iPhone físico emparejado**, y esta es la tercera versión de
# este filtro. Las dos anteriores intentaban adivinar si estaba alcanzable a
# partir de la foto que da `devicectl`, y las dos se equivocaron:
#
#   · `tunnelState == connected` — es el túnel de depuración: se duerme y solo
#     despierta cuando algo le habla. Por cable suele estar dormido.
#   · `transportType == wired` — por Wi-Fi el mismo teléfono es `localNetwork`.
#
# Y por red puede estar emparejado, despierto y con el túnel caído a la vez. Ese
# estado no se puede leer sin intentar hablarle, así que no se lee: se elige el
# mejor candidato y **que decida el intento de instalar**, que sabe más que
# nosotros y da un error de verdad si no llega. `physical` se queda, que sin él
# se instala en el simulador y el error habla de rutas que no existen.
def puntos(x):
    c = x.get("connectionProperties", {})
    return ((2 if c.get("transportType") == "wired" else 0)
            + (1 if c.get("tunnelState") == "connected" else 0))

candidatos = [x for x in json.load(sys.stdin)["result"]["devices"]
              if x.get("hardwareProperties", {}).get("deviceType") == "iPhone"
              and x.get("hardwareProperties", {}).get("reality") == "physical"
              and x.get("connectionProperties", {}).get("pairingState") == "paired"]
if candidatos:
    mejor = max(candidatos, key=puntos)
    print(mejor["hardwareProperties"]["udid"],
          mejor.get("deviceProperties", {}).get("name", "iPhone"),
          mejor.get("connectionProperties", {}).get("transportType", "?"))
')
UDID=${INFO%% *}
[[ -n "$UDID" ]] || {
    echo "no hay ningún iPhone emparejado con este Mac" >&2
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

# Cuándo deja de abrirse, según el perfil que se acaba de embeber y no según lo
# que creamos recordar de la cuenta.
PERFIL=$(mktemp)
if security cms -D -i "$APP/embedded.mobileprovision" > "$PERFIL" 2>/dev/null; then
    CADUCA=$(/usr/libexec/PlistBuddy -c 'Print :ExpirationDate' "$PERFIL" 2>/dev/null || true)
    echo
    echo "· el perfil de este build caduca el ${CADUCA:-?}"
    echo "  pasada esa fecha la app deja de abrirse: vuelve a ejecutar esto"
fi
rm -f "$PERFIL"
