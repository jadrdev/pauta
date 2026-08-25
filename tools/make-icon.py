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

if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "ambas"
    if which in ("mono", "ambas"):  build("icon-mono", icon_mono)
    if which in ("claro", "ambas"): build("icon-claro", icon_claro)
