#!/bin/zsh
# Sube la app del teléfono —con su widget y la app del reloj dentro— a App
# Store Connect, de donde sale para TestFlight.
#
# Es el relevo de `iphone.sh` para todo lo que no sea probar en el momento:
# por cable, el perfil de desarrollo caduca al año, el teléfono tiene que estar
# a mano y desbloqueado, y el reloj se queda con lo que traiga el teléfono. Con
# TestFlight, la compilación llega al iPhone y al iPad desde la nube y se
# actualiza sola.
#
# Lo que pide, una vez:
#
#   · La app creada en App Store Connect con el identificador
#     dev.jadrdev.pauta.
#   · Tu cuenta en Xcode ▸ Ajustes ▸ Cuentas: la subida va con ella, igual que
#     en el organizador.
#
# Cada subida necesita un número de compilación que no se haya subido antes
# —`CURRENT_PROJECT_VERSION` en project.yml—. Apple lo rechaza si se repite, y
# lo dice en la subida, no antes.
#
#   tools/testflight.sh            archiva, exporta y sube
#   tools/testflight.sh --sin-subir  lo mismo, pero se queda en el .ipa
set -euo pipefail
cd "$(dirname "$0")/.."

# Ninguna versión con textos sin traducir: en catalán o en inglés saldrían en
# español sin que nada avise. Si falla, `tools/textos.sh` dice cuáles son.
/usr/bin/python3 tools/textos-comprobar.py

. tools/xcode.sh
ARCHIVO=build/PautaIOS.xcarchive
SALIDA=build/ios-export

DESTINO=upload
[[ "${1:-}" == "--sin-subir" ]] && DESTINO=export

command -v xcodegen >/dev/null || {
    echo "hace falta xcodegen:  brew install xcodegen" >&2; exit 1; }

echo "▸ Proyecto…"
xcodegen generate --quiet

VERSION=$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)
COMPILACION=$(sed -n 's/^ *CURRENT_PROJECT_VERSION: "\(.*\)"/\1/p' project.yml)
echo "▸ Archivando $VERSION ($COMPILACION)…"
rm -rf "$ARCHIVO" "$SALIDA"
xcodebuild -project Pauta.xcodeproj -scheme Pauta -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVO" \
    -derivedDataPath build/ios-archive -allowProvisioningUpdates -quiet archive

# Las opciones son las del archivo, cambiando solo a dónde va: así lo que se
# prueba con --sin-subir es exactamente lo que se sube.
OPCIONES=build/ExportOptions-appstore.plist
cp tools/ExportOptions-appstore.plist "$OPCIONES"
/usr/libexec/PlistBuddy -c "Set :destination $DESTINO" "$OPCIONES"

if [[ "$DESTINO" == upload ]]; then
    echo "▸ Firmando y subiendo a App Store Connect…"
else
    echo "▸ Firmando para la App Store, sin subir…"
fi
xcodebuild -exportArchive -archivePath "$ARCHIVO" -exportOptionsPlist "$OPCIONES" \
    -exportPath "$SALIDA" -allowProvisioningUpdates -quiet

if [[ "$DESTINO" == upload ]]; then
    echo "✓ Subida $VERSION ($COMPILACION)."
    echo "  Apple la procesa unos minutos antes de que salga en TestFlight;"
    echo "  llega un correo cuando está lista."
else
    echo "✓ $SALIDA/Pauta.ipa  ($VERSION, $COMPILACION)"
fi
