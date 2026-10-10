#!/usr/bin/env python3
"""Hojas de los NPC (clases de BW2) en el formato del juego.

Fuente: sprites/npc_src/b2w2_overworld_entities.png (The Spriters Resource, B2W2
"Overworld Entities", ripeado por Barubary). Cada personaje es un bloque con su color de
fondo y 12 cuadros de 32 px: arriba ×3, abajo ×3, izquierda ×3, derecha ×3 (quieto y
dos pasos).

Salida: art/npcs/<clave>.png de 96×256 (3 columnas × 8 filas): filas 0–3 caminar
(abajo, izquierda, derecha, arriba) y 4–7 correr (las mismas), como las hojas de los
protagonistas (DirectionalSprite).

Uso: python3 tools/build_npc_sheets.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "sprites" / "npc_src" / "b2w2_overworld_entities.png"
OUT = ROOT / "art" / "npcs"
CELL = 32

# Clave -> índice del bloque completo (orden de lectura de la hoja). Ver core/npc_looks.gd.
LOOKS = {
    "joven_a": 0, "chica_a": 1, "colegial": 2, "pokefan": 3, "joven_b": 4, "nino": 5, "abuela": 6,
    "karateka_a": 7, "doctor": 8, "dama_a": 9, "obrero_a": 10, "musico_a": 11, "joven_c": 12, "obrero_b": 13,
    "dependiente": 14, "cientifica": 15, "dama_sombrilla": 16, "ornitologo": 18, "enfermera": 26,
    "chica_b": 27, "joven_d": 28, "joven_e": 29, "marinero": 31, "musico_b": 40, "chica_c": 41,
    "musica": 42, "musico_c": 43, "guay_a": 44, "guay_b": 45, "medium": 46, "motorista": 48, "policia": 49,
    "joven_f": 53, "abuelo_a": 55, "abuelo_b": 59, "mochilero": 64, "dama_b": 65, "guay_chica": 68,
    "karateka_b": 96,
    # Personajes importantes.
    "hugh": 25,
}
# Personajes de 7 cuadros (arriba ×2, abajo ×2, izquierda ×3; la derecha es el espejo):
# clave -> índice entre los bloques de 7 cuadros.
LOOKS_7 = {"cientifico": 39}


def blocks(image):
    px = image.load()
    cols, rows = image.width // CELL, image.height // CELL
    def bg(cx, cy):
        return px[cx * CELL, cy * CELL]
    def has_art(cx, cy, color):
        for y in range(cy * CELL, cy * CELL + CELL):
            for x in range(cx * CELL, cx * CELL + CELL):
                p = px[x, y]
                if p[3] > 0 and p[:3] != color[:3]:
                    return True
        return False
    seen, result = set(), []
    for cy in range(rows):
        for cx in range(cols):
            if (cx, cy) in seen:
                continue
            color = bg(cx, cy)
            if color[3] == 0 or color[:3] == (255, 255, 255):
                continue
            stack, cells = [(cx, cy)], []
            while stack:
                a, b = stack.pop()
                if (a, b) in seen or not (0 <= a < cols and 0 <= b < rows) or bg(a, b)[:3] != color[:3]:
                    continue
                seen.add((a, b))
                cells.append((a, b))
                stack += [(a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)]
            frames = sorted([c for c in cells if has_art(c[0], c[1], color)], key=lambda c: (c[1], c[0]))
            result.append((color, frames))
    return result


def frame(image, cell, color):
    cx, cy = cell
    crop = image.crop((cx * CELL, cy * CELL, cx * CELL + CELL, cy * CELL + CELL))
    data = [(0, 0, 0, 0) if p[:3] == color[:3] else p for p in crop.getdata()]
    crop.putdata(data)
    return crop


def _has_body(art):
    """¿Es un cuadro real? (una X de relleno tiene pocos píxeles y de un solo color)."""
    pixels = [p for p in art.getdata() if p[3] > 0]
    return len(pixels) > 90 and len(set(pixels)) > 3


# Profesores de Platino (sprites/npc_src/prof_plat_npcs.png, "NPCs" de The Spriters
# Resource, ripeado por spaceemotion): columnas de 9 cuadros en la sección "Other".
# Orden: frente, espalda, perfil, espalda×2 (pasos), frente×2, perfil×2.
PLATINUM_COLUMNS = {"prof_rowan": (241, 1560), "prof_oak": (273, 1560)}


def columns_from_platinum():
    path = ROOT / "sprites" / "npc_src" / "prof_plat_npcs.png"
    if not path.exists():
        return
    image = Image.open(path).convert("RGBA")
    for key, (x, y) in PLATINUM_COLUMNS.items():
        color = image.getpixel((x + 1, y + 1))
        cells = [frame_at(image, x, y + i * CELL, color) for i in range(9)]
        down = [cells[0], cells[5], cells[6]]
        up = [cells[1], cells[3], cells[4]]
        left = [cells[2], cells[7], cells[8]]
        right = [c.transpose(Image.FLIP_LEFT_RIGHT) for c in left]
        sheet = Image.new("RGBA", (CELL * 3, CELL * 8), (0, 0, 0, 0))
        for row, group in enumerate([down, left, right, up]):
            for col in range(3):
                sheet.paste(group[col], (col * CELL, row * CELL))
                sheet.paste(group[col], (col * CELL, (row + 4) * CELL))
        sheet.save(OUT / f"{key}.png")


def frame_at(image, x, y, color):
    crop = image.crop((x, y, x + CELL, y + CELL))
    crop.putdata([(0, 0, 0, 0) if abs(p[0] - color[0]) + abs(p[1] - color[1]) + abs(p[2] - color[2]) < 6 else p for p in crop.getdata()])
    return crop


def main():
    image = Image.open(SRC).convert("RGBA")
    every = blocks(image)
    full = [b for b in every if len(b[1]) == 12]
    seven = [b for b in every if len(b[1]) in (7, 14)]
    OUT.mkdir(parents=True, exist_ok=True)
    # Del bloque (arriba, abajo, izquierda, derecha) a las filas del juego (abajo, izquierda, derecha, arriba).
    order = [1, 2, 3, 0]
    for key, index in LOOKS.items():
        color, frames = full[index]
        arts = [frame(image, cell, color) for cell in frames]
        # Algunos personajes traen cuadros vacíos (una X en la fuente): si falta un paso se
        # usa la pose quieta; si falta todo un lado, el espejo del lado contrario.
        ok = [_has_body(a) for a in arts]
        for direction in range(4):
            stand = direction * 3
            if not ok[stand]:
                twin = {2: 3, 3: 2}.get(direction, 1 - direction)
                if ok[twin * 3]:
                    for col in range(3):
                        source = arts[twin * 3 + col] if ok[twin * 3 + col] else arts[twin * 3]
                        arts[stand + col] = source.transpose(Image.FLIP_LEFT_RIGHT) if direction >= 2 else source
                        ok[stand + col] = True
            for col in (1, 2):
                if not ok[stand + col]:
                    arts[stand + col] = arts[stand]
        sheet = Image.new("RGBA", (CELL * 3, CELL * 8), (0, 0, 0, 0))
        for row, direction in enumerate(order):
            for col in range(3):
                art = arts[direction * 3 + col]
                sheet.paste(art, (col * CELL, row * CELL))
                sheet.paste(art, (col * CELL, (row + 4) * CELL))
        sheet.save(OUT / f"{key}.png")
    for key, index in LOOKS_7.items():
        color, frames = seven[index]
        arts = [frame(image, cell, color) for cell in frames[:7]]
        up = [arts[0], arts[1], arts[1]]
        down = [arts[2], arts[3], arts[3]]
        left = [arts[4], arts[5], arts[6]]
        right = [a.transpose(Image.FLIP_LEFT_RIGHT) for a in left]
        sheet = Image.new("RGBA", (CELL * 3, CELL * 8), (0, 0, 0, 0))
        for row, cells in enumerate([down, left, right, up]):
            for col in range(3):
                sheet.paste(cells[col], (col * CELL, row * CELL))
                sheet.paste(cells[col], (col * CELL, (row + 4) * CELL))
        sheet.save(OUT / f"{key}.png")
    columns_from_platinum()
    print(f"{len(LOOKS) + len(LOOKS_7)} hojas de NPC en {OUT}")


if __name__ == "__main__":
    main()
