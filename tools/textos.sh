#!/bin/zsh
# Pone al día el catálogo de textos con lo que hay en el código, y dice qué
# falta por traducir.
#
# Xcode lo hace solo al compilar **desde Xcode**. Desde la terminal no: el
# compilador saca los textos de cada archivo (`.stringsdata`), pero nadie los
# lleva al catálogo. Esto compila el iPhone —con el reloj y los widgets— y el
# Mac pidiéndole esos textos, y los mete en `Resources/idiomas/Localizable.xcstrings`.
#
# Lo que se quitó del código queda marcado como «stale» en el catálogo, no se
# borra: si vuelve, vuelve con su traducción.
#
#   tools/textos.sh            sincroniza y comprueba
#   tools/textos.sh comprobar  solo comprueba, sin compilar
set -euo pipefail
cd "$(dirname "$0")/.."

CATALOGO=Resources/idiomas/Localizable.xcstrings

if [[ "${1:-}" != comprobar ]]; then
    . tools/xcode.sh
    xcodegen generate --quiet

    echo "▸ Sacando los textos del iPhone, el reloj y los widgets…"
    xcodebuild -project Pauta.xcodeproj -scheme Pauta \
        -destination "generic/platform=iOS Simulator" \
        -derivedDataPath build/textos-ios SWIFT_EMIT_LOC_STRINGS=YES -quiet build

    echo "▸ Sacando los textos del Mac…"
    xcodebuild -project Pauta.xcodeproj -scheme PautaMac -configuration Debug \
        -destination 'platform=macOS' -derivedDataPath build/textos-mac \
        SWIFT_EMIT_LOC_STRINGS=YES CODE_SIGNING_ALLOWED=NO -quiet build

    echo "▸ Al catálogo…"
    ARGS=()
    for f in $(find build/textos-ios build/textos-mac -name '*.stringsdata'); do
        ARGS+=(--stringsdata "$f")
    done
    xcrun xcstringstool sync "$CATALOGO" "${ARGS[@]}"
    RELLENAR=--rellenar

    # Una segunda copia del Mac con el mismo identificador se queda permisos y
    # widget que son de la de Aplicaciones. Solo hacía falta por sus textos.
    rm -rf build/textos-mac
fi

/usr/bin/python3 tools/textos-comprobar.py ${RELLENAR:-} "$CATALOGO"
