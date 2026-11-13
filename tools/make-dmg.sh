#!/bin/zsh
# Empaqueta la app en un .dmg listo para descargar: firmado con Developer ID y
# notarizado, para que se abra en cualquier Mac sin quitarle la cuarentena.
#
# El disco lleva dos cosas y nada más: la app y un enlace a /Applications, que es
# el gesto que todo el mundo en macOS conoce —arrastrar de un icono al otro—. Sin
# fondo dibujado ni ventana colocada a mano: eso exige guionizar el Finder, que
# falla en cuanto se ejecuta sin sesión gráfica delante, y no aporta nada que el
# usuario no sepa hacer ya.
#
# Lo que necesita, una vez por Mac (los detalles en docs/compilar.md):
#
#   · El certificado «Developer ID Application» del equipo en el llavero.
#   · La contraseña de notarización guardada con el nombre de PERFIL:
#       xcrun notarytool store-credentials pauta-notario \
#           --apple-id <tu Apple ID> --team-id 26W4G92PSS
#
# Sin el certificado cae a la firma de desarrollo de antes y lo dice; sin la
# contraseña **se para**: un disco con Developer ID sin notarizar se bloquea
# igual en otro Mac, y publicarlo sería creer que ya no hace falta la
# cuarentena cuando sí hace.
set -euo pipefail
cd "$(dirname "$0")/.."

# Ninguna versión con textos sin traducir: en catalán o en inglés saldrían en
# español sin que nada avise. Si falla, `tools/textos.sh` dice cuáles son.
/usr/bin/python3 tools/textos-comprobar.py

. tools/xcode.sh
EQUIPO=26W4G92PSS
PERFIL=${PERFIL:-pauta-notario}
IDENTIDAD="Developer ID Application"

# Por su huella y no por su nombre: en el llavero hay certificados de más de un
# equipo, y un nombre a medias puede casar con el que no es.
HUELLA=$(security find-identity -v -p codesigning \
    | awk -v q="\"$IDENTIDAD: " -v e="($EQUIPO)\"" 'index($0, q) && index($0, e) {print $2; exit}')
if [[ -n "$HUELLA" ]]; then
    CON_DEVELOPER_ID=1
else
    CON_DEVELOPER_ID=0
fi

if (( CON_DEVELOPER_ID )); then
    # Antes de compilar nada: descubrir al final, tras cinco minutos, que falta
    # la contraseña es la forma cara de descubrirlo.
    xcrun notarytool history --keychain-profile "$PERFIL" >/dev/null 2>&1 || {
        echo "no está guardada la contraseña de notarización «$PERFIL»:" >&2
        echo "  xcrun notarytool store-credentials $PERFIL --apple-id <tu Apple ID> --team-id $EQUIPO" >&2
        exit 1
    }

    # Archivar y exportar, como lo haría el organizador de Xcode, y no firmar a
    # mano: al exportar para Developer ID, Xcode pide a Apple los perfiles de
    # esa distribución —la app y el widget llevan un grupo, y el widget en
    # sandbox no arranca sin perfil que lo autorice— y vuelve a firmar el
    # paquete entero, de dentro afuera, con el sello de hora.
    echo "▸ Proyecto…"
    xcodegen generate --quiet
    echo "▸ Archivando…"
    rm -rf build/Pauta.xcarchive build/export
    xcodebuild -project Pauta.xcodeproj -scheme PautaMac -configuration Release \
        -destination 'generic/platform=macOS' -archivePath build/Pauta.xcarchive \
        -derivedDataPath build/mac-dd -allowProvisioningUpdates -quiet archive
    echo "▸ Exportando para Developer ID…"
    xcodebuild -exportArchive -archivePath build/Pauta.xcarchive \
        -exportOptionsPlist tools/ExportOptions-devid.plist \
        -exportPath build/export -allowProvisioningUpdates -quiet
    APP=build/export/Pauta.app
else
    ./build.sh
    APP=build/Pauta.app
fi

[ -d "$APP/Contents/PlugIns/PautaWidget.appex" ] || {
    echo "el widget no está en el paquete: algo se rompió en el proyecto" >&2; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    "$APP/Contents/Info.plist")
STAGE="build/dmg"
DMG="build/Pauta-$VERSION.dmg"

