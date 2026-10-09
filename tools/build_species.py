#!/usr/bin/env python3
"""Genera los datos de especies (.tres) y sus hojas overworld (normal y shiny).

Fuentes:
- sprites/data/*.csv: CSV de PokeAPI (especies, tipos, stats, alturas, nombres en español).
- Hojas overworld y paleta shiny de pokeemerald-expansion (GitHub, rh-hideout),
  cacheadas en sprites/overworld/pokemon/.

Salida:
- art/pokemon/<identifier>/overworld.png y overworld_shiny.png: 2 columnas (pasos)
  × 4 filas (abajo, izquierda, derecha, arriba), celdas de 32 px, fondo transparente.
- creatures/data/species/<identifier>.tres (SpeciesData), las 1,025 especies.
- creatures/data/basic_pool.tres: básicos para elegir inicial (sin legendarios,
  singulares, Ultraentes ni paradojas).
- creatures/data/all_species.tres: todas las especies (para el spawner por hábitat).

Uso: python3 tools/build_species.py
"""
import csv
import shutil
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "sprites" / "data"
CACHE = ROOT / "sprites" / "overworld" / "pokemon"
BASE_URL = "https://raw.githubusercontent.com/rh-hideout/pokeemerald-expansion/master/graphics/pokemon/{}/{}"
SPANISH = "7"  # local_language_id de español en PokeAPI
CELL = 32
MAX_DEX = 1025

# Temperamentos (SpeciesData.Temperament).
WANDER, CURIOUS, SHY, AGGRESSIVE, TERRITORIAL = range(5)
# Hábitats (SpeciesData.Habitat).
MEADOW, FOREST, MOUNTAIN, FRESHWATER, SEA, SWAMP = range(6)
# Tipos (PokemonTypes.Type = id de PokeAPI - 1).
(NORMAL, FIGHTING, FLYING, POISON, GROUND, ROCK, BUG, GHOST, STEEL, FIRE, WATER, GRASS,
 ELECTRIC, PSYCHIC, ICE, DRAGON, DARK, FAIRY) = range(18)

# Dónde aparece cada tipo. Los de tipo Agua solo aparecen en zonas con agua.
TYPE_HABITATS = {
    NORMAL: {MEADOW, FOREST}, FIGHTING: {MOUNTAIN, MEADOW}, FLYING: {MEADOW, FOREST, MOUNTAIN},
    POISON: {SWAMP, FOREST}, GROUND: {MOUNTAIN, MEADOW}, ROCK: {MOUNTAIN}, BUG: {FOREST, MEADOW},
    GHOST: {FOREST, SWAMP, MOUNTAIN}, STEEL: {MOUNTAIN}, FIRE: {MOUNTAIN, MEADOW},
    WATER: {FRESHWATER, SEA, SWAMP}, GRASS: {MEADOW, FOREST, SWAMP}, ELECTRIC: {MEADOW, MOUNTAIN},
    PSYCHIC: {FOREST, MEADOW}, ICE: {MOUNTAIN, SEA}, DRAGON: {MOUNTAIN}, DARK: {FOREST, MOUNTAIN},
    FAIRY: {MEADOW, FOREST},
}
WATER_HABITATS = {FRESHWATER, SEA, SWAMP}
# habitat_id de PokeAPI (solo Gen 1–3): 7 = mar, 9 = orilla de agua dulce.
POKEAPI_SEA, POKEAPI_WATERS_EDGE = "7", "9"

# Rareza: peso = etapa × poder (decisión de Fernando, 2026-10-09).
STAGE_FACTOR = {1: 1.0, 2: 0.35, 3: 0.1}

# Roster aprobado: temperamento de diseño.
ROSTER = {
    "venusaur": WANDER, "charizard": AGGRESSIVE, "blastoise": TERRITORIAL,
    "pidgeot": SHY, "ampharos": CURIOUS, "sawsbuck": SHY, "absol": AGGRESSIVE,
    "heracross": TERRITORIAL, "swampert": WANDER, "leavanny": CURIOUS, "gardevoir": SHY,
    "aggron": TERRITORIAL, "aerodactyl": AGGRESSIVE, "excadrill": WANDER, "froslass": SHY,
    "garchomp": AGGRESSIVE,
}

