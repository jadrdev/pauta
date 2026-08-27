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

echo "▸ Empaquetando ${APP}…"
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
    <!-- Sin estas cadenas, pedir acceso a Recordatorios aborta el proceso. -->
    <key>NSRemindersFullAccessUsageDescription</key>
    <string>Pauta lee su propia lista de Recordatorios para traer a la bandeja lo que apuntes desde el iPhone o con Siri.</string>
    <key>NSRemindersUsageDescription</key>
    <string>Pauta lee su propia lista de Recordatorios para traer a la bandeja lo que apuntes desde el iPhone o con Siri.</string>
</dict>
</plist>
PLIST

# Firma. Con firma ad-hoc el hash del binario cambia con cada cambio de código
# (comprobado), y TCC identifica las apps por su firma: para el sistema cada
# build sería una app nueva, así que los permisos de calendario, recordatorios,
# accesibilidad, etc. se pedirían otra vez en cada compilación y dejarían
# entradas basura en Ajustes de Privacidad. Con una identidad de desarrollador
# el requisito designado se basa en el identificador y el equipo, no en el hash,
# y sobrevive a las recompilaciones.
#
# SIGN_ID fuerza una identidad concreta. Si no, se busca la primera de Apple que
# no esté revocada; y si no hay ninguna, se cae a ad-hoc con un aviso.
SIGN_ID="${SIGN_ID:-}"
if [ -z "${SIGN_ID}" ]; then
    SIGN_ID=$(security find-identity -v -p codesigning 2>/dev/null \
              | grep -v CSSMERR \
              | grep -m1 '"Apple Develop' \
              | sed 's/.*"\(.*\)".*/\1/') || true
fi

if [ -n "${SIGN_ID}" ] && codesign --force --sign "${SIGN_ID}" "${APP}" 2>/dev/null; then
    echo "  firmado con identidad estable: ${SIGN_ID}"
else
    if [ -n "${SIGN_ID}" ]; then
        echo "  aviso: no se pudo firmar con «${SIGN_ID}»; se recurre a ad-hoc"
    else
        echo "  aviso: sin identidad de firma en el llavero; se recurre a ad-hoc"
    fi
    echo "         los permisos del sistema se volverán a pedir en cada build"
    codesign --force --sign - "${APP}" >/dev/null 2>&1 || true
fi

# Registra el bundle en LaunchServices. Sin esto, `open` puede quedarse con una
# versión cacheada y abrir la app sin ventana cuando cambia el identificador.
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$PWD/$APP" 2>/dev/null || true

echo "✓ Listo: $APP"