# Manda el archivo a Apple y espera el veredicto. Si no es «Accepted», enseña el
# informe: dice qué binario y qué falta, que es lo único útil en ese momento.
notarizar() {
    local archivo=$1 salida id estado
    salida=$(xcrun notarytool submit "$archivo" --keychain-profile "$PERFIL" \
        --wait --output-format json)
    id=$(print -r -- "$salida" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
    estado=$(print -r -- "$salida" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])')
    if [[ "$estado" != "Accepted" ]]; then
        echo "Apple no lo ha aceptado ($estado):" >&2
        xcrun notarytool log "$id" --keychain-profile "$PERFIL" >&2 || true
        exit 1
    fi
}

if (( CON_DEVELOPER_ID )); then
    # La app se notariza y se grapa **ella**, no solo el disco: Homebrew la
    # saca del disco y la deja en Aplicaciones, y el ticket grapado viaja con
    # ella. Sin él, la primera vez que se abre Gatekeeper pregunta a Apple por
    # red, y sin red no la deja abrir.
    echo "▸ Notarizando la app (tarda un par de minutos)…"
    ditto -c -k --keepParent "$APP" build/Pauta-notarizar.zip
    notarizar build/Pauta-notarizar.zip
    rm -f build/Pauta-notarizar.zip
    xcrun stapler staple -q "$APP"
fi

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Pauta.app"
ln -s /Applications "$STAGE/Applications"

echo "▸ Creando $DMG…"
hdiutil create -volname "Pauta $VERSION" -srcfolder "$STAGE" \
    -ov -format UDZO -quiet "$DMG"
rm -rf "$STAGE"

if (( CON_DEVELOPER_ID )); then
    # Y el disco también, que es lo que se descarga y lo que Gatekeeper mira
    # primero al abrirlo.
    codesign -s "$HUELLA" --timestamp "$DMG"
    echo "▸ Notarizando el disco…"
    notarizar "$DMG"
    xcrun stapler staple -q "$DMG"

    # La prueba de verdad: lo que diría Gatekeeper en el Mac de otro.
    spctl -a -t open --context context:primary-signature "$DMG" 2>/dev/null \
        && spctl -a -t exec "$APP" 2>/dev/null \
        || { echo "Gatekeeper rechaza el resultado:" >&2
             spctl -a -vv -t exec "$APP" >&2 || true; exit 1; }
    echo "✓ Firmada con Developer ID, notarizada y grapada: se abre en cualquier Mac."

    # La copia exportada no se deja suelta: dos Pauta.app con la misma firma en
    # el disco son dos apps para el sistema de avisos (ver «Una sola copia»).
    rm -rf build/export
else
    # La advertencia importa más que el paquete. Firmado solo con un certificado
    # de desarrollo, el disco se abre aquí y en ningún otro Mac: Gatekeeper
    # exige «Developer ID Application» **y** notarización para lo que se
    # descarga de internet, y sin las dos cosas el sistema dice que la app está
    # dañada, que es un mensaje que asusta y no explica nada.
    echo "⚠︎ Firmada solo con un certificado de desarrollo: no hay «$IDENTIDAD»"
    echo "  del equipo $EQUIPO en el llavero. En otro Mac Gatekeeper la bloqueará"
    echo "  hasta que se le quite la cuarentena:"
    echo "      xattr -dr com.apple.quarantine /Applications/Pauta.app"
fi

SHA=$(shasum -a 256 "$DMG" | cut -d' ' -f1)

echo
echo "✓ $DMG  ($(du -h "$DMG" | cut -f1))"
echo "  sha256: $SHA"

# El cask ya relleno, para no copiar a mano una versión y un hash de sesenta y
# cuatro caracteres. Escribirlos a mano es exactamente cómo se publica un cask
# que baja el archivo bueno y se niega a instalarlo porque el hash no cuadra.
echo
echo "▸ Para el tap (jadrdev/homebrew-pauta, Casks/pauta.rb):"
cat <<CASK
  version "$VERSION"
  sha256 "$SHA"
CASK
echo "  y publica la release con la etiqueta v$VERSION antes de subirlo:"
echo "  el cask baja de ahí, y un cask que apunta a una release que no existe"
echo "  falla en el ordenador de quien instala, no en el tuyo."
