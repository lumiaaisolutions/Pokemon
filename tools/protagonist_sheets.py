#!/usr/bin/env python3
"""Convierte las hojas overworld de los 10 protagonistas al formato de Nate.

Salida (art/trainers/<id>_overworld.png): 3 columnas (parado, paso A, paso B) × 8 filas
(caminar abajo, izquierda, derecha, arriba; correr abajo, izquierda, derecha, arriba),
celdas de 32×32 con los pies en la última fila de píxeles y la cabeza centrada.

Cada fuente se describe en CHARACTERS: regiones (bloques) de la hoja, el orden de las
filas detectadas (dirección) y el orden de los cuadros. Los cuadros se detectan como
manchas sobre el fondo (el color de la esquina y los colores de fondo de celda listados).
Si un personaje no trae correr, se reutiliza caminar; si no trae derecha, se refleja
la izquierda. Uso: python3 tools/protagonist_sheets.py [--debug]
(--debug guarda hojas numeradas en el directorio temporal para revisar el orden).
"""
import os
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "sprites" / "overworld" / "protagonists"
OUT = ROOT / "art" / "trainers"
CELL = 32
DIRECTIONS = ["down", "left", "right", "up"]

# rows: dirección de cada fila detectada (de arriba abajo); None = se ignora.
# frames: índices (de izquierda a derecha en la fila) para parado, paso A y paso B.
CHARACTERS = {
    "red": {"file": "hgss_trainers_overworld.png", "cells": {"origin": (0, 640), "pitch": (32, 32), "size": (32, 32), "grid": (3, 4)},
            # Bloque de 12 cuadros de HGSS (orden medido con la piel de la cara).
            "order": {"down": [5, 8, 11], "left": [3, 6, 9], "right": [1, 4, 7], "up": [0, 2, 10]}},
    "ethan": {"file": "hgss_ethan.png",
              "walk": {"box": (0, 0, 70, 122), "rows": ["down", "left", "up", "right"], "frames": [1, 0, 2]},
              "run": {"box": (85, 0, 160, 122), "rows": ["up", "left", "down", "right"], "frames": [1, 0, 2]}},
    "lucas": {"file": "candidates/plat_lucas.png",
              "walk": {"box": (0, 0, 140, 140), "rows": ["down", "up", "left", "right"], "frames": [0, 1, 3]},
              "run": {"box": (170, 0, 310, 140), "rows": ["down", "up", "left", "right"], "frames": [0, 1, 3]}},
    "brendan": {"file": "candidates/cand_brendan_hyo_0.png",
                "walk": {"box": (0, 0, 70, 122), "rows": ["down", "left", "up", "right"], "frames": [1, 0, 2]},
                "run": {"box": (85, 0, 160, 122), "rows": ["up", "left", "down", "right"], "frames": [1, 0, 2]}},
    "calem": {"file": "candidates/cand_calem_tobalcr.png", "scale": 2,
              "walk": {"box": (0, 0, 256, 256), "rows": ["down", "left", "right", "up"], "frames": [0, 1, 3]}},
    "leaf": {"file": "candidates/cand_leaf_zender.png",
             "walk": {"box": (0, 0, 95, 126), "rows": ["up", "down", "left", "right"], "frames": [0, 1, 2]}},
    "lyra": {"file": "hgss_lyra.png",
             "walk": {"box": (0, 0, 100, 125), "rows": ["down", "left", "up", "right"], "frames": [1, 0, 2]},
             "run": {"box": (110, 0, 215, 125), "rows": ["down", "left", "up", "right"], "frames": [1, 0, 2]}},
    "dawn": {"file": "candidates/plat_dawn.png",
             "walk": {"box": (0, 0, 140, 140), "rows": ["down", "up", "left", "right"], "frames": [0, 1, 3]},
             "run": {"box": (170, 0, 310, 140), "rows": ["down", "up", "left", "right"], "frames": [0, 1, 3]}},
    "may": {"file": "candidates/cand_may_zender_full.png",
            "walk": {"box": (0, 0, 72, 126), "rows": ["up", "down", "left", "right"], "frames": [0, 1, 2]}},
    "serena": {"file": "candidates/cand_serena_zender_full.png",
               "walk": {"box": (0, 0, 72, 118), "rows": ["up", "down", "left", "right"], "frames": [0, 1, 2]}},
}


