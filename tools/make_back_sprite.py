#!/usr/bin/env python3
"""Genera una espalda aproximada para un entrenador que solo tiene sprite de frente.

Espeja el sprite y, dentro de la caja de la cara, pinta la piel y los rasgos con el
color del pelo (el contorno exterior se conserva). Es un sustituto: si aparece un
sprite de espalda real, se reemplaza en el manifiesto.
Uso: python3 tools/make_back_sprite.py <frente.png> <salida.png> x0 y0 x1 y1 R,G,B
  (x0 y0 x1 y1 es la caja de la cara en el sprite de frente, ya recortado; R,G,B es el pelo)
"""
import sys

from PIL import Image


def is_skin(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return a > 0 and r > 150 and r > g > b and r - b > 40


def make_back(image: Image.Image, face_box: tuple[int, int, int, int], hair_rgb: tuple[int, int, int]) -> tuple[Image.Image, int]:
    """Devuelve (espalda, píxeles de cara convertidos) a partir del sprite de frente."""
    image = image.convert("RGBA").copy()
    x0, y0, x1, y1 = face_box
    hair = tuple(hair_rgb) + (255,)
    width, height = image.size
    pixels = image.load()

    def on_edge(x: int, y: int) -> bool:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if not (0 <= nx < width and 0 <= ny < height) or pixels[nx, ny][3] == 0:
                return True
        return False

    # Dentro de la cara: piel y rasgos (ojos, boca, cejas) pasan a ser pelo.
    changes = []
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            p = pixels[x, y]
            if p[3] == 0 or on_edge(x, y):
                continue
            if is_skin(p) or max(p[:3]) < 70 or p[:3] == (232, 232, 248):
                changes.append((x, y))

    # Mechones: columnas alternas más oscuras.
    shade = tuple(max(0, int(c * 0.72)) for c in hair[:3]) + (255,)
    for x, y in changes:
        strand = (x + (y // 4)) % 3 == 0
        pixels[x, y] = shade if strand else hair

    return image.transpose(Image.Transpose.FLIP_LEFT_RIGHT), len(changes)


def main() -> int:
    if len(sys.argv) != 8:
        print(__doc__, file=sys.stderr)
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    box = tuple(int(v) for v in sys.argv[3:7])
    hair = tuple(int(v) for v in sys.argv[7].split(","))
    back, changed = make_back(Image.open(src), box, hair)
    back.save(dst)
    print(f"{dst}: {changed} píxeles de cara convertidos")
    return 0


if __name__ == "__main__":
    sys.exit(main())
