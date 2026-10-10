#!/usr/bin/env python3
"""Hojas de los líderes de gimnasio y del Alto Mando en el formato del juego.

Fuentes (sprites/npc_src/, no versionadas):
- b2w2_overworld_entities.png (B2W2 "Overworld Entities", The Spriters Resource):
  bloques completos de 12 cuadros ("A") y bloques de 7 cuadros del Torneo Mundial ("B"),
  con la misma numeración que tools/build_npc_sheets.py.
- prof_hgss_trainers.png (HGSS "Trainer Overworlds", ripeado por Dragoon): celdas de
  12 cuadros (3 × 4) en una cuadrícula de 10 columnas ("H").
- prof_plat_npcs.png (Platino "NPCs", ripeado por spaceemotion): columnas de 9 cuadros ("P").

Catálogo aprobado por Fernando (2026-10-10, ver docs/sistemas/regiones.md). Salida:
art/npcs/lider_<id>.png y art/npcs/alto_<id>.png (96×256, como las de los NPC).

Uso: python3 tools/build_leader_sheets.py
"""
from PIL import Image

from build_npc_sheets import ROOT, SRC, OUT, CELL, blocks, frame, _has_body, frame_at
from protagonist_sheets import background_keys, blobs, rows_of, cut, place

LEADERS = {
    "brock": "B56", "misty": "B57", "ltsurge": "B58", "erika": "B59", "janine": "B66", "sabrina": "B60", "blaine": "B49",
    "falkner": "B61", "bugsy": "B62", "whitney": "B63", "morty": "B48", "jasmine": "B64", "pryce": "B50", "clair": "B65",
    "roxanne": "B55", "brawly": "B68", "wattson": "B69", "norman": "B70", "winona": "B71", "juan": "B51",
    "roark": "B72", "gardenia": "B73", "maylene": "B74", "crasherwake": "B75", "byron": "B76", "elesa": "B53",
    "steven": "B77", "cynthia": "A51", "alder": "A72", "clay": "A20", "skyla": "A21", "iris": "A23", "marlon": "A54",
    "brycen": "A22", "chuck": "A58", "flannery": "A60", "fantina": "A62", "wallace": "A63", "giovanni": "A56",
    "burgh": "A53", "drayden": "A59", "roxie": "A52", "cress": "A44", "chili": "A45", "koga": "H37", "blue": "H49",
}
ELITE = {"lance": "H40", "will": "H31", "bruno": "H38", "karen": "H39", "shauntal": "A24", "caitlin": "A26", "flint": "P5.13"}

HGSS = ROOT / "sprites" / "npc_src" / "prof_hgss_trainers.png"
PLAT = ROOT / "sprites" / "npc_src" / "prof_plat_npcs.png"
# Inicio de cada columna de la hoja de HGSS (medido: no son múltiplos exactos de 96).
HGSS_COLUMNS = [0, 96, 192, 288, 383, 479, 573, 669, 765, 861]
# Orden de los cuadros en una celda de HGSS (medido con la cara, como en protagonist_sheets.py).
HGSS_ORDER = {"down": [5, 8, 11], "left": [3, 6, 9], "right": [1, 4, 7], "up": [0, 2, 10]}
PLAT_ROWS = [97, 385, 673, 961, 1249, 1560]


def sheet_of(down, left, right, up):
    sheet = Image.new("RGBA", (CELL * 3, CELL * 8), (0, 0, 0, 0))
    for row, cells in enumerate([down, left, right, up]):
        for col in range(3):
            sheet.paste(cells[col], (col * CELL, row * CELL))
            sheet.paste(cells[col], (col * CELL, (row + 4) * CELL))
    return sheet