# Roster como destacados de su bioma: siempre aparecen ahí y con peso ×20.
ROSTER_HABITAT = {
    "pidgeot": MEADOW, "ampharos": MEADOW, "sawsbuck": MEADOW, "absol": MEADOW,
    "heracross": FOREST, "swampert": SWAMP, "leavanny": FOREST, "gardevoir": FOREST,
    "aggron": MOUNTAIN, "aerodactyl": MOUNTAIN, "excadrill": MOUNTAIN, "froslass": MOUNTAIN,
    "garchomp": MOUNTAIN, "venusaur": MEADOW, "charizard": MOUNTAIN, "blastoise": FRESHWATER,
}
ROSTER_WEIGHT_BOOST = 20.0
# Los raros del roster conservan su bioma pero no reciben el refuerzo.
ROSTER_RARE = {"absol", "gardevoir", "froslass", "garchomp"}

# Especiales que PokeAPI no marca como legendarios pero no tienen sentido como inicial
# ni como aparición común: Ultraentes (Gen 7) y Pokémon paradoja (Gen 9).
SPECIAL = {
    "nihilego", "buzzwole", "pheromosa", "xurkitree", "celesteela", "kartana", "guzzlord", "poipole", "naganadel",
    "stakataka", "blacephalon",
    "great-tusk", "scream-tail", "brute-bonnet", "flutter-mane", "slither-wing", "sandy-shocks", "iron-treads",
    "iron-bundle", "iron-hands", "iron-jugulis", "iron-moth", "iron-thorns", "roaring-moon", "iron-valiant",
    "walking-wake", "iron-leaves", "gouging-fire", "raging-bolt", "iron-boulder", "iron-crown",
}


def load_csv(name: str) -> list[dict]:
    with open(DATA / name, encoding="utf-8") as f:
        return list(csv.DictReader(f))


# Especies cuya hoja overworld está en la subcarpeta de su forma predeterminada.
FORM_FOLDERS = {"alcremie": "alcremie/strawberry"}


def pokeemerald_name(identifier: str, dirs: set[str]) -> str:
    if identifier in FORM_FOLDERS:
        return FORM_FOLDERS[identifier]
    for candidate in (identifier.replace("-", "_"), identifier.replace("-", "")):
        if candidate in dirs:
            return candidate
    raise KeyError(identifier)


def fetch(source: str, filename: str) -> Path | None:
    """Descarga (con caché) un archivo de la carpeta de la especie en pokeemerald."""
    cached = CACHE / source / filename
    if cached.exists():
        return cached
    cached.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(5):
        try:
            urllib.request.urlretrieve(BASE_URL.format(source, filename), cached)
            return cached
        except urllib.error.HTTPError:
            return None  # El archivo no existe (p. ej. sin paleta shiny).
        except urllib.error.URLError:
            time.sleep(1.5 * (attempt + 1))  # Fallo de red pasajero: reintenta.
    raise RuntimeError(f"No se pudo descargar {source}/{filename}")


def read_jasc_pal(path: Path) -> list[int]:
    lines = path.read_text().split()
    count = int(lines[2])
    values = [int(v) for v in lines[3:3 + count * 3]]
    return values + [0] * (768 - len(values))


