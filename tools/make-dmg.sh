#!/bin/zsh
# Empaqueta la app en un .dmg listo para descargar.
#
# El disco lleva dos cosas y nada más: la app y un enlace a /Applications, que es
# el gesto que todo el mundo en macOS conoce —arrastrar de un icono al otro—. Sin
# fondo dibujado ni ventana colocada a mano: eso exige guionizar el Finder, que
# falla en cuanto se ejecuta sin sesión gráfica delante, y no aporta nada que el
# usuario no sepa hacer ya.
set -euo pipefail
cd "$(dirname "$0")/.."

./build.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    build/Pauta.app/Contents/Info.plist)
STAGE="build/dmg"
DMG="build/Pauta-$VERSION.dmg"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R build/Pauta.app "$STAGE/Pauta.app"
ln -s /Applications "$STAGE/Applications"

echo "▸ Creando $DMG…"
hdiutil create -volname "Pauta $VERSION" -srcfolder "$STAGE" \
    -ov -format UDZO -quiet "$DMG"
rm -rf "$STAGE"

# La advertencia importa más que el paquete. Con un certificado de desarrollo
# —el único que da una cuenta gratuita— el disco se abre aquí y en ningún otro
# Mac: Gatekeeper exige «Developer ID Application» **y** notarización para lo que
# se descarga de internet, y sin las dos cosas el sistema dice que la app está
# dañada, que es un mensaje que asusta y no explica nada.
if codesign -dv --verbose=2 build/Pauta.app 2>&1 | grep -q "Authority=Developer ID Application"; then
    echo "▸ Firmada con Developer ID. Falta notarizar:"
    echo "  xcrun notarytool submit \"$DMG\" --keychain-profile <perfil> --wait"
    echo "  xcrun stapler staple \"$DMG\""
else
    echo "⚠︎ Firmada solo con un certificado de desarrollo."
    echo "  Sirve para probar y para pasársela a alguien de confianza, pero en"
    echo "  otro Mac Gatekeeper la bloqueará hasta que se le quite la cuarentena:"
    echo "      xattr -dr com.apple.quarantine /Applications/Pauta.app"
    echo "  Para repartirla sin esa nota hace falta la cuenta de desarrollador"
    echo "  de pago, un certificado Developer ID y notarizarla."
fi

echo
echo "✓ $DMG  ($(du -h "$DMG" | cut -f1))"
echo "  sha256: $(shasum -a 256 "$DMG" | cut -d' ' -f1)"
