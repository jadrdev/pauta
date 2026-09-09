#!/bin/bash
# Compila Pauta y su widget, y deja el paquete en build/Pauta.app.
#
# Antes esto era `swift build` y un bundle montado a mano, y estuvo bien
# mientras la app era un solo binario. **El widget acabó con eso**, por dos
# razones que ninguna herramienta de paquetes cubre:
#
#   · Una extensión es otro paquete —con su identificador, sus permisos y su
#     punto de extensión— embebido en `Contents/PlugIns/` y firmado aparte.
#   · Un grupo de aplicaciones necesita que la firma vaya **autorizada**, y
#     quien pide esa autorización a Apple es Xcode.
#
# Así que compila el mismo proyecto que el teléfono, cambiando el destino. La
# interfaz de este guion no cambia: sigue dejando `build/Pauta.app`, que es lo
# que abren `run.sh` y `tools/make-dmg.sh`.
#
# ICONO=icon-claro ./build.sh   elige la otra lámina de icono.
set -euo pipefail
cd "$(dirname "$0")"

export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}
CONFIG=${1:-release}
DERIVED=${DERIVED:-build/mac-dd}
APP="build/Pauta.app"

command -v xcodegen >/dev/null || {
    echo "hace falta xcodegen:  brew install xcodegen" >&2; exit 1; }

# release/debug en minúscula por compatibilidad con lo que había; xcodebuild las
# quiere capitalizadas.
case "$CONFIG" in
    release|Release) XCCONFIG=Release ;;
    debug|Debug)     XCCONFIG=Debug ;;
    *) echo "configuración desconocida: $CONFIG (release|debug)" >&2; exit 1 ;;
esac

echo "▸ Proyecto…"
xcodegen generate --quiet

echo "▸ Compilando app y widget ($XCCONFIG)…"
ARGS=(-project Pauta.xcodeproj -scheme PautaMac -configuration "$XCCONFIG"
      -destination 'platform=macOS' -derivedDataPath "$DERIVED"
      -allowProvisioningUpdates -quiet)
[ -n "${ICONO:-}" ] && ARGS+=("ICONO=$ICONO")
xcodebuild "${ARGS[@]}" build

echo "▸ Empaquetando ${APP}…"
rm -rf "$APP"
cp -R "$DERIVED/Build/Products/$XCCONFIG/Pauta.app" "$APP"

[ -d "$APP/Contents/PlugIns/PautaWidget.appex" ] || {
    echo "el widget no está en el paquete: algo se rompió en el proyecto" >&2; exit 1; }

# La firma sale de Xcode con **tu** equipo y no con «la primera identidad del
# llavero», que era como esto acabó firmado con el certificado de la empresa sin
# que nadie lo decidiera. Importa más de lo que parece: TCC identifica las apps
# por su firma, así que cambiar de certificado hace que el sistema la vea como
# otra app y vuelva a pedir los permisos una vez.
EQUIPO=$(codesign -dv --verbose=2 "$APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')
echo "  firmada por el equipo $EQUIPO"

# Registra el bundle en LaunchServices. Sin esto `open` puede quedarse con una
# versión cacheada, y —desde que hay widget— el sistema tampoco descubre la
# extensión que acaba de aparecer dentro del paquete.
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$PWD/$APP" 2>/dev/null || true

# La extensión la registra el propio Xcode al compilar, apuntando a su carpeta
# de compilación: `pluginkit -m` enseña esa ruta y no la de aquí —probado, y
# `pluginkit -a` sobre el paquete no le gana el sitio—. Funciona igual, es el
# mismo binario con la misma firma; lo que hay que saber es que en esta máquina
# el widget que ofrece el sistema vive en `build/mac-dd` y desaparece si se
# limpia. Instalada de verdad —arrastrada a Aplicaciones desde el disco— es esa
# copia la que se registra, que es el camino de cualquiera que no sea yo.

echo "✓ Listo: $APP"
