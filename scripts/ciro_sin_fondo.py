# Quita el fondo de damero "dibujado" de las ilustraciones de Ciro (JPG sin transparencia
# real): rellena desde los bordes todo lo que no es el contorno blanco del sticker.
# Uso: python scripts/ciro_sin_fondo.py <original.jpg> <salida.webp> <alto_px> [sin-azul]
# Originales en input/ciro_ilustraciones/, resultados en assets/ciro/ (y copia en docs/img/).
import sys
from PIL import Image, ImageDraw, ImageFilter
src, dst, alto = sys.argv[1], sys.argv[2], int(sys.argv[3])
im = Image.open(src).convert("RGB"); w, h = im.size
if len(sys.argv) > 4 and sys.argv[4] == "sin-azul":
    # Azules (tono 190-265 grados) pasan a verde (145 grados), con la misma luz
    import numpy as np
    hsv = np.array(im.convert("HSV")).astype(int)
    azul = (hsv[..., 0] >= 134) & (hsv[..., 0] <= 188) & (hsv[..., 1] > 25)
    hsv[..., 0][azul] = 103
    im = Image.fromarray(hsv.astype("uint8"), "HSV").convert("RGB")
# Máscara: 255 = blanco (borde del sticker), 0 = no blanco
m = im.convert("L").point(lambda v: 255 if v >= 228 else 0)
for x in range(0, w, 4):
    for y in (0, h - 1):
        if m.getpixel((x, y)) == 0: ImageDraw.floodfill(m, (x, y), 128)
for y in range(0, h, 4):
    for x in (0, w - 1):
        if m.getpixel((x, y)) == 0: ImageDraw.floodfill(m, (x, y), 128)
alpha = m.point(lambda v: 0 if v == 128 else 255)
alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
out = im.convert("RGBA"); out.putalpha(alpha)
out = out.crop(alpha.point(lambda v: 255 if v > 20 else 0).getbbox())
out = out.resize((round(out.width * alto / out.height), alto), Image.LANCZOS)
out.save(dst, "WEBP", quality=88, method=6)
print(dst, out.size)