def overworld_sheets(source: str) -> tuple[Image.Image, Image.Image | None, int]:
    """Convierte la hoja de pokeemerald (6 frames: abajo×2, arriba×2, lado izquierdo×2)
    a 2 columnas × 4 filas (abajo, izquierda, derecha, arriba) con fondo transparente,
    en versión normal y shiny (si existe la paleta)."""
    raw = Image.open(fetch(source, "overworld.png"))
    shiny_pal = fetch(source, "overworld_shiny.pal")
    variants = [raw.copy()]
    if raw.mode == "P" and shiny_pal is not None:
        shiny = raw.copy()
        shiny.putpalette(read_jasc_pal(shiny_pal))
        variants.append(shiny)
    sheets = []
    foot = CELL
    for variant in variants:
        if variant.mode == "P":
            # El índice 0 de la paleta es el fondo en las hojas de GBA.
            variant.info["transparency"] = 0
        image = variant.convert("RGBA")
        frames = [image.crop((i * CELL, 0, (i + 1) * CELL, CELL)) for i in range(image.width // CELL)]
        while len(frames) < 6:
            frames.append(frames[-1])
        down, up, left = frames[0:2], frames[2:4], frames[4:6]
        right = [f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in left]
        sheet = Image.new("RGBA", (CELL * 2, CELL * 4), (0, 0, 0, 0))
        for row, pair in enumerate((down, left, right, up)):
            for col, frame in enumerate(pair):
                sheet.paste(frame, (col * CELL, row * CELL))
        # Filas vacías bajo los pies: el mínimo entre todos los frames (el que más baja).
        for frame in frames:
            bbox = frame.getchannel("A").getbbox()
            if bbox:
                foot = min(foot, CELL - bbox[3])
        sheets.append(sheet)
    return sheets[0], sheets[1] if len(sheets) > 1 else None, foot


def default_temperament(stats: dict) -> int:
    """Temperamento por stats para especies fuera del roster."""
    if stats["attack"] >= 100 or (stats["attack"] > stats["defense"] + 25 and stats["attack"] >= 80):
        return AGGRESSIVE
    if stats["defense"] >= 90 or stats["attack"] >= 85:
        return TERRITORIAL
    if stats["speed"] >= 80 and stats["hp"] < 60:
        return SHY
    if stats["sp_attack"] > stats["attack"]:
        return CURIOUS
    return WANDER


def size_scale(height_m: float) -> float:
    """Escalones de píxel por altura oficial (decisión de Fernando)."""
    if height_m <= 0.7:
        return 1.0
    if height_m <= 1.5:
        return 1.5
    if height_m <= 3.0:
        return 2.0
    return 3.0


def habitats_for(types: list[int], pokeapi_habitat: str) -> list[int]:
    if WATER in types:
        result = set(WATER_HABITATS)
        if pokeapi_habitat == POKEAPI_SEA:
            result = {SEA}
        elif pokeapi_habitat == POKEAPI_WATERS_EDGE:
            result = {FRESHWATER, SWAMP}
        return sorted(result)
    result: set[int] = set()
    for t in types:
        result |= TYPE_HABITATS[t]
    return sorted(result)


def spawn_weight(stage: int, base_total: int, special: bool) -> float:
    if special:
        return 0.0
    power = min(max((350.0 / base_total) ** 2, 0.05), 1.5)
    if base_total > 500:
        power *= 0.3
    return round(STAGE_FACTOR[stage] * power, 4)


def tres_species(sp: dict) -> str:
    types = ", ".join(str(t) for t in sp["types"])
    habitats = ", ".join(str(h) for h in sp["habitats"])
    shiny_ext = ""
    shiny_field = ""
    if sp["shiny"]:
        shiny_ext = f'\n[ext_resource type="Texture2D" path="res://art/pokemon/{sp["identifier"]}/overworld_shiny.png" id="3_shiny"]'
        shiny_field = '\noverworld_sheet_shiny = ExtResource("3_shiny")'
    name = sp["name"].replace('"', '\\"')
    return f"""[gd_resource type="Resource" script_class="SpeciesData" format=3]

[ext_resource type="Script" path="res://creatures/data/species_data.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://art/pokemon/{sp['identifier']}/overworld.png" id="2_ow"]{shiny_ext}

[resource]
script = ExtResource("1_script")
dex_id = {sp['id']}
identifier = "{sp['identifier']}"
display_name = "{name}"
types = Array[int]([{types}])
hp = {sp['hp']}
attack = {sp['attack']}
defense = {sp['defense']}
sp_attack = {sp['sp_attack']}
sp_defense = {sp['sp_defense']}
speed = {sp['speed']}
evolution_stage = {sp['stage']}
base_total = {sp['base_total']}
height_m = {sp['height']}
size_scale = {sp['size']}
habitats = Array[int]([{habitats}])
spawn_weight = {sp['weight']}
is_legendary = {str(sp['legendary']).lower()}
is_mythical = {str(sp['mythical']).lower()}
temperament = {sp['temperament']}
overworld_sheet = ExtResource("2_ow"){shiny_field}
foot_offset_px = {sp['foot']}
"""


def tres_list(script_class: str, script_path: str, identifiers: list[str]) -> str:
    """Recurso con un arreglo tipado Array[SpeciesData] llamado species."""
    lines = [f'[gd_resource type="Resource" script_class="{script_class}" format=3]', "",
             f'[ext_resource type="Script" path="{script_path}" id="1_script"]',
             '[ext_resource type="Script" path="res://creatures/data/species_data.gd" id="1_species"]']
    for i, ident in enumerate(identifiers):
        lines.append(f'[ext_resource type="Resource" path="res://creatures/data/species/{ident}.tres" id="{i + 2}_sp"]')
    refs = ", ".join(f'ExtResource("{i + 2}_sp")' for i in range(len(identifiers)))
    lines += ["", "[resource]", 'script = ExtResource("1_script")', f'species = Array[ExtResource("1_species")]([{refs}])']
    return "\n".join(lines) + "\n"


def main() -> int:
    species_rows = {r["id"]: r for r in load_csv("pokemon_species.csv") if int(r["id"]) <= MAX_DEX}
    names = {r["pokemon_species_id"]: r["name"] for r in load_csv("pokemon_species_names.csv") if r["local_language_id"] == SPANISH}
    heights = {r["species_id"]: int(r["height"]) / 10.0 for r in load_csv("pokemon.csv") if r["is_default"] == "1"}
    types: dict[str, list[int]] = {}
    for r in sorted(load_csv("pokemon_types.csv"), key=lambda r: int(r["slot"])):
        types.setdefault(r["pokemon_id"], []).append(int(r["type_id"]) - 1)
    stat_keys = {"1": "hp", "2": "attack", "3": "defense", "4": "sp_attack", "5": "sp_defense", "6": "speed"}
    stats: dict[str, dict] = {}
    for r in load_csv("pokemon_stats.csv"):
        if r["stat_id"] in stat_keys:
            stats.setdefault(r["pokemon_id"], {})[stat_keys[r["stat_id"]]] = int(r["base_stat"])
    dirs = set((DATA / "pokeemerald_dirs.txt").read_text().split())

    def stage_of(sid: str) -> int:
        """Etapa evolutiva; un bebé previo (Pichu) no cuenta como etapa."""
        stage = 1
        row = species_rows[sid]
        while row["evolves_from_species_id"]:
            parent = species_rows[row["evolves_from_species_id"]]
            if parent["is_baby"] != "1":
                stage += 1
            row = parent
        return min(stage, 3)

    def build(sid: str) -> dict:
        row = species_rows[sid]
        identifier = row["identifier"]
        source = pokeemerald_name(identifier, dirs)
        sheet, shiny, foot = overworld_sheets(source)
        art = ROOT / "art" / "pokemon" / identifier
        art.mkdir(parents=True, exist_ok=True)
        sheet.save(art / "overworld.png")
        if shiny is not None:
            shiny.save(art / "overworld_shiny.png")
        legendary = row["is_legendary"] == "1"
        mythical = row["is_mythical"] == "1"
        st = stats[sid]
        base_total = sum(st.values())
        stage = stage_of(sid)
        temperament = ROSTER.get(identifier, default_temperament(st))
        if legendary or mythical:
            temperament = TERRITORIAL
        return {
            "id": int(sid), "identifier": identifier, "name": names.get(sid, identifier.title()),
            "types": types[sid], **st, "foot": foot, "shiny": shiny is not None,
            "stage": stage, "base_total": base_total, "height": heights[sid], "size": size_scale(heights[sid]),
            "habitats": sorted(set(habitats_for(types[sid], row["habitat_id"])) | ({ROSTER_HABITAT[identifier]} if identifier in ROSTER_HABITAT else set())),
            "weight": round(spawn_weight(stage, base_total, legendary or mythical or identifier in SPECIAL)
                            * (ROSTER_WEIGHT_BOOST if identifier in ROSTER_HABITAT and identifier not in ROSTER_RARE else 1.0), 4),
            "legendary": legendary, "mythical": mythical, "temperament": temperament,
        }

    ids = sorted(species_rows, key=int)
    with ThreadPoolExecutor(max_workers=6) as pool:
        built = list(pool.map(build, ids))

    out_dir = ROOT / "creatures" / "data" / "species"
    out_dir.mkdir(parents=True, exist_ok=True)
    keep = {sp["identifier"] for sp in built}
    for old in out_dir.glob("*.tres"):
        if old.stem not in keep:
            old.unlink()
            old.with_suffix(".tres.uid").unlink(missing_ok=True)
    for old in (ROOT / "art" / "pokemon").glob("*"):
        if old.is_dir() and old.name not in keep:
            shutil.rmtree(old)
    for sp in built:
        (out_dir / f"{sp['identifier']}.tres").write_text(tres_species(sp), encoding="utf-8")

    basics = [sp["identifier"] for sp in built
              if not species_rows[str(sp["id"])]["evolves_from_species_id"]
              and not sp["legendary"] and not sp["mythical"] and sp["identifier"] not in SPECIAL]
    (ROOT / "creatures" / "data" / "basic_pool.tres").write_text(
        tres_list("SpeciesPool", "res://creatures/data/species_pool.gd", basics), encoding="utf-8")
    (ROOT / "creatures" / "data" / "all_species.tres").write_text(
        tres_list("SpeciesPool", "res://creatures/data/species_pool.gd", [sp["identifier"] for sp in built]), encoding="utf-8")
    shiny_count = sum(sp["shiny"] for sp in built)
    print(f"{len(built)} especies, {len(basics)} básicos para inicial, {shiny_count} con hoja shiny, "
          f"{sum(sp['legendary'] or sp['mythical'] for sp in built)} legendarios/singulares")
    return 0


if __name__ == "__main__":
    sys.exit(main())
