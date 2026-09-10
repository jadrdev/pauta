#!/usr/bin/env python3
"""Genera los .icns de Pauta a partir del monograma de la identidad.

  mono   — P blanca y check verde sobre el negro de marca (la que va puesta)
  claro  — P en negro de marca y check verde sobre fondo claro

Uso: python3 tools/make-icon.py [mono|claro|ambas]
"""
import subprocess, sys, pathlib
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
RES  = ROOT / "Resources"

BRAND_BLACK = (8, 12, 16, 255)
BRAND_LIGHT = (250, 250, 248, 255)

def squircle(size, ground):
    """Lámina de icono macOS: squircle centrado con margen transparente."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    m = round(size * 0.098)
    r = round(size * 0.2237 * (1 - 2 * 0.098))
    d.rounded_rectangle([m, m, size - m - 1, size - m - 1], radius=r, fill=ground)
    return img, m, size - m

def compose(size, ground, art_name, frac=0.60):
    # Se compone siempre a 1024 y se reduce: mejor resultado que dibujar a 32.
    if size < 1024:
        return compose(1024, ground, art_name, frac).resize((size, size), Image.LANCZOS)
    img, lo, hi = squircle(size, ground)
    art = Image.open(RES / art_name).convert("RGBA")
    span = hi - lo
    k = min((span * frac) / art.size[0], (span * frac) / art.size[1])
    r = art.resize((int(art.size[0] * k), int(art.size[1] * k)), Image.LANCZOS)
    img.alpha_composite(r, (lo + (span - r.size[0]) // 2, lo + (span - r.size[1]) // 2))
    return img

def lamina_ios(size, ground, art_name, frac=0.52):
    """Lámina de iOS: **a sangre**, sin margen ni esquinas redondeadas.

    La máscara la pone el sistema, y la del Mac encima se vería como un icono
    metido en un marco con un borde muerto alrededor. El monograma va algo más
    pequeño en proporción que en el Mac porque el redondeo de iOS come esquina:
    lo que en una lámina plana parece holgado, ahí queda pegado al filo.
    """
    if size < 1024:
        return lamina_ios(1024, ground, art_name, frac).resize((size, size), Image.LANCZOS)
    img = Image.new("RGBA", (size, size), ground)
    art = Image.open(RES / art_name).convert("RGBA")
    k = min((size * frac) / art.size[0], (size * frac) / art.size[1])
    r = art.resize((int(art.size[0] * k), int(art.size[1] * k)), Image.LANCZOS)
    img.alpha_composite(r, ((size - r.size[0]) // 2, (size - r.size[1]) // 2))
    # Sin alfa: iOS no admite transparencia en el icono, y donde la hay sale
    # negro sin avisar.
    return img.convert("RGB")


def lamina_reloj(size, ground, art_name, frac=0.46):
    """La lámina del reloj: la de iOS con el monograma **más pequeño todavía**.

    La máscara de watchOS es un **círculo**, y un círculo come mucho más que el
    redondeo de iOS: lo que en un icono de iPhone queda holgado, aquí toca el
    filo por los cuatro lados. De 0,52 a 0,46.

    Y sigue siendo a sangre y sin alfa, por lo mismo que en iOS: la máscara la
    pone el sistema, y donde hay transparencia sale negro sin avisar.
    """
    return lamina_ios(size, ground, art_name, frac)


def icon_mono(size=1024):  return compose(size, BRAND_BLACK, "monogram.png")
def icon_claro(size=1024): return compose(size, BRAND_LIGHT, "monogram-ink.png")

def build(name, maker):
    iconset = RES / f"{name}.iconset"
    iconset.mkdir(parents=True, exist_ok=True)
    for base in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = base * scale
            suffix = "" if scale == 1 else "@2x"
            maker(px).save(iconset / f"icon_{base}x{base}{suffix}.png")
    out = RES / f"{name}.icns"
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(out)], check=True)
    maker(1024).save(RES / f"{name}-preview.png")
    print(f"✓ {out.relative_to(ROOT)}")

def build_ios():
    """El catálogo de recursos del icono de iOS.

    Una sola imagen de 1024 y no las quince de antaño: desde Xcode 14 el sistema
    deriva los tamaños él, y mantener quince a mano era garantizar que alguna se
    quedara con el arte viejo.
    """
    catalogo = RES / "ios" / "Assets.xcassets" / "AppIcon.appiconset"
    catalogo.mkdir(parents=True, exist_ok=True)
    lamina_ios(1024, BRAND_BLACK, "monogram.png").save(catalogo / "icon-1024.png")
    (catalogo / "Contents.json").write_text(
        '{\n  "images" : [\n    {\n      "filename" : "icon-1024.png",\n'
        '      "idiom" : "universal",\n      "platform" : "ios",\n'
        '      "size" : "1024x1024"\n    }\n  ],\n'
        '  "info" : { "author" : "pauta", "version" : 1 }\n}\n')
    (RES / "ios" / "Assets.xcassets" / "Contents.json").write_text(
        '{\n  "info" : { "author" : "pauta", "version" : 1 }\n}\n')
    lamina_ios(512, BRAND_BLACK, "monogram.png").save(RES / "icon-ios-preview.png")
    print(f"✓ {catalogo.relative_to(ROOT)}")


def build_watch():
    """El catálogo del icono del reloj.

    Otro catálogo y no el de iOS: la plataforma va escrita dentro del
    `Contents.json`, y sobre todo el arte no es el mismo — el monograma va más
    pequeño porque la máscara es redonda.
    """
    catalogo = RES / "watch" / "Assets.xcassets" / "AppIcon.appiconset"
    catalogo.mkdir(parents=True, exist_ok=True)
    lamina_reloj(1024, BRAND_BLACK, "monogram.png").save(catalogo / "icon-1024.png")
    (catalogo / "Contents.json").write_text(
        '{\n  "images" : [\n    {\n      "filename" : "icon-1024.png",\n'
        '      "idiom" : "universal",\n      "platform" : "watchos",\n'
        '      "size" : "1024x1024"\n    }\n  ],\n'
        '  "info" : { "author" : "pauta", "version" : 1 }\n}\n')
    (RES / "watch" / "Assets.xcassets" / "Contents.json").write_text(
        '{\n  "info" : { "author" : "pauta", "version" : 1 }\n}\n')
    lamina_reloj(512, BRAND_BLACK, "monogram.png").save(RES / "icon-reloj-preview.png")
    print(f"✓ {catalogo.relative_to(ROOT)}")


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "ambas"
    if which in ("mono", "ambas"):  build("icon-mono", icon_mono)
    if which in ("claro", "ambas"): build("icon-claro", icon_claro)
    if which in ("ios", "ambas"):   build_ios()
    if which in ("reloj", "ambas"): build_watch()
