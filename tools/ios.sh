#!/bin/zsh
# Compila la app de iOS y la instala en el simulador.
#
# Sin proyecto de Xcode, igual que el Mac: se compila con swiftc y el .app se
# monta a mano. Para el **simulador** eso basta y no hace falta firmar nada —es
# lo que permite tener algo instalable hoy, sin cuenta de desarrollador—.
#
# Para un iPhone de verdad esto no llega: ahí hacen falta un perfil de
# aprovisionamiento y una firma, y eso lo da Xcode (gratis dura 7 días; sin
# límite con la cuenta de pago).
set -euo pipefail
cd "$(dirname "$0")/.."

: ${DEVELOPER_DIR:=/Applications/Xcode-beta.app/Contents/Developer}
export DEVELOPER_DIR
DESTINO="${1:-iPhone 17}"
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
TRIPLE="arm64-apple-ios17.0-simulator"
OUT="build/ios"
APP="$OUT/Pauta.app"

rm -rf "$OUT"; mkdir -p "$APP"

echo "▸ Núcleo…"
xcrun --sdk iphonesimulator swiftc -target "$TRIPLE" -sdk "$SDK" -O \
    -module-name PautaCore -emit-module -emit-module-path "$OUT/PautaCore.swiftmodule" \
    -emit-library -static -o "$OUT/libPautaCore.a" \
    Sources/PautaCore/*.swift

echo "▸ Interfaz…"
xcrun --sdk iphonesimulator swiftc -target "$TRIPLE" -sdk "$SDK" -O \
    -I "$OUT" -L "$OUT" -lPautaCore \
    -o "$APP/Pauta" \
    Sources/PautaIOS/*.swift

# La versión sale del mismo sitio que la del Mac, para que no discrepen.
VERSION=$(/usr/bin/sed -n 's/.*CFBundleShortVersionString<\/key><string>\(.*\)<\/string>.*/\1/p' build.sh | head -1)

cat > "$APP/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>              <string>Pauta</string>
    <key>CFBundleDisplayName</key>       <string>Pauta</string>
    <key>CFBundleExecutable</key>        <string>Pauta</string>
    <key>CFBundleIdentifier</key>        <string>dev.jadrdev.pauta</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key>           <string>1</string>
    <key>MinimumOSVersion</key>          <string>17.0</string>
    <key>CFBundleSupportedPlatforms</key><array><string>iPhoneSimulator</string></array>
    <key>UIDeviceFamily</key>            <array><integer>1</integer></array>
    <key>CFBundleDevelopmentRegion</key> <string>es</string>
    <key>CFBundleLocalizations</key>     <array><string>es</string></array>
    <!-- Obligatoria desde iOS 14; vacía hereda el fondo del sistema. -->
    <key>UILaunchScreen</key>            <dict/>
    <!-- Sin estas cadenas, pedir acceso al calendario aborta el proceso. -->
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>Pauta enseña los eventos de hoy junto a tus tareas, para que Hoy sea el día completo. Solo los lee: nunca escribe en tus calendarios.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>Pauta enseña los eventos de hoy junto a tus tareas, para que Hoy sea el día completo. Solo los lee: nunca escribe en tus calendarios.</string>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
</dict>
</plist>
PLIST

# El icono, compilado con actool: en iOS el icono no es un PNG dentro del
# paquete sino un catálogo compilado más unas claves en el plist, y las claves
# las escribe la propia herramienta.
echo "▸ Icono…"
xcrun actool Resources/ios/Assets.xcassets \
    --compile "$APP" --platform iphonesimulator --minimum-deployment-target 17.0 \
    --app-icon AppIcon --output-partial-info-plist "$OUT/icono.plist" \
    --output-format human-readable-text > /dev/null
/usr/libexec/PlistBuddy -c "Merge $OUT/icono.plist" "$APP/Info.plist" > /dev/null

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