def from_full(image, block):
    color, frames = block
    arts = [frame(image, cell, color) for cell in frames]
    ok = [_has_body(a) for a in arts]
    # Lado sin cuadros (X en la fuente): el espejo del contrario; paso que falta: el quieto.
    for side, twin in ((3, 2), (2, 3)):
        if not ok[side * 3] and ok[twin * 3]:
            for col in range(3):
                source = arts[twin * 3 + col] if ok[twin * 3 + col] else arts[twin * 3]
                arts[side * 3 + col] = source.transpose(Image.FLIP_LEFT_RIGHT)
                ok[side * 3 + col] = True
    # Sin espalda (X en la fuente, p. ej. Chuck o Wallace del Torneo Mundial): el frente.
    if not ok[0] and ok[3]:
        for col in range(3):
            arts[col] = arts[3 + col] if ok[3 + col] else arts[3]
            ok[col] = True
    for i in range(12):
        if not ok[i]:
            arts[i] = arts[i - i % 3]
    up, down, left, right = arts[0:3], arts[3:6], arts[6:9], arts[9:12]
    return sheet_of(down, left, right, up)


def from_seven(image, block):
    """Bloques del Torneo Mundial: arriba ×2, abajo ×2, izquierda ×3. Varios traen cuadros
    vacíos o con una X (sin espalda o sin paso): se usa el cuadro quieto que sí exista."""
    color, frames = block
    arts = [frame(image, cell, color) for cell in frames[:7]]
    ok = [_has_body(a) for a in arts]
    front = arts[2] if ok[2] else next(a for a, good in zip(arts, ok) if good)
    down = [front, arts[3] if ok[3] else front, arts[3] if ok[3] else front]
    back = arts[0] if ok[0] else front
    up = [back, arts[1] if ok[1] else back, arts[1] if ok[1] else back]
    side = arts[4] if ok[4] else front
    left = [side, arts[5] if ok[5] else side, arts[6] if ok[6] else side]
    return sheet_of(down, left, [a.transpose(Image.FLIP_LEFT_RIGHT) for a in left], up)


def from_hgss(image, cell):
    """Celda de 12 cuadros (3 × 4): se buscan las figuras porque la rejilla no es exacta."""
    row, col = divmod(cell, 10)
    x1 = HGSS_COLUMNS[col + 1] if col + 1 < len(HGSS_COLUMNS) else image.width
    box = (HGSS_COLUMNS[col] + 1, row * 128 + 1, x1 - 1, row * 128 + 127)
    keys = background_keys(image, box)
    # Fuera las líneas que separan celdas (manchas muy angostas).
    figures = [b for r in rows_of([b for b in blobs(image, box, keys) if b[2] - b[0] > 8]) for b in r]
    cells = [place(cut(image, b, keys)) for b in figures]
    walk = {d: [cells[i] for i in idx] for d, idx in HGSS_ORDER.items()}
    return sheet_of(walk["down"], walk["left"], walk["right"], walk["up"])


def from_platinum(image, row, col):
    x, y = 17 + col * CELL, PLAT_ROWS[row]
    color = image.getpixel((x + 1, y + 1))
    cells = [frame_at(image, x, y + i * CELL, color) for i in range(9)]
    left = [cells[2], cells[7], cells[8]]
    return sheet_of([cells[0], cells[5], cells[6]], left, [c.transpose(Image.FLIP_LEFT_RIGHT) for c in left], [cells[1], cells[3], cells[4]])


def build(code, bw, full, seven, hgss, plat):
    kind = code[0]
    if kind == "A":
        return from_full(bw, full[int(code[1:])])
    if kind == "B":
        return from_seven(bw, seven[int(code[1:])])
    if kind == "H":
        return from_hgss(hgss, int(code[1:]))
    row, col = map(int, code[1:].split("."))
    return from_platinum(plat, row, col)


def main():
    bw = Image.open(SRC).convert("RGBA")
    every = blocks(bw)
    full = [b for b in every if len(b[1]) == 12]
    seven = [b for b in every if len(b[1]) in (7, 14)]
    hgss = Image.open(HGSS).convert("RGBA")
    plat = Image.open(PLAT).convert("RGBA")
    OUT.mkdir(parents=True, exist_ok=True)
    for prefix, table in (("lider", LEADERS), ("alto", ELITE)):
        for key, code in table.items():
            build(code, bw, full, seven, hgss, plat).save(OUT / f"{prefix}_{key}.png")
    print(f"{len(LEADERS)} líderes y {len(ELITE)} del Alto Mando en {OUT}")


if __name__ == "__main__":
    main()
