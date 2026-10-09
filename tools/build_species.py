#!/usr/bin/env python3
"""Genera los datos de especies (.tres) y sus hojas overworld.

Fuentes:
- sprites/data/*.csv: CSV de PokeAPI (especies, tipos, stats, nombres en español).
- Hojas overworld de pokeemerald-expansion (GitHub, rh-hideout), cacheadas en
  sprites/overworld/pokemon/<nombre>.png.

Salida:
- art/pokemon/<identifier>/overworld.png: 2 columnas (pasos) × 4 filas (abajo,
  izquierda, derecha, arriba), celdas de 32 px, fondo transparente.
- creatures/data/species/<identifier>.tres (SpeciesData).
- creatures/data/basic_pool.tres (SpeciesPool con los básicos no legendarios).
- world/biomes/pradera_encounters.tres (EncounterTable de la Pradera).

Uso: python3 tools/build_species.py
"""
import csv
import shutil
import sys
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "sprites" / "data"
CACHE = ROOT / "sprites" / "overworld" / "pokemon"
OVERWORLD_URL = "https://raw.githubusercontent.com/rh-hideout/pokeemerald-expansion/master/graphics/pokemon/{}/overworld.png"
SPANISH = "7"  # local_language_id de español en PokeAPI
CELL = 32

# Temperamentos (SpeciesData.Temperament): 0 deambula, 1 curioso, 2 tímido, 3 agresivo.
WANDER, CURIOUS, SHY, AGGRESSIVE = range(4)
COMMON, RARE = range(2)

# Roster aprobado por Fernando (docs/ESTADO.md): temperamento y rareza de diseño.
ROSTER = {
    "venusaur": (WANDER, COMMON), "charizard": (AGGRESSIVE, COMMON), "blastoise": (WANDER, COMMON),
    "pidgeot": (SHY, COMMON), "ampharos": (CURIOUS, COMMON), "sawsbuck": (SHY, COMMON), "absol": (AGGRESSIVE, RARE),
    "heracross": (AGGRESSIVE, COMMON), "swampert": (WANDER, COMMON), "leavanny": (CURIOUS, COMMON), "gardevoir": (SHY, RARE),
    "aggron": (AGGRESSIVE, COMMON), "aerodactyl": (AGGRESSIVE, COMMON), "excadrill": (WANDER, COMMON), "froslass": (SHY, RARE),
    "garchomp": (AGGRESSIVE, RARE),
}
# Especiales que PokeAPI no marca como legendarios pero no tienen sentido como inicial:
# Ultraentes (Gen 7) y Pokémon paradoja (Gen 9).
SPECIAL_NOT_STARTER = {
    "nihilego", "buzzwole", "pheromosa", "xurkitree", "celesteela", "kartana", "guzzlord", "poipole", "stakataka", "blacephalon",
    "great-tusk", "scream-tail", "brute-bonnet", "flutter-mane", "slither-wing", "sandy-shocks", "iron-treads", "iron-bundle",
    "iron-hands", "iron-jugulis", "iron-moth", "iron-thorns", "roaring-moon", "iron-valiant", "walking-wake", "iron-leaves",
    "gouging-fire", "raging-bolt", "iron-boulder", "iron-crown",
}
PRADERA = [("pidgeot", 35.0), ("ampharos", 30.0), ("sawsbuck", 30.0), ("absol", 5.0)]


def load_csv(name: str) -> list[dict]:
    with open(DATA / name, encoding="utf-8") as f:
        return list(csv.DictReader(f))


def pokeemerald_name(identifier: str, dirs: set[str]) -> str:
    for candidate in (identifier.replace("-", "_"), identifier.replace("-", "")):
        if candidate in dirs:
            return candidate
    raise KeyError(identifier)


def default_temperament(stats: dict) -> int:
    """Temperamento por stats para especies fuera del roster."""
    if stats["attack"] >= 90 or stats["attack"] > stats["defense"] + 25:
        return AGGRESSIVE
    if stats["speed"] >= 80 and stats["hp"] < 60:
        return SHY
    if stats["sp_attack"] > stats["attack"]:
        return CURIOUS
    return WANDER


