#!/usr/bin/env python3
"""Las capturas de la App Store: la pantalla de verdad dentro de un marco de
teléfono, con un titular encima, sobre el fondo y los colores de Pauta.

Las pantallas salen del simulador con la maqueta (`-demo`), que enseña tareas
de muestra y nunca las de nadie:

    xcrun simctl launch <simulador> dev.jadrdev.pauta -demo -vista hoy
    xcrun simctl io <simulador> screenshot hoy.png

Y esto las compone, al mismo tamaño que la captura (el que pide App Store
Connect para ese aparato):

    python3 tools/capturas-tienda.py entrada.png salida.png "Titular" "Línea de debajo"
"""
import sys
from PIL import Image, ImageDraw, ImageFont

# La paleta de la app (Sources/PautaCore/Paleta.swift), en claro.
FONDO_ARRIBA = (232, 247, 238)   # el verde de acento, muy rebajado
FONDO_ABAJO = (250, 250, 248)    # bg
TINTA = (14, 17, 20)             # ink
VERDE = (9, 125, 73)             # accentInk
SUAVE = (96, 104, 112)           # inkSoft, aproximado
MARCO = (22, 24, 27)

FUENTE = "/System/Library/Fonts/SFNS.ttf"


def fuente(tamano, peso):
    f = ImageFont.truetype(FUENTE, tamano)
    # Ejes de SF: ancho, tamaño óptico, grado y peso.
    f.set_variation_by_axes([100, 96 if tamano >= 60 else 28, 400, peso])
    return f


def componer(entrada, salida, titular, linea):
    pantalla = Image.open(entrada).convert("RGB")
    ancho, alto = pantalla.size
    lienzo = Image.new("RGB", (ancho, alto), FONDO_ABAJO)

    # Fondo: degradado suave de arriba abajo, y un círculo grande muy tenue.
    d = ImageDraw.Draw(lienzo)
    for y in range(alto):
        t = min(1, y / (alto * 0.55))
        color = tuple(int(a + (b - a) * t) for a, b in zip(FONDO_ARRIBA, FONDO_ABAJO))
        d.line([(0, y), (ancho, y)], fill=color)
    capa = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    ImageDraw.Draw(capa).ellipse(
        [-ancho * 0.35, alto * 0.18, ancho * 0.75, alto * 0.18 + ancho * 1.1],
        fill=(16, 232, 136, 22))
    lienzo = Image.alpha_composite(lienzo.convert("RGBA"), capa).convert("RGB")
    d = ImageDraw.Draw(lienzo)

    # El titular, en dos tintas como el ejemplo: la primera línea en verde.
    # Los textos, a la medida del lienzo: en el iPad, algo más pequeños en
    # proporción, que el lienzo es mucho más ancho.
    escala = ancho / 1320 if alto / ancho > 1.6 else ancho / 1600
    margen_sup = int(190 * escala)
    lineas = titular.split("|")
    tam = int(108 * escala)
    y = margen_sup
    for i, texto in enumerate(lineas):
        f = fuente(tam, 760)
        w = d.textlength(texto, font=f)
        d.text(((ancho - w) / 2, y), texto, font=f, fill=VERDE if i == 0 and len(lineas) > 1 else TINTA)
        y += int(tam * 1.18)
    f2 = fuente(int(50 * escala), 500)
    w = d.textlength(linea, font=f2)
    d.text(((ancho - w) / 2, y + int(22 * escala)), linea, font=f2, fill=SUAVE)
    arriba_telefono = y + int(150 * escala)

    # El teléfono: la pantalla con las esquinas redondeadas dentro de un marco.
    borde = int(26 * escala)
    alto_tel = alto - arriba_telefono + int(260 * escala)  # se corta por abajo
    alto_pant = alto_tel - 2 * borde
    proporcion = pantalla.height / pantalla.width
    ancho_pant = int(min(ancho * 0.80, alto_pant / proporcion))
    alto_pant = int(ancho_pant * proporcion)
    pant = pantalla.resize((ancho_pant, alto_pant), Image.LANCZOS)
    # Un teléfono es alargado y muy redondeado; un iPad, casi cuadrado y menos.
    radio = int(ancho_pant * (0.12 if proporcion > 1.6 else 0.04))
    mascara = Image.new("L", pant.size, 0)
    ImageDraw.Draw(mascara).rounded_rectangle([0, 0, *pant.size], radio, fill=255)

    x0 = (ancho - ancho_pant) // 2 - borde
    y0 = arriba_telefono
    # Sombra suave debajo del marco.
    sombra = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    ImageDraw.Draw(sombra).rounded_rectangle(
        [x0 + 10, y0 + 30, x0 + ancho_pant + 2 * borde + 10, y0 + alto_pant + 2 * borde + 30],
        radio + borde, fill=(0, 0, 0, 40))
    from PIL import ImageFilter
    sombra = sombra.filter(ImageFilter.GaussianBlur(40 * escala))
    lienzo = Image.alpha_composite(lienzo.convert("RGBA"), sombra).convert("RGB")
    d = ImageDraw.Draw(lienzo)
    d.rounded_rectangle([x0, y0, x0 + ancho_pant + 2 * borde, y0 + alto_pant + 2 * borde],
                        radio + borde, fill=MARCO)
    lienzo.paste(pant, (x0 + borde, y0 + borde), mascara)
    lienzo.save(salida, "PNG")


if __name__ == "__main__":
    componer(*sys.argv[1:5])