def is_background(pixel, keys) -> bool:
    return pixel[3] < 16 or pixel[:3] in keys


def background_keys(image: Image.Image, box) -> set:
    """Colores de fondo: la esquina de la hoja y los colores que llenan bordes de celda."""
    px = image.load()
    keys = {px[0, 0][:3]}
    x0, y0, x1, y1 = box
    counts: dict = {}
    for y in range(y0, min(y1, image.height)):
        for x in range(x0, min(x1, image.width)):
            c = px[x, y]
            if c[3] >= 16:
                counts[c[:3]] = counts.get(c[:3], 0) + 1
    # Colores muy abundantes (fondos de celda) también son fondo.
    area = max(1, (x1 - x0) * (y1 - y0))
    for color, n in counts.items():
        if n > area * 0.18:
            keys.add(color)
    return keys


def blobs(image: Image.Image, box, keys) -> list:
    px = image.load()
    x0, y0, x1, y1 = box
    x1, y1 = min(x1, image.width), min(y1, image.height)
    seen = set()
    found = []
    for y in range(y0, y1):
        for x in range(x0, x1):
            if (x, y) in seen or is_background(px[x, y], keys):
                continue
            queue = deque([(x, y)])
            seen.add((x, y))
            bx0 = bx1 = x
            by0 = by1 = y
            n = 0
            while queue:
                cx, cy = queue.popleft()
                n += 1
                bx0, bx1, by0, by1 = min(bx0, cx), max(bx1, cx), min(by0, cy), max(by1, cy)
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if x0 <= nx < x1 and y0 <= ny < y1 and (nx, ny) not in seen and not is_background(px[nx, ny], keys):
                            seen.add((nx, ny))
                            queue.append((nx, ny))
            if n > 40:
                found.append((bx0, by0, bx1 + 1, by1 + 1))
    # Une manchas que se solapan (pelo o accesorios separados del cuerpo).
    merged = True
    while merged:
        merged = False
        for i in range(len(found)):
            for j in range(i + 1, len(found)):
                a, b = found[i], found[j]
                if a[0] < b[2] + 1 and b[0] < a[2] + 1 and a[1] < b[3] + 1 and b[1] < a[3] + 1:
                    found[i] = (min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3]))
                    found.pop(j)
                    merged = True
                    break
            if merged:
                break
    return found


def rows_of(boxes: list) -> list:
    """Agrupa las manchas en filas por su centro vertical y las ordena por x."""
    boxes = sorted(boxes, key=lambda b: (b[1] + b[3]) / 2)
    rows: list = []
    for b in boxes:
        center = (b[1] + b[3]) / 2
        if rows and abs(center - rows[-1][0]) < 10:
            rows[-1][1].append(b)
        else:
            rows.append([center, [b]])
    return [sorted(r[1], key=lambda b: b[0]) for r in rows]


def cut(image: Image.Image, box, keys) -> Image.Image:
    frame = image.crop(box).convert("RGBA")
    px = frame.load()
    for y in range(frame.height):
        for x in range(frame.width):
            if is_background(px[x, y], keys):
                px[x, y] = (0, 0, 0, 0)
    return frame


def place(frame: Image.Image) -> Image.Image:
    """Pies abajo y cabeza centrada en una celda de CELL×CELL."""
    bbox = frame.getbbox()
    if bbox is None:
        return Image.new("RGBA", (CELL, CELL))
    frame = frame.crop(bbox)
    px = frame.load()
    xs = [x for y in range(min(10, frame.height)) for x in range(frame.width) if px[x, y][3] > 0]
    head = sum(xs) / len(xs) if xs else frame.width / 2
    cell = Image.new("RGBA", (CELL, CELL))
    cell.alpha_composite(frame.crop((0, max(0, frame.height - CELL), frame.width, frame.height)),
                         (int(round(CELL / 2 - head)), CELL - min(frame.height, CELL)))
    return cell


