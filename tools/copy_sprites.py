#!/usr/bin/env python3
"""Copia a art/ los sprites listados en tools/sprites_manifest.json.

sprites/ es la fuente local (Pokémon Showdown, fuera de git); art/ es lo que importa Godot.
Uso: python3 tools/copy_sprites.py
"""
import json
import sys
from pathlib import Path

from PIL import Image

from make_back_sprite import make_back
from overworld_sheet import extract

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "sprites"
MANIFEST = ROOT / "tools" / "sprites_manifest.json"


def main() -> int:
    entries = json.loads(MANIFEST.read_text(encoding="utf-8"))["sprites"]
    missing = 0
    for entry in entries:
        src = SOURCE / entry["src"]
        dst = ROOT / entry["dst"]
        if not src.exists():
            print(f"FALTA {src.relative_to(ROOT)}", file=sys.stderr)
            missing += 1
            continue
        image = Image.open(src).convert("RGBA")
        sheet = entry.get("overworld_sheet")
        if sheet:
            out = extract(image, sheet["cell"], sheet["pitch"], sheet["blocks"])
            dst.parent.mkdir(parents=True, exist_ok=True)
            out.save(dst)
            print(f"{entry['src']} -> {entry['dst']} hoja overworld {out.size[0]}x{out.size[1]}")
            continue
        if entry.get("crop"):
            bbox = image.getchannel("A").getbbox()
            if bbox:
                image = image.crop(bbox)
        dst.parent.mkdir(parents=True, exist_ok=True)
        image.save(dst)
        print(f"{entry['src']} -> {entry['dst']} {image.size[0]}x{image.size[1]}")
        generated = entry.get("generate_back")
        if generated:
            back, changed = make_back(image, tuple(generated["face_box"]), tuple(generated["hair"]))
            back_dst = ROOT / generated["dst"]
            back.save(back_dst)
            print(f"  espalda generada -> {generated['dst']} ({changed} px de cara)")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
