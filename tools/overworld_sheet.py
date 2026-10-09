#!/usr/bin/env python3
"""Extrae una hoja overworld de B2W2 (celdas sobre fondo magenta con rejilla verde)
a una hoja limpia y transparente para Godot.

Salida: columnas = frames (parado, paso A, paso B); filas = bloques × direcciones en
orden DIRECTIONS (abajo, izquierda, derecha, arriba). Con walk y run: filas 0–3 caminar
y 4–7 correr.
"""
from PIL import Image

DIRECTIONS = ["down", "left", "right", "up"]
BACKGROUND = (255, 0, 255)


def extract(image: Image.Image, cell: int, pitch: int, blocks: list[dict]) -> Image.Image:
    """blocks: [{"x": px, "y": px, "frames": n, "rows": {"up": 0, "down": 1, ...}}, ...]"""
    image = image.convert("RGBA")
    frames = max(b["frames"] for b in blocks)
    out = Image.new("RGBA", (frames * cell, len(blocks) * len(DIRECTIONS) * cell), (0, 0, 0, 0))
    for b_index, block in enumerate(blocks):
        for d_index, direction in enumerate(DIRECTIONS):
            source_row = block["rows"][direction]
            for f in range(block["frames"]):
                x = block["x"] + f * pitch
                y = block["y"] + source_row * pitch
                tile = image.crop((x, y, x + cell, y + cell))
                pixels = tile.load()
                for ty in range(cell):
                    for tx in range(cell):
                        if pixels[tx, ty][:3] == BACKGROUND:
                            pixels[tx, ty] = (0, 0, 0, 0)
                out.paste(tile, (f * cell, (b_index * len(DIRECTIONS) + d_index) * cell))
    return out
