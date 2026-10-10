class_name PlayerCharacters
extends RefCounted
## Personajes jugables: 5 chicos y 5 chicas (protagonistas de cada generación).
## Todos usan una hoja con el formato de Nate (ver tools/protagonist_sheets.py), así
## que tienen la misma funcionalidad. Los que no traen animación de correr usan su
## caminar acelerado (run = false).

const LIST: Array[Dictionary] = [
	{"id": "red", "name": "Red", "gender": "male", "region": "Kanto", "run": false},
	{"id": "ethan", "name": "Ethan", "gender": "male", "region": "Johto", "run": true},
	{"id": "brendan", "name": "Brendan", "gender": "male", "region": "Hoenn", "run": true},
	{"id": "lucas", "name": "Lucas", "gender": "male", "region": "Sinnoh", "run": true},
	{"id": "calem", "name": "Calem", "gender": "male", "region": "Kalos", "run": false},
	{"id": "leaf", "name": "Leaf", "gender": "female", "region": "Kanto", "run": false},
	{"id": "lyra", "name": "Lyra", "gender": "female", "region": "Johto", "run": true},
	{"id": "may", "name": "May", "gender": "female", "region": "Hoenn", "run": false},
	{"id": "dawn", "name": "Dawn", "gender": "female", "region": "Sinnoh", "run": true},
	{"id": "serena", "name": "Serena", "gender": "female", "region": "Kalos", "run": false},
]
## Personaje de respaldo (partidas y pruebas sin selección).
const DEFAULT_ID := "nate"


static func by_gender(gender: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in LIST:
		if entry["gender"] == gender:
			result.append(entry)
	return result


static func find(id: String) -> Dictionary:
	for entry in LIST:
		if entry["id"] == id:
			return entry
	return {"id": DEFAULT_ID, "name": "Nate", "gender": "male", "region": "Teselia", "run": true}


## Hoja overworld (3 × 8 celdas de 32 px) del personaje.
static func sheet(id: String) -> Texture2D:
	var path := "res://art/trainers/%s_overworld.png" % id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return load("res://art/trainers/nate_overworld.png") as Texture2D
