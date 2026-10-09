class_name SpeciesPool
extends Resource
## Conjunto de especies del que se eligen al azar (p. ej. los iniciales básicos).

@export var species: Array[SpeciesData] = []


## Devuelve count especies distintas al azar.
func pick_distinct(rng: RandomNumberGenerator, count: int) -> Array[SpeciesData]:
	var indices := range(species.size())
	var picked: Array[SpeciesData] = []
	for i in mini(count, species.size()):
		var j := rng.randi_range(i, indices.size() - 1)
		var tmp: int = indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
		picked.append(species[indices[i]])
	return picked
