class_name MegaData
extends Resource
## Una megaevolución: forma, tipos y estadísticas de la mega, la megapiedra que
## necesita y sus sprites de combate (Gen 5, frente y espalda, normal y shiny).
## La genera tools/build_megas.py desde PokeAPI y el dump de Showdown.

## Identificador de PokeAPI (p. ej. "greninja-mega", "charizard-mega-x").
@export var identifier: String = ""
## Especie base (identificador de SpeciesData, p. ej. "greninja").
@export var base_species: String = ""
@export var display_name: String = ""
## Megapiedra necesaria (p. ej. "Greninjita"). Rayquaza no usa piedra (Ascenso del Dragón).
@export var stone: String = ""
@export var types: Array[int] = []
@export var hp: int = 0
@export var attack: int = 0
@export var defense: int = 0
@export var sp_attack: int = 0
@export var sp_defense: int = 0
@export var speed: int = 0
## Sprites de combate (null si el dump no los trae todavía).
@export var front: Texture2D
@export var back: Texture2D
@export var front_shiny: Texture2D
@export var back_shiny: Texture2D


func base_total() -> int:
	return hp + attack + defense + sp_attack + sp_defense + speed


func has_battle_sprites() -> bool:
	return front != null and back != null
