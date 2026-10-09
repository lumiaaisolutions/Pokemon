#!/usr/bin/env python3
"""Sprites derivados de los de B2W2, para lo que el juego no trae.

- art/world/b2w2/dead_tree.png: árbol muerto del pantano (placeholder): el pino de
  B2W2 sin hojas, en grises y cafés apagados, con ramas ralas.

Uso: python3 tools/derived_sprites.py (después de tools/copy_sprites.py)
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "art" / "world" / "b2w2"


def dead_tree() -> None:
    image = Image.open(ART / "pine.png").convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            lum = int(0.3 * r + 0.59 * g + 0.11 * b)
            if g > r and g > b:
                # Follaje: ramas secas y ralas.
                if (x + y) % 3 == 0:
                    pixels[x, y] = (0, 0, 0, 0)
                else:
                    pixels[x, y] = (int(lum * 0.75) + 20, int(lum * 0.68) + 12, int(lum * 0.6) + 8, 255)
            else:
                pixels[x, y] = (int(lum * 0.8) + 10, int(lum * 0.72) + 6, int(lum * 0.65), 255)
    image.save(ART / "dead_tree.png")
    print("dead_tree.png", image.size)


if __name__ == "__main__":
    dead_tree()
    sys.exit(0)
