class_name MegaCatalog
extends Resource
## Todas las megaevoluciones (ver MegaData). Se carga desde
## res://creatures/data/all_megas.tres.

const PATH := "res://creatures/data/all_megas.tres"

@export var megas: Array[MegaData] = []


## Megas de una especie (Charizard, Mewtwo y Raichu tienen X e Y; algunas tienen Z).
func for_species(identifier: String) -> Array[MegaData]:
	var result: Array[MegaData] = []
	for mega in megas:
		if mega.base_species == identifier:
			result.append(mega)
	return result


func find(identifier: String) -> MegaData:
	for mega in megas:
		if mega.identifier == identifier:
			return mega
	return null


static func load_catalog() -> MegaCatalog:
	return load(PATH) as MegaCatalog
