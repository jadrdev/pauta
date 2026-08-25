#!/bin/bash
# Compila Pauta y la empaqueta como Pauta.app (sin necesidad de abrir Xcode).
set -euo pipefail
cd "$(dirname "$0")"

export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}
CONFIG=${1:-release}
APP="build/Pauta.app"
# Variante de icono: icon-mono (fondo oscuro) o icon-claro (fondo claro).
ICON=${ICON:-icon-mono}

echo "▸ Compilando ($CONFIG)…"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Pauta"

echo "▸ Empaquetando $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Pauta"
cp "Resources/$ICON.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "Resources/monogram.png"     "$APP/Contents/Resources/monogram.png"
cp "Resources/monogram-ink.png" "$APP/Contents/Resources/monogram-ink.png"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>              <string>Pauta</string>
    <key>CFBundleDisplayName</key>       <string>Pauta</string>
    <key>CFBundleExecutable</key>        <string>Pauta</string>
    <key>CFBundleIconFile</key>          <string>AppIcon</string>
    <key>CFBundleIdentifier</key>        <string>dev.jadrdev.pauta</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key>           <string>1</string>
    <key>LSMinimumSystemVersion</key>    <string>14.0</string>
    <key>NSPrincipalClass</key>          <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>   <true/>
</dict>
</plist>
PLIST

# Firma ad-hoc: suficiente para ejecutarla en local.
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "  (aviso: no se pudo firmar; la app aún debería abrir)"

# Registra el bundle en LaunchServices. Sin esto, `open` puede quedarse con una
# versión cacheada y abrir la app sin ventana cuando cambia el identificador.
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$PWD/$APP" 2>/dev/null || true

echo "✓ Listo: $APP"
