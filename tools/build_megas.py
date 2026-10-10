#!/usr/bin/env python3
"""Genera el catálogo de megaevoluciones (creatures/data/megas/*.tres y all_megas.tres).

Fuentes:
- PokeAPI (sprites/data/*.csv): formas "-mega", tipos y estadísticas (incluye las de
  Leyendas Z-A y su DLC, como Mega Greninja).
- Dump de Showdown (sprites/gen5*, Gen 5 estático): sprites de combate de frente y
  espalda, normal y shiny. Se copian a art/pokemon/<especie>/<forma>/.

Las megapiedras se nombran "<Nombre>ita" (sin la vocal final; + X/Y/Z) salvo las
excepciones de STONES (nombres provisionales hasta verificarlos uno por uno);
Rayquaza no usa piedra. Uso: python3 tools/build_megas.py && godot --headless --path . --import
"""
import csv
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "sprites" / "data"
SPANISH = "7"
# Nombres de megapiedra conocidos que no siguen la regla "<Nombre>ita".
STONES = {
    "rayquaza-mega": "",
    "mewtwo-mega-x": "Mewtwoita X",
    "mewtwo-mega-y": "Mewtwoita Y",
    "blastoise-mega": "Blastoisinita",
    "alakazam-mega": "Alakazamita",
    "heracross-mega": "Heracronita",
    "houndoom-mega": "Houndoominita",
    "lucario-mega": "Lucarita",
    "abomasnow-mega": "Abomasnowita",
    "sableye-mega": "Sablenita",
    "altaria-mega": "Altarianita",
    "sharpedo-mega": "Sharpedonita",
    "slowbro-mega": "Slowbronita",
    "glalie-mega": "Glalita",
    "diancie-mega": "Diancita",
}


def load(name: str) -> list[dict]:
    with open(DATA / name, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def showdown_name(identifier: str) -> str:
    """charizard-mega-x -> charizard-megax; meowstic-male-mega se queda igual."""
    base, _, rest = identifier.partition("-mega")
    return base + "-mega" + rest.replace("-", "")


def suffix(identifier: str) -> str:
    rest = identifier.partition("-mega")[2]
    return rest.strip("-").upper()


def main() -> int:
    pokemon = load("pokemon.csv")
    species_id = {r["identifier"]: r["species_id"] for r in pokemon}
    # La especie (no la forma por defecto: "meowstic", no "meowstic-male").
    base_identifier = {r["id"]: r["identifier"] for r in load("pokemon_species.csv")}
    names = {r["pokemon_species_id"]: r["name"] for r in load("pokemon_species_names.csv") if r["local_language_id"] == SPANISH}
    form_ids = {r["identifier"]: r["id"] for r in pokemon}
    types: dict[str, list[int]] = {}
    for r in sorted(load("pokemon_types.csv"), key=lambda r: int(r["slot"])):
        types.setdefault(r["pokemon_id"], []).append(int(r["type_id"]) - 1)
    stat_keys = {"1": "hp", "2": "attack", "3": "defense", "4": "sp_attack", "5": "sp_defense", "6": "speed"}
    stats: dict[str, dict] = {}
    for r in load("pokemon_stats.csv"):
        stats.setdefault(r["pokemon_id"], {})[stat_keys[r["stat_id"]]] = int(r["base_stat"])

    out_dir = ROOT / "creatures" / "data" / "megas"
    out_dir.mkdir(parents=True, exist_ok=True)
    megas = [r["identifier"] for r in pokemon if "-mega" in r["identifier"]]
    written: list[str] = []
    without_sprites: list[str] = []
    for ident in megas:
        sid = species_id[ident]
        base = base_identifier[sid]
        if not (ROOT / "creatures" / "data" / "species" / f"{base}.tres").exists():
            continue
        species_name = names.get(sid, base.capitalize())
        tag = suffix(ident)
        variant = ""
        for word in ("male", "female", "curly", "droopy", "stretchy", "original"):
            if f"-{word}" in ident:
                variant = word
        letter = tag.split("-")[-1] if tag and tag.split("-")[-1] in ("X", "Y", "Z") else ""
        display = f"Mega {species_name}" + (f" {letter}" if letter else "")
        stem = species_name[:-1] if species_name[-1].lower() in "aeiouy" else species_name
        stone = STONES.get(ident, f"{stem}ita" + (f" {letter}" if letter else ""))
        form_dir = "mega" + (f"_{letter.lower()}" if letter else "") + (f"_{variant}" if variant else "")
        sd = showdown_name(ident)
        art = ROOT / "art" / "pokemon" / base / form_dir
        sprites = {}
        for key, folder in (("front", "gen5"), ("back", "gen5-back"), ("front_shiny", "gen5-shiny"), ("back_shiny", "gen5-back-shiny")):
            src = ROOT / "sprites" / folder / f"{sd}.png"
            if src.exists():
                art.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(src, art / f"{key}.png")
                sprites[key] = f"res://art/pokemon/{base}/{form_dir}/{key}.png"
        if "front" not in sprites:
            without_sprites.append(ident)
        fid = form_ids[ident]
        st = stats[fid]
        ext = ['[ext_resource type="Script" path="res://creatures/data/mega_data.gd" id="1_script"]']
        fields = []
        for i, (key, path) in enumerate(sprites.items()):
            ext.append(f'[ext_resource type="Texture2D" path="{path}" id="{i + 2}_{key}"]')
            fields.append(f'{key} = ExtResource("{i + 2}_{key}")')
        type_list = ", ".join(str(t) for t in types[fid])
        text = "\n".join([
            '[gd_resource type="Resource" script_class="MegaData" format=3]', "", *ext, "", "[resource]",
            'script = ExtResource("1_script")',
            f'identifier = "{ident}"', f'base_species = "{base}"', f'display_name = "{display}"', f'stone = "{stone}"',
            f"types = Array[int]([{type_list}])",
            *(f"{k} = {st[k]}" for k in ("hp", "attack", "defense", "sp_attack", "sp_defense", "speed")),
            *fields,
        ]) + "\n"
        (out_dir / f"{ident}.tres").write_text(text, encoding="utf-8")
        written.append(ident)

    lines = ['[gd_resource type="Resource" script_class="MegaCatalog" format=3]', "",
             '[ext_resource type="Script" path="res://creatures/data/mega_catalog.gd" id="1_script"]',
             '[ext_resource type="Script" path="res://creatures/data/mega_data.gd" id="1_mega"]']
    for i, ident in enumerate(written):
        lines.append(f'[ext_resource type="Resource" path="res://creatures/data/megas/{ident}.tres" id="{i + 2}_m"]')
    refs = ", ".join(f'ExtResource("{i + 2}_m")' for i in range(len(written)))
    lines += ["", "[resource]", 'script = ExtResource("1_script")', f'megas = Array[ExtResource("1_mega")]([{refs}])']
    (ROOT / "creatures" / "data" / "all_megas.tres").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(written)} megas; sin sprites de combate Gen 5: {len(without_sprites)}")
    for ident in without_sprites:
        print("  sin sprites:", ident)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
