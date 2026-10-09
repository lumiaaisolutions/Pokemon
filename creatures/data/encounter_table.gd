class_name EncounterTable
extends Resource
## Qué especies aparecen en la hierba alta de un bioma y con qué peso relativo.

@export var species: Array[SpeciesData] = []
## Peso de cada especie (mismo índice que species).
@export var weights: PackedFloat32Array = PackedFloat32Array()
## Máximo de Pokémon salvajes vivos a la vez en el bioma.
@export var max_alive: int = 10


func pick(rng: RandomNumberGenerator) -> SpeciesData:
	var total := 0.0
	for w in weights:
		total += w
	var roll := rng.randf() * total
	for i in species.size():
		roll -= weights[i]
		if roll <= 0.0:
			return species[i]
	return species[species.size() - 1]
