#!/usr/bin/env python3
"""Copia los íconos de los objetos del catálogo (creatures/data/items.json) desde
sprites/itemicons/ a art/items/. Los que no tienen ícono (p. ej. la Piedra Llave y
las megapiedras) se dibujan en el juego. Uso: python3 tools/copy_item_icons.py"""
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
catalog = json.loads((ROOT / "creatures" / "data" / "items.json").read_text(encoding="utf-8"))
out = ROOT / "art" / "items"
out.mkdir(parents=True, exist_ok=True)
missing = []
for item in catalog["items"]:
    name = item.get("icon", item["id"])
    if not name:
        continue
    src = ROOT / "sprites" / "itemicons" / f"{name}.png"
    if src.exists():
        shutil.copyfile(src, out / f"{item['id']}.png")
    else:
        missing.append(item["id"])
print(f"{len(catalog['items']) - len(missing)} íconos copiados; sin ícono: {missing}")
