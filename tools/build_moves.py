#!/usr/bin/env python3
"""Movimientos y listas oficiales de cada especie desde PokeAPI.

- creatures/data/moves.json: id -> nombre en español, tipo (0-17), potencia, precisión,
  clase (physical / special / status), categoría del efecto, curación, estado y drenaje.
- creatures/data/learnsets.json: especie -> {"level": [[nivel, id], ...] en orden,
  "other": [ids por MT y tutor]}, del juego más reciente que tenga cada lista.

Los CSV se descargan una vez a sprites/data/ (caché). Uso: python3 tools/build_moves.py
"""
import csv
import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "sprites" / "data"
BASE = "https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/{}.csv"
SPANISH = "7"
CLASSES = {"1": "status", "2": "physical", "3": "special"}
# Categorías de move_meta (meta_category_id).
CATEGORIES = {"0": "damage", "1": "ailment", "2": "buff", "3": "heal", "4": "damage_ailment", "5": "swagger",
              "6": "damage_lower", "7": "damage_raise", "8": "drain", "9": "ohko", "10": "field", "11": "field",
              "12": "force_switch", "13": "unique"}


def load(name: str) -> list[dict]:
    path = DATA / f"{name}.csv"
    if not path.exists():
        path.write_bytes(urllib.request.urlopen(BASE.format(name), timeout=60).read())
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def main() -> int:
    species = {r["id"]: r["identifier"] for r in load("pokemon_species") if int(r["id"]) <= 1025}
    names = {r["move_id"]: r["name"] for r in load("move_names") if r["local_language_id"] == SPANISH}
    meta = {r["move_id"]: r for r in load("move_meta")}
    moves = {}
    for r in load("moves"):
        if int(r["id"]) > 10000 or not r["type_id"]:
            continue
        m = meta.get(r["id"], {})
        moves[r["identifier"]] = {
            "name": names.get(r["id"], r["identifier"].replace("-", " ").title()),
            "type": int(r["type_id"]) - 1,
            "power": int(r["power"] or 0),
            "accuracy": int(r["accuracy"] or 100),
            "class": CLASSES.get(r["damage_class_id"], "status"),
            "category": CATEGORIES.get(m.get("meta_category_id", "0"), "unique"),
            "healing": int(m.get("healing", 0) or 0),
            "drain": int(m.get("drain", 0) or 0),
            "ailment": int(m.get("meta_ailment_id", 0) or 0),
            "ailment_chance": int(m.get("ailment_chance", 0) or 0),
            "priority": int(r["priority"] or 0),
        }
    move_ids = {r["id"]: r["identifier"] for r in load("moves")}
    # Por especie: el grupo de versiones más reciente en que aparece.
    by_species: dict[str, dict[int, list]] = {}
    for r in load("pokemon_moves"):
        if r["pokemon_id"] not in species:
            continue
        by_species.setdefault(r["pokemon_id"], {}).setdefault(int(r["version_group_id"]), []).append(r)
    learnsets = {}
    for sid, groups in by_species.items():
        # Por nivel: el juego más reciente que los tenga (algunos solo traen MT).
        with_level = [g for g in sorted(groups, reverse=True) if any(r["pokemon_move_method_id"] == "1" for r in groups[g])]
        level_rows = groups[with_level[0]] if with_level else []
        level = sorted({(int(r["level"] or 0), move_ids[r["move_id"]]) for r in level_rows if r["pokemon_move_method_id"] == "1" and move_ids.get(r["move_id"]) in moves})
        seen = set()
        ordered = []
        for lvl, move in level:
            if move not in seen:
                seen.add(move)
                ordered.append([lvl, move])
        with_other = [g for g in sorted(groups, reverse=True) if any(r["pokemon_move_method_id"] in ("3", "4") for r in groups[g])]
        other_rows = groups[with_other[0]] if with_other else []
        other = sorted({move_ids[r["move_id"]] for r in other_rows if r["pokemon_move_method_id"] in ("3", "4") and move_ids.get(r["move_id"]) in moves} - seen)
        learnsets[species[sid]] = {"level": ordered, "other": other}
    used = {m for ls in learnsets.values() for m in [x[1] for x in ls["level"]] + ls["other"]}
    moves = {k: v for k, v in moves.items() if k in used}
    (ROOT / "creatures" / "data" / "moves.json").write_text(json.dumps(moves, ensure_ascii=False), encoding="utf-8")
    (ROOT / "creatures" / "data" / "learnsets.json").write_text(json.dumps(learnsets, ensure_ascii=False), encoding="utf-8")
    print(f"{len(moves)} movimientos; {len(learnsets)} especies con lista")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
