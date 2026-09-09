#!/bin/zsh
# Compila la app de iOS con su widget y la instala en el simulador.
#
# Esto lo montaba a mano —`swiftc` y un `.app` armado a pulso, sin proyecto de
# Xcode— y era una buena idea mientras la app era un solo binario: el simulador
# no pide firma, así que no hacía falta cuenta de desarrollador para tener algo
# instalable.
#
# El widget acabó con eso. Una extensión no es un binario más dentro del
# paquete: es otro paquete con su propio identificador, sus permisos y su punto
# de extensión, embebido en `PlugIns/` y firmado aparte. Montar eso a pulso es
# reimplementar a Xcode, y un paquete mal armado no falla al compilar: falla al
# no aparecer en la galería de widgets, que es el peor error posible —el que no
# dice nada—.
#
# Así que un solo camino: el mismo proyecto y el mismo `xcodebuild` que el
# teléfono, cambiando solo el destino. Para el simulador sigue sin hacer falta
# firma de verdad.
set -euo pipefail
cd "$(dirname "$0")/.."

: ${DEVELOPER_DIR:=/Applications/Xcode-beta.app/Contents/Developer}
export DEVELOPER_DIR
: ${DERIVED:=build/ios-sim}
DESTINO="${1:-iPhone 17}"

command -v xcodegen >/dev/null || {
    echo "hace falta xcodegen:  brew install xcodegen" >&2; exit 1; }

echo "▸ Proyecto…"
xcodegen generate --quiet

echo "▸ Compilando app y widget…"
xcodebuild -project Pauta.xcodeproj -scheme Pauta \
    -destination "platform=iOS Simulator,name=$DESTINO" \
    -derivedDataPath "$DERIVED" -quiet build

APP="$DERIVED/Build/Products/Debug-iphonesimulator/Pauta.app"
[[ -d "$APP/PlugIns/PautaWidget.appex" ]] || {
    echo "el widget no está en el paquete: algo se rompió en el proyecto" >&2; exit 1; }

echo "▸ Simulador «$DESTINO»…"
UDID=$(xcrun simctl list devices available -j \
    | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin)["devices"]; print(next(x["udid"] for v in d.values() for x in v if x["name"]==sys.argv[1]))' "$DESTINO")
ESTADO=$(xcrun simctl list devices -j \
    | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin)["devices"]; print(next(x["state"] for v in d.values() for x in v if x["udid"]==sys.argv[1]))' "$UDID")
[[ "$ESTADO" == "Booted" ]] || xcrun simctl boot "$UDID"
xcrun simctl install "$UDID" "$APP"

echo
echo "✓ $APP instalada en $DESTINO"
echo "  para abrirla:  xcrun simctl launch $UDID dev.jadrdev.pauta"
echo "  el widget:     mantén pulsada la pantalla de inicio ▸ Añadir widget ▸ Pauta"