def extract(spec: dict, image: Image.Image) -> dict:
    """{dirección: [parado, paso A, paso B]} de un bloque."""
    keys = background_keys(image, spec["box"])
    rows = rows_of(blobs(image, spec["box"], keys))
    result = {}
    for direction, row in zip(spec["rows"], rows):
        if direction is None or direction in result:
            continue
        picked = [row[i] for i in spec["frames"] if i < len(row)]
        if len(picked) < 3:
            continue
        result[direction] = [place(cut(image, b, keys)) for b in picked]
    if "right" not in result and "left" in result:
        result["right"] = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in result["left"]]
    return result


def extract_cells(spec: dict, image: Image.Image) -> list:
    """Cuadros de una rejilla fija (para el bloque de Red), en orden de lectura."""
    (ox, oy), (px_, py_), (w, h), (cols, rows) = spec["origin"], spec["pitch"], spec["size"], spec["grid"]
    # Fondo del bloque y las líneas que separan los bloques de la hoja.
    keys = background_keys(image, (ox, oy, ox + cols * px_, oy + rows * py_)) | {image.getpixel((ox + 1, oy + 1))[:3]}
    for y in range(oy, oy + rows * py_):
        for x in (ox + cols * px_ - 1, ox + cols * px_ - 2):
            keys.add(image.getpixel((x, y))[:3])
    return [place(cut(image, (ox + c * px_, oy + r * py_, ox + c * px_ + w, oy + r * py_ + h), keys)) for r in range(rows) for c in range(cols)]


def build(name: str, config: dict, debug_dir: Path | None) -> Path | None:
    image = Image.open(SRC / config["file"]).convert("RGBA")
    if config.get("scale", 1) > 1:
        s = config["scale"]
        image = image.resize((image.width // s, image.height // s), Image.NEAREST)
        for block in ("walk", "run"):
            if block in config:
                b = config[block]["box"]
                config[block] = dict(config[block], box=tuple(v // s for v in b))
    if "cells" in config:
        frames = extract_cells(config["cells"], image)
        if config.get("order") is None:
            if debug_dir:
                save_debug(debug_dir / f"{name}_cells.png", [frames])
            return None
        walk = {d: [frames[i] for i in idx] for d, idx in config["order"].items()}
        run = walk
    else:
        walk = extract(config["walk"], image)
        run = extract(config["run"], image) if "run" in config else walk
    if debug_dir:
        save_debug(debug_dir / f"{name}.png", [walk.get(d, []) for d in DIRECTIONS] + [run.get(d, []) for d in DIRECTIONS])
    missing = [d for d in DIRECTIONS if d not in walk or d not in run]
    if missing:
        print(f"{name}: faltan direcciones {missing}")
        return None
    sheet = Image.new("RGBA", (CELL * 3, CELL * 8))
    for block_index, block in enumerate((walk, run)):
        for d_index, direction in enumerate(DIRECTIONS):
            for f_index, frame in enumerate(block[direction]):
                sheet.alpha_composite(frame, (f_index * CELL, (block_index * 4 + d_index) * CELL))
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}_overworld.png"
    sheet.save(path)
    return path


def save_debug(path: Path, rows: list) -> None:
    columns = max((len(r) for r in rows), default=1)
    scale = 3
    sheet = Image.new("RGBA", (columns * CELL * scale + 30, len(rows) * CELL * scale), (60, 90, 60, 255))
    draw = ImageDraw.Draw(sheet)
    for r, row in enumerate(rows):
        draw.text((2, r * CELL * scale + 4), str(r), fill=(255, 255, 0, 255))
        for c, frame in enumerate(row):
            sheet.alpha_composite(frame.resize((CELL * scale, CELL * scale), Image.NEAREST), (30 + c * CELL * scale, r * CELL * scale))
            draw.text((30 + c * CELL * scale + 2, r * CELL * scale + 2), str(r * columns + c if len(rows) == 1 else c), fill=(255, 255, 255, 255))
    sheet.save(path)


def main() -> int:
    debug_dir = Path(os.environ.get("TMPDIR", "/tmp")) / "protagonists_debug" if "--debug" in sys.argv else None
    if debug_dir:
        debug_dir.mkdir(parents=True, exist_ok=True)
    for name, config in CHARACTERS.items():
        path = build(name, dict(config), debug_dir)
        print(f"{name}: {path.relative_to(ROOT) if path else 'sin salida'}")
    if debug_dir:
        print("depuración en", debug_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
