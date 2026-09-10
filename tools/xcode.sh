# Dónde está Xcode, buscándolo en vez de escribiéndolo.
#
# Aquí iba `/Applications/Xcode-beta.app` como valor por defecto, y con motivo:
# en este equipo `xcode-select` apuntaba a las Command Line Tools, que no
# compilan apps. Pero era la ruta de **una app concreta**, y el día que la beta
# se desinstaló los cinco guiones se rompieron a la vez con el mismo error:
#
#     xcrun: error: missing DEVELOPER_DIR path: /Applications/Xcode-beta.app/…
#
# Se busca en este orden, y cada paso existe por algo:
#
#   1. `DEVELOPER_DIR` si ya viene puesto — manda quien llama, que es lo que
#      permite compilar con otra versión sin editar nada.
#   2. Lo que diga `xcode-select`, **solo si apunta a un Xcode**: si apunta a
#      las Command Line Tools no sirve, y es el caso que trajo todo esto.
#   3. El primer Xcode de /Applications, con la beta al final: si están las dos
#      instaladas, la estable es la que se usa para lo que se publica.
if [ -z "${DEVELOPER_DIR:-}" ]; then
    seleccionado=$(xcode-select -p 2>/dev/null || true)
    case "$seleccionado" in
        */Xcode*.app/Contents/Developer)
            DEVELOPER_DIR="$seleccionado"
            ;;
        *)
            for candidato in /Applications/Xcode.app /Applications/Xcode-beta.app; do
                if [ -d "$candidato/Contents/Developer" ]; then
                    DEVELOPER_DIR="$candidato/Contents/Developer"
                    break
                fi
            done
            ;;
    esac
fi
export DEVELOPER_DIR

if [ ! -d "${DEVELOPER_DIR:-/no-hay}" ]; then
    echo "no encuentro Xcode, y hace falta: de ahí salen xcodebuild, los SDK y la firma." >&2
    echo "  instálalo, y si ya está, apunta a él:" >&2
    echo "      sudo xcode-select -s /Applications/Xcode.app" >&2
    exit 1
fi
