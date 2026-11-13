"""Falla si el catálogo tiene algún texto sin traducir.

Un texto nuevo escrito en español que nadie traduce no da error en ningún sitio:
en catalán y en inglés sale en español, y nadie se entera hasta que lo ve un
usuario. Esto lo convierte en un fallo **antes** de subir una versión.

Cuenta como traducido lo que está en estado `translated` en cada idioma, con
sus variantes de plural si las tiene. Lo que no hay que traducir —«·», «%lld»,
el nombre de la app— va marcado en el catálogo con `shouldTranslate: false`.
Lo que el código ya no usa (`stale`) no cuenta.

**El español también tiene que estar escrito**, aunque sea igual que la clave.
El idioma de respaldo de la app es el inglés (`CFBundleDevelopmentRegion`), y
si la tabla del español no trae un texto, el sistema no devuelve la clave: va a
buscarlo al inglés. Una app en español con la mitad de las frases en inglés.
Xcode no escribe la tabla del idioma de partida si nadie le da sus valores, así
que `--rellenar` los pone, igual a la clave, en lo que no los tenga.

    python3 tools/textos-comprobar.py [--rellenar] [catálogo]
"""
import json
import sys

IDIOMAS = ["ca", "en"]


def traducida(loc):
    """Si una localización está entera: su valor, o todas sus variantes."""
    if "stringUnit" in loc:
        return loc["stringUnit"].get("state") == "translated"
    if "variations" in loc:
        return all(traducida(v) for grupo in loc["variations"].values()
                   for v in grupo.values())
    return False


def rellenar(ruta):
    """Escribe el español de lo que no lo tenga: el valor que dio el código
    (`defaultValue`) si lo hay, y si no la propia clave."""
    cat = json.load(open(ruta, encoding="utf-8"))
    for clave, e in cat["strings"].items():
        if e.get("extractionState") == "stale":
            continue
        locs = e.setdefault("localizations", {})
        unidad = locs.get("es", {}).get("stringUnit")
        if unidad is None:
            locs["es"] = {"stringUnit": {"state": "translated", "value": clave}}
        else:
            unidad["state"] = "translated"
    json.dump(cat, open(ruta, "w", encoding="utf-8"), ensure_ascii=False,
              indent=2, separators=(",", " : "))


def main(ruta):
    cat = json.load(open(ruta, encoding="utf-8"))
    faltan = {i: [] for i in ["es"] + IDIOMAS}
    for clave, e in cat["strings"].items():
        if e.get("extractionState") == "stale":
            continue
        locs = e.get("localizations", {})
        if "es" not in locs or not traducida(locs["es"]):
            faltan["es"].append(clave)
        if e.get("shouldTranslate") is False:
            continue
        for i in IDIOMAS:
            if i not in locs or not traducida(locs[i]):
                faltan[i].append(clave)
    total = sum(len(v) for v in faltan.values())
    if total == 0:
        vivos = sum(1 for e in cat["strings"].values()
                    if e.get("extractionState") != "stale")
        print(f"✓ {vivos} textos, todos en español, catalán e inglés")
        return 0
    for i, claves in faltan.items():
        if claves:
            nombre = {"es": "español (tools/textos-comprobar.py --rellenar)",
                      "ca": "catalán", "en": "inglés"}[i]
            print(f"✗ {len(claves)} sin escribir en {nombre}:")
            for c in claves[:40]:
                print(f"    «{c}»")
            if len(claves) > 40:
                print(f"    … y {len(claves) - 40} más")
    return 1


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--rellenar"]
    ruta = args[0] if args else "Resources/idiomas/Localizable.xcstrings"
    if "--rellenar" in sys.argv:
        rellenar(ruta)
    sys.exit(main(ruta))
