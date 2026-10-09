class_name SpeciesData
extends Resource
## Datos de una especie. Generado por tools/build_species.py desde PokeAPI; los
## campos de diseño (temperamento) se ajustan en el roster de ese script.

## TERRITORIAL: solo persigue dentro de su zona; AGGRESSIVE: persigue en cuanto te ve.
enum Temperament { WANDER, CURIOUS, SHY, AGGRESSIVE, TERRITORIAL }
## Zonas donde puede aparecer (según sus tipos; ver tools/build_species.py).
enum Habitat { MEADOW, FOREST, MOUNTAIN, FRESHWATER, SEA, SWAMP }

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

@export_group("Aparición")
## 1 = básico, 2 = segunda etapa, 3 = tercera etapa (los bebés no cuentan como etapa).
@export var evolution_stage: int = 1
## Suma de las 6 estadísticas base.
@export var base_total: int = 300
@export var height_m: float = 1.0
## Escalón de tamaño en el mundo por su altura: 1, 1.5, 2 o 3.
@export var size_scale: float = 1.0
@export var habitats: Array[Habitat] = []
## Peso relativo de aparición (etapa × poder). 0 = no aparece en hierba (legendarios).
@export var spawn_weight: float = 1.0
## Nada en el agua (tipo Agua con forma de pez o tentáculos); si no, aparece en la orilla.
@export var swims: bool = false
@export var is_legendary: bool = false
@export var is_mythical: bool = false

@export_group("Mundo")
@export var temperament: Temperament = Temperament.WANDER
## Hoja overworld: 2 columnas (pasos) × 4 filas (abajo, izquierda, derecha, arriba), celdas de 32 px.
@export var overworld_sheet: Texture2D
## La misma hoja con la paleta variocolor.
@export var overworld_sheet_shiny: Texture2D
## Filas transparentes bajo los pies en la hoja; se descuentan al apoyar el sprite en el suelo.
@export var foot_offset_px: int = 0
