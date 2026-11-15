# Quita el fondo "dibujado" de las ilustraciones de Ciro (sin transparencia real): rellena
# desde los bordes todo lo que no es el contorno blanco del sticker.
# Uso: python scripts/ciro_sin_fondo.py <original> <salida.webp|.png> <alto_px> [sin-azul] [fondo-blanco]
#   (alto_px = 0 mantiene el tamaño original; la salida .png sirve para guardar los Ciros de recuerdo)
#   sin-azul:     pasa los azules a verde
#   fondo-blanco: el fondo es blanco liso (no damero); se rellena el blanco que toca los
#                 bordes hasta la línea oscura que rodea el sticker
#   umbral=N:     luz desde la que un pixel cuenta como blanco (228 por defecto); subirlo
#                 (p. ej. 245) cuando los cuadros claros del damero son casi blancos
# Originales en input/ciro_ilustraciones/, resultados en assets/ciro/ (y copia en docs/img/).
import sys
from PIL import Image, ImageDraw, ImageFilter
src, dst, alto = sys.argv[1], sys.argv[2], int(sys.argv[3])
opciones = set(sys.argv[4:])
im = Image.open(src).convert("RGB"); w, h = im.size
if "sin-azul" in opciones:
    # Azules (tono 190-265 grados) pasan a verde (145 grados), con la misma luz
    import numpy as np
    hsv = np.array(im.convert("HSV")).astype(int)
    azul = (hsv[..., 0] >= 134) & (hsv[..., 0] <= 188) & (hsv[..., 1] > 25)
    hsv[..., 0][azul] = 103
    im = Image.fromarray(hsv.astype("uint8"), "HSV").convert("RGB")
# Máscara: 255 = blanco (borde del sticker), 0 = no blanco
umbral = next((int(o.split("=")[1]) for o in opciones if o.startswith("umbral=")), 228)
m = im.convert("L").point(lambda v: 255 if v >= umbral else 0)
# Con damero se rellena lo que no es blanco; con fondo blanco, el blanco que toca los bordes
fondo = 255 if "fondo-blanco" in opciones else 0
for x in range(0, w, 4):
    for y in (0, h - 1):
        if m.getpixel((x, y)) == fondo: ImageDraw.floodfill(m, (x, y), 128)
for y in range(0, h, 4):
    for x in (0, w - 1):
        if m.getpixel((x, y)) == fondo: ImageDraw.floodfill(m, (x, y), 128)
alpha = m.point(lambda v: 0 if v == 128 else 255)
alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
out = im.convert("RGBA"); out.putalpha(alpha)
out = out.crop(alpha.point(lambda v: 255 if v > 20 else 0).getbbox())
if alto > 0: out = out.resize((round(out.width * alto / out.height), alto), Image.LANCZOS)
if dst.lower().endswith(".png"): out.save(dst, "PNG", optimize=True)
else: out.save(dst, "WEBP", quality=88, method=6)
print(dst, out.size)
