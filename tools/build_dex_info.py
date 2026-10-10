#!/usr/bin/env python3
"""Datos de la Pokédex para las 1,025 especies.

- creatures/data/dex_info.json: categoría (genus) y descripción en español, altura (m)
  y peso (kg), desde los CSV de PokeAPI (la descripción se descarga y se guarda en
  sprites/data/ como caché).
- art/pokemon/<especie>/front.png y front_shiny.png: sprites de frente Gen 5 del dump
  de Showdown (para el menú y la Pokédex).
- art/cries/<número>.ogg: gritos oficiales del repositorio PokeAPI/cries (con caché).

Uso: python3 tools/build_dex_info.py [--sin-gritos]
"""
import csv
import json
import re
import shutil
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "sprites" / "data"
SPANISH = "7"
FLAVOR_URL = "https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/pokemon_species_flavor_text.csv"
CRY_URL = "https://raw.githubusercontent.com/PokeAPI/cries/main/cries/pokemon/latest/{}.ogg"
FORM_SUFFIX = re.compile(r"-(male|female|normal|incarnate|ordinary|altered|land|red-striped|aria|average|disguised|50|baile|midday|solo|shield|amped|full-belly|single-strike|zero|curly|family-of-four|green-plumage|two-segment|teal-mask|plant|standard)$")


def fetch(url: str, dest: Path) -> bool:
    if dest.exists() and dest.stat().st_size > 0:
        return True
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            dest.write_bytes(response.read())
        return True
    except Exception as error:  # noqa: BLE001 - se informa y se sigue
        print("no se pudo descargar", url, error)
        return False


def load(name: str) -> list[dict]:
    with open(DATA / name, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def showdown_file(folder: str, identifier: str) -> Path | None:
    base = FORM_SUFFIX.sub("", identifier)
    for candidate in (identifier, identifier.replace("-", ""), base, base.replace("-", "")):
        path = ROOT / "sprites" / folder / f"{candidate}.png"
        if path.exists():
            return path
    return None


def main() -> int:
    fetch(FLAVOR_URL, DATA / "pokemon_species_flavor_text.csv")
    species = {r["id"]: r for r in load("pokemon_species.csv") if int(r["id"]) <= 1025}
    names = {r["pokemon_species_id"]: r for r in load("pokemon_species_names.csv") if r["local_language_id"] == SPANISH}
    default_form = {r["species_id"]: r for r in load("pokemon.csv") if r["is_default"] == "1"}
    flavor: dict[str, str] = {}
    for r in load("pokemon_species_flavor_text.csv"):
        if r["language_id"] == SPANISH:
            # La versión más reciente gana.
            flavor[r["species_id"]] = " ".join(r["flavor_text"].split())
    info = {}
    copied = 0
    for sid, row in species.items():
        ident = row["identifier"]
        form = default_form.get(sid, {})
        info[ident] = {
            "genus": names.get(sid, {}).get("genus", ""),
            "flavor": flavor.get(sid, ""),
            "height_m": int(form.get("height", 0) or 0) / 10.0,
            "weight_kg": int(form.get("weight", 0) or 0) / 10.0,
            # Octavos de probabilidad de ser hembra; -1 = sin sexo.
            "gender_rate": int(row.get("gender_rate", -1)),
        }
        # Sprites de frente (la carpeta del arte usa el identificador de la especie).
        out = ROOT / "art" / "pokemon" / ident
        out.mkdir(parents=True, exist_ok=True)
        for folder, name in (("gen5", "front.png"), ("gen5-shiny", "front_shiny.png")):
            src = showdown_file(folder, ident)
            if src is not None:
                shutil.copyfile(src, out / name)
                copied += 1
    (ROOT / "creatures" / "data" / "dex_info.json").write_text(json.dumps(info, ensure_ascii=False, indent=0), encoding="utf-8")
    print(f"{len(info)} especies; {copied} sprites de frente copiados")
    if "--sin-gritos" not in sys.argv:
        cries = ROOT / "art" / "cries"
        cries.mkdir(parents=True, exist_ok=True)
        ok = sum(fetch(CRY_URL.format(int(sid)), cries / f"{int(sid)}.ogg") for sid in species)
        print(f"{ok} gritos listos")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
