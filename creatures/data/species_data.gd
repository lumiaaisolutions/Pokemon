class_name SpeciesData
extends Resource
## Datos de una especie. Generado por tools/build_species.py desde PokeAPI; los
## campos de diseño (temperamento, rareza) se ajustan en el roster de ese script.

enum Temperament { WANDER, CURIOUS, SHY, AGGRESSIVE }
enum Rarity { COMMON, RARE }

@export var dex_id: int = 0
## Identificador en inglés de PokeAPI (p. ej. "mr-mime").
@export var identifier: String = ""
@export var display_name: String = ""
@export var types: Array[PokemonTypes.Type] = []

@export_group("Stats base")
@export var hp: int = 50
@export var attack: int = 50
@export var defense: int = 50
@export var sp_attack: int = 50
@export var sp_defense: int = 50
@export var speed: int = 50

@export_group("Mundo")
@export var temperament: Temperament = Temperament.WANDER
@export var rarity: Rarity = Rarity.COMMON
## Hoja overworld: 2 columnas (pasos) × 4 filas (abajo, izquierda, derecha, arriba), celdas de 32 px.
@export var overworld_sheet: Texture2D
## Filas transparentes bajo los pies en la hoja; se descuentan al apoyar el sprite en el suelo.
@export var foot_offset_px: int = 0
