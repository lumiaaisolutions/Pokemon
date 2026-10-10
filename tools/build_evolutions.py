#!/usr/bin/env python3
"""Genera creatures/data/evolutions.json: a qué evoluciona cada especie y cómo.

Fuente: CSV de PokeAPI en sprites/data/ (pokemon_species, pokemon_evolution, items,
evolution_triggers). El juego no tiene niveles, así que el método oficial se traduce
(ver core/evolution.gd):
- level: nivel mínimo oficial -> victorias en combate con ese Pokémon.
- item: piedra u objeto (se usa desde la Mochila).
- friendship / trade / other: vínculo con el Pokémon.

Uso: python3 tools/build_evolutions.py
"""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "sprites" / "data"
OUT = ROOT / "creatures" / "data" / "evolutions.json"


def rows(name):
    with open(DATA / f"{name}.csv", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


species = {r["id"]: r for r in rows("pokemon_species")}
items = {r["id"]: r["identifier"] for r in rows("items")}
triggers = {r["id"]: r["identifier"] for r in rows("evolution_triggers")}

result = {}
seen = set()
for r in rows("pokemon_evolution"):
    to = species.get(r["evolved_species_id"])
    if to is None or not to["evolves_from_species_id"]:
        continue
    source = species[to["evolves_from_species_id"]]
    if int(source["id"]) > 1025 or int(to["id"]) > 1025:
        continue
    key = (source["identifier"], to["identifier"])
    if key in seen:
        continue
    seen.add(key)
    trigger = triggers.get(r["evolution_trigger_id"], "unclassified")
    entry = {"to": to["identifier"]}
    if trigger == "use-item" and r["trigger_item_id"]:
        entry["method"] = "item"
        entry["item"] = {"thunder-stone": "thunderstone"}.get(items.get(r["trigger_item_id"], ""), items.get(r["trigger_item_id"], ""))
    elif trigger == "level-up" and r["minimum_happiness"]:
        entry["method"] = "friendship"
    elif trigger == "level-up" and r["minimum_level"]:
        entry["method"] = "level"
        entry["level"] = int(r["minimum_level"])
    elif trigger == "trade":
        entry["method"] = "trade"
    else:
        entry["method"] = "other"
    if r["time_of_day"]:
        entry["time"] = r["time_of_day"]
    result.setdefault(source["identifier"], []).append(entry)

OUT.write_text(json.dumps(result, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")
print(f"{len(result)} especies con evolución, {sum(len(v) for v in result.values())} caminos -> {OUT}")
