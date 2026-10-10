class_name DexData
extends RefCounted
## Datos de la Pokédex por especie (creatures/data/dex_info.json, ver
## tools/build_dex_info.py): categoría, descripción, altura y peso; y los gritos.

const PATH := "res://creatures/data/dex_info.json"

static var _info := {}
static var _all: Array[SpeciesData] = []


static func _ensure() -> void:
	if _info.is_empty():
		_info = JSON.parse_string(FileAccess.get_file_as_string(PATH))


static func info(identifier: String) -> Dictionary:
	_ensure()
	return _info.get(identifier, {})


static func genus(identifier: String) -> String:
	return info(identifier).get("genus", "Pokémon")


static func flavor(identifier: String) -> String:
	return info(identifier).get("flavor", "")


static func height(identifier: String) -> float:
	return float(info(identifier).get("height_m", 0.0))


static func weight(identifier: String) -> float:
	return float(info(identifier).get("weight_kg", 0.0))


## Grito oficial (ogg) de la especie, o null.
static func cry(species: SpeciesData) -> AudioStream:
	var path := "res://art/cries/%d.ogg" % species.dex_id
	return load(path) as AudioStream if ResourceLoader.exists(path) else null


## Las 1,025 especies en orden de la Pokédex nacional.
static func all_species() -> Array[SpeciesData]:
	if _all.is_empty():
		var list := load("res://creatures/data/all_species.tres")
		for species: SpeciesData in list.get("species"):
			_all.append(species)
		_all.sort_custom(func(a: SpeciesData, b: SpeciesData) -> bool: return a.dex_id < b.dex_id)
	return _all