def overworld_sheet(source_name: str) -> tuple[Image.Image, int]:
    """Convierte la hoja de pokeemerald (6 frames: abajo×2, arriba×2, lado izquierdo×2)
    a 2 columnas × 4 filas (abajo, izquierda, derecha, arriba) con fondo transparente."""
    cached = CACHE / f"{source_name}.png"
    if not cached.exists():
        CACHE.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(OVERWORLD_URL.format(source_name), cached)
    raw = Image.open(cached)
    if raw.mode == "P":
        # El índice 0 de la paleta es el fondo en las hojas de GBA.
        raw.info["transparency"] = 0
    image = raw.convert("RGBA")
    frames = [image.crop((i * CELL, 0, (i + 1) * CELL, CELL)) for i in range(image.width // CELL)]
    down, up, left = frames[0:2], frames[2:4], frames[4:6]
    right = [f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in left]
    sheet = Image.new("RGBA", (CELL * 2, CELL * 4), (0, 0, 0, 0))
    for row, pair in enumerate((down, left, right, up)):
        for col, frame in enumerate(pair):
            sheet.paste(frame, (col * CELL, row * CELL))
    # Filas vacías bajo los pies: el mínimo entre todos los frames (el que más baja).
    foot = CELL
    for frame in frames:
        bbox = frame.getchannel("A").getbbox()
        if bbox:
            foot = min(foot, CELL - bbox[3])
    return sheet, foot


def tres_species(sp: dict) -> str:
    types = ", ".join(str(t) for t in sp["types"])
    return f"""[gd_resource type="Resource" script_class="SpeciesData" format=3]

[ext_resource type="Script" path="res://creatures/data/species_data.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://art/pokemon/{sp['identifier']}/overworld.png" id="2_ow"]

[resource]
script = ExtResource("1_script")
dex_id = {sp['id']}
identifier = "{sp['identifier']}"
display_name = "{sp['name']}"
types = Array[int]([{types}])
hp = {sp['hp']}
attack = {sp['attack']}
defense = {sp['defense']}
sp_attack = {sp['sp_attack']}
sp_defense = {sp['sp_defense']}
speed = {sp['speed']}
temperament = {sp['temperament']}
rarity = {sp['rarity']}
overworld_sheet = ExtResource("2_ow")
foot_offset_px = {sp['foot']}
"""


def tres_list(script_class: str, script_path: str, field: str, identifiers: list[str], extra: str = "") -> str:
    """Recurso con un arreglo tipado Array[SpeciesData] de especies."""
    lines = [f'[gd_resource type="Resource" script_class="{script_class}" format=3]', "",
             f'[ext_resource type="Script" path="{script_path}" id="1_script"]',
             '[ext_resource type="Script" path="res://creatures/data/species_data.gd" id="1_species"]']
    for i, ident in enumerate(identifiers):
        lines.append(f'[ext_resource type="Resource" path="res://creatures/data/species/{ident}.tres" id="{i + 2}_sp"]')
    refs = ", ".join(f'ExtResource("{i + 2}_sp")' for i in range(len(identifiers)))
    lines += ["", "[resource]", 'script = ExtResource("1_script")',
              f'{field} = Array[ExtResource("1_species")]([{refs}])']
    if extra:
        lines.append(extra)
    return "\n".join(lines) + "\n"


def main() -> int:
    species_rows = {r["id"]: r for r in load_csv("pokemon_species.csv")}
    names = {r["pokemon_species_id"]: r["name"] for r in load_csv("pokemon_species_names.csv") if r["local_language_id"] == SPANISH}
    types: dict[str, list[int]] = {}
    for r in sorted(load_csv("pokemon_types.csv"), key=lambda r: int(r["slot"])):
        types.setdefault(r["pokemon_id"], []).append(int(r["type_id"]) - 1)
    stat_keys = {"1": "hp", "2": "attack", "3": "defense", "4": "sp_attack", "5": "sp_defense", "6": "speed"}
    stats: dict[str, dict] = {}
    for r in load_csv("pokemon_stats.csv"):
        if r["stat_id"] in stat_keys:
            stats.setdefault(r["pokemon_id"], {})[stat_keys[r["stat_id"]]] = int(r["base_stat"])
    dirs = set((DATA / "pokeemerald_dirs.txt").read_text().split())

    by_identifier = {r["identifier"]: r for r in species_rows.values()}
    basics = [r["identifier"] for r in species_rows.values()
              if not r["evolves_from_species_id"] and r["is_legendary"] == "0" and r["is_mythical"] == "0" and int(r["id"]) <= 1025
              and r["identifier"] not in SPECIAL_NOT_STARTER]
    wanted = list(dict.fromkeys(list(ROSTER) + basics))

    out_dir = ROOT / "creatures" / "data" / "species"
    out_dir.mkdir(parents=True, exist_ok=True)
    # Borra especies generadas antes que ya no están en la lista (p. ej. tras excluir especiales).
    keep = set(wanted)
    for old in out_dir.glob("*.tres"):
        if old.stem not in keep:
            old.unlink()
            old.with_suffix(".tres.uid").unlink(missing_ok=True)
    for old in (ROOT / "art" / "pokemon").glob("*"):
        if old.is_dir() and old.name not in keep:
            shutil.rmtree(old)
    for count, identifier in enumerate(wanted, 1):
        row = by_identifier[identifier]
        sid = row["id"]
        sheet, foot = overworld_sheet(pokeemerald_name(identifier, dirs))
        art = ROOT / "art" / "pokemon" / identifier
        art.mkdir(parents=True, exist_ok=True)
        sheet.save(art / "overworld.png")
        sp = {"id": int(sid), "identifier": identifier, "name": names.get(sid, identifier.title()), "types": types[sid], **stats[sid], "foot": foot}
        sp["temperament"], sp["rarity"] = ROSTER.get(identifier, (default_temperament(stats[sid]), COMMON))
        (out_dir / f"{identifier}.tres").write_text(tres_species(sp), encoding="utf-8")
        if count % 50 == 0:
            print(f"{count}/{len(wanted)}")

    (ROOT / "creatures" / "data" / "basic_pool.tres").write_text(
        tres_list("SpeciesPool", "res://creatures/data/species_pool.gd", "species", basics), encoding="utf-8")
    weights = ", ".join(str(w) for _, w in PRADERA)
    (ROOT / "world" / "biomes" / "pradera_encounters.tres").write_text(
        tres_list("EncounterTable", "res://creatures/data/encounter_table.gd", "species", [n for n, _ in PRADERA],
                  f"weights = PackedFloat32Array({weights})\nmax_alive = 12"), encoding="utf-8")
    print(f"{len(wanted)} especies ({len(basics)} básicos en el grupo de iniciales)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
