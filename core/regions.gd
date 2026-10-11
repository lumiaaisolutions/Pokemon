class_name Regions
extends RefCounted
## Viaje por regiones (diseño acordado con Fernando el 2026-10-10, ver
## docs/sistemas/regiones.md):
## - 6 regiones con nombre inventado, cada una con su semilla (el mundo se genera al llegar).
## - Cada región tiene 8 líderes (sin repetirse entre regiones), una Liga (4 del Alto Mando
##   y un héroe no elegido como Campeón), su profesor, su Pokédex regional (~250 especies:
##   hay que viajar para completarla) y sus legendarios (repartidos sin repetir).
## - Se completa con 8 medallas + Liga + 11 de los 21 puntos de Concursos, Investigación y
##   Academia; entonces el profesor da el Boleto a la siguiente.
## - Barco o avión al azar por región (muelle o aeropuerto en su pueblo inicial).
## - Lo de cada región (banderas, actividades, zonas, avance, profesor) se guarda aparte;
##   el equipo, la Pokédex, la mochila, el dinero y las licencias viajan contigo.

const COUNT := 6
const GYMS := 8
const ELITE_SIZE := 4
## Especies por Pokédex regional (aprox.; se completa por líneas evolutivas).
const DEX_TARGET := 250
## Misiones para completar la región: avance de estos caminos del Rotom (21 en total).
const MISSION_PATHS := ["concursos", "investigacion", "academia"]
const MISSIONS_NEEDED := 11
## Banderas que no son de la región (viajan contigo).
const GLOBAL_FLAGS := ["ride_license", "fly_license", "bike_given", "daycare", "rival_next_day", "rival_badges", "win_streak"]
const PREFIXES := ["Aure", "Valt", "Nimb", "Cald", "Ostr", "Lun", "Bris", "Ferr", "Cobr", "Esmer", "Solv", "Torm", "Mir", "Zafr",
		"Ard", "Elv", "Cristal", "Orb", "Sel", "Tamar", "Quel", "Ventr", "Rubí", "Ambar"]
const SUFFIXES := ["ia", "oria", "ara", "eria", "avia", "is", "alia", "ania", "ona", "ea", "ira", "elia"]

## Conjunto de líneas evolutivas permitidas en la región actual (caché).
static var _chains := {}
static var _chains_region := -1


## Crea las regiones de la partida si aún no existen (partidas nuevas y viejas).
static func ensure() -> void:
	if not GameState.regions.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("regiones:%d" % GameState.world_seed)
	if GameState.professor == "":
		GameState.professor = ActivityManager.PROFESSORS[rng.randi() % ActivityManager.PROFESSORS.size()]
	var leaders: Array = Leaders.GYM.keys()
	_shuffle(leaders, rng)
	var elite_use := {}
	var heroes := _hero_pool(rng)
	var professors: Array = ActivityManager.PROFESSORS.duplicate()
	professors.erase(GameState.professor)
	_shuffle(professors, rng)
	var chains := _chain_pool(rng)
	var legendaries := _legendary_pool(rng)
	var names := {}
	for i in COUNT:
		var name := _name(rng)
		while names.has(name):
			name = _name(rng)
		names[name] = true
		var region := {
			"name": name,
			"seed": GameState.world_seed if i == 0 else rng.randi_range(1, 2147483646),
			"transport": "boat" if rng.randf() < 0.5 else "plane",
			"leaders": leaders.slice(i * GYMS, (i + 1) * GYMS),
			"elite": _pick_elite(elite_use, rng),
			"champion": heroes[i % heroes.size()],
			"professor": GameState.professor if i == 0 else String(professors[(i - 1) % professors.size()]),
			"chains": _region_chains(chains, i, rng),
			"legendaries": legendaries[i],
			"unlocked": i == 0,
			"state": {},
		}
		GameState.regions.append(region)
	GameState.region_index = 0
	_chains_region = -1


static func current() -> Dictionary:
	ensure()
	return GameState.regions[clampi(GameState.region_index, 0, GameState.regions.size() - 1)]


static func index() -> int:
	return clampi(GameState.region_index, 0, COUNT - 1)


static func region_name(i: int = -1) -> String:
	ensure()
	return "Región " + String(GameState.regions[index() if i < 0 else i]["name"])


## ¿La especie vive en la Pokédex de esta región? (los legendarios, solo los suyos).
static func allows(species: SpeciesData) -> bool:
	if species == null:
		return false
	if species.is_legendary or species.is_mythical:
		return (current()["legendaries"] as Array).has(species.identifier)
	if _chains_region != index():
		_chains.clear()
		for chain in current()["chains"]:
			_chains[int(chain)] = true
		_chains_region = index()
	return _chains.has(species.evolution_chain)


## Líder de un pueblo con gimnasio: por afinidad del tema del pueblo con el líder (fijo
## por región). settlements: los asentamientos con gimnasio, en orden del mapa.
static func assign_leaders(gym_towns: Array) -> Dictionary:
	var region := current()
	var free: Array = (region["leaders"] as Array).duplicate()
	var result := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(region["seed"]) + 4049
	# Primero los pueblos con un líder afín; el resto, al azar entre los que quedan.
	for settlement: Dictionary in gym_towns:
		var theme := TownIdentity.theme_of(settlement)
		var fits := free.filter(func(id: String) -> bool: return (Leaders.GYM[id]["themes"] as Array).has(theme))
		if not fits.is_empty():
			var id: String = fits[rng.randi() % fits.size()]
			result[settlement["name"]] = id
			free.erase(id)
	for settlement: Dictionary in gym_towns:
		if not result.has(settlement["name"]) and not free.is_empty():
			result[settlement["name"]] = free.pop_at(rng.randi() % free.size())
	return result


# --- Avance de la región --------------------------------------------------------------

static func badges(i: int = -1) -> int:
	var flags: Dictionary = GameState.world_flags if i < 0 or i == index() else (GameState.regions[i]["state"] as Dictionary).get("world_flags", {})
	return (flags.get("badges", []) as Array).size()


## Medallas de todas las regiones (los héroes y el rival crecen con ellas).
static func total_badges() -> int:
	if GameState.regions.is_empty():
		return badges()
	var total := 0
	for i in GameState.regions.size():
		total += badges(i)
	return total


static func missions_done() -> int:
	var done := 0
	for path: String in MISSION_PATHS:
		done += mini(int(GameState.path_progress.get(path, 0)), int(ActivityManager.PATHS[path]["max"]))
	return done


## {"badges", "champion", "missions", "complete"} de la región actual.
static func progress() -> Dictionary:
	var b := badges()
	var champion := bool(GameState.world_flags.get("champion", false))
	var missions := missions_done()
	return {"badges": b, "champion": champion, "missions": missions,
			"complete": b >= GYMS and champion and missions >= MISSIONS_NEEDED}


## ¿Ya se dio el Boleto de esta región? (la siguiente queda abierta).
static func ticket_given() -> bool:
	return bool(GameState.world_flags.get("ticket", false))


## El profesor da el Boleto: abre la siguiente región (si queda alguna).
static func give_ticket() -> int:
	GameState.world_flags["ticket"] = true
	for i in GameState.regions.size():
		if not GameState.regions[i]["unlocked"]:
			GameState.regions[i]["unlocked"] = true
			return i
	return -1


static func unlocked() -> Array[int]:
	ensure()
	var result: Array[int] = []
	for i in GameState.regions.size():
		if GameState.regions[i]["unlocked"]:
			result.append(i)
	return result


static func transport(i: int = -1) -> String:
	return String(GameState.regions[index() if i < 0 else i]["transport"])


## Avión de la región (al azar entre los dos de B2W2, fijo por su semilla): de pasajeros
## ("plane1") o de carga de Mistralton ("plane2"). Decisión de Fernando, 2026-10-10.
static func plane_model(i: int = -1) -> String:
	return "plane1" if absi(hash(int(GameState.regions[index() if i < 0 else i]["seed"]))) % 2 == 0 else "plane2"


## Cambia de región: guarda lo de la actual y carga lo de la otra (o lo crea).
## La escena principal se recarga después (ver Main.travel_to).
static func switch_to(target: int) -> void:
	ensure()
	var here: Dictionary = GameState.regions[index()]
	var flags := GameState.world_flags.duplicate(true)
	var carried := {}
	for key: String in GLOBAL_FLAGS:
		if flags.has(key):
			carried[key] = flags[key]
			flags.erase(key)
	here["state"] = {"world_flags": flags, "activities": GameState.activities, "occupied_zones": GameState.occupied_zones,
			"path_progress": GameState.path_progress, "respawn_point": [GameState.respawn_point.x, GameState.respawn_point.y, GameState.respawn_point.z]}
	var there: Dictionary = GameState.regions[target]
	var state: Dictionary = there.get("state", {})
	GameState.region_index = target
	GameState.world_seed = int(there["seed"])
	GameState.professor = String(there["professor"])
	GameState.world_flags = (state.get("world_flags", {}) as Dictionary).duplicate(true)
	for key: String in carried:
		GameState.world_flags[key] = carried[key]
	GameState.activities = state.get("activities", [])
	GameState.occupied_zones = state.get("occupied_zones", [])
	GameState.path_progress = state.get("path_progress", {})
	_chains_region = -1


# --- Generación -----------------------------------------------------------------------

static func _name(rng: RandomNumberGenerator) -> String:
	return PREFIXES[rng.randi() % PREFIXES.size()] + SUFFIXES[rng.randi() % SUFFIXES.size()]


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = list[i]
		list[i] = list[j]
		list[j] = tmp


## 4 del Alto Mando sin repetir dentro de la región; los menos usados primero.
static func _pick_elite(use: Dictionary, rng: RandomNumberGenerator) -> Array:
	var pool: Array = Leaders.ELITE.keys()
	_shuffle(pool, rng)
	pool.sort_custom(func(a: String, b: String) -> bool: return int(use.get(a, 0)) < int(use.get(b, 0)))
	var picked := pool.slice(0, ELITE_SIZE)
	for id: String in picked:
		use[id] = int(use.get(id, 0)) + 1
	return picked


## Campeones: héroes no elegidos (sin repetir mientras alcancen).
static func _hero_pool(rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for entry in PlayerCharacters.LIST:
		if entry["id"] != GameState.character_id and Heroes.TEAMS.has(entry["id"]):
			pool.append(entry["id"])
	_shuffle(pool, rng)
	return pool


## Líneas evolutivas repartidas: cada una en al menos una región (pool[i]) y el resto al azar.
static func _chain_pool(rng: RandomNumberGenerator) -> Array:
	var chains := {}
	for species: SpeciesData in WildSpawner.ALL_SPECIES.species:
		if species.spawn_weight > 0.0 and not species.is_legendary and not species.is_mythical:
			chains[species.evolution_chain] = int(chains.get(species.evolution_chain, 0)) + 1
	var keys: Array = chains.keys()
	_shuffle(keys, rng)
	var own: Array = []
	for i in COUNT:
		own.append([])
	for k in keys.size():
		(own[k % COUNT] as Array).append(keys[k])
	return [own, chains]


static func _region_chains(data: Array, i: int, rng: RandomNumberGenerator) -> Array:
	var own: Array = (data[0] as Array)[i]
	var sizes: Dictionary = data[1]
	var result: Array = own.duplicate()
	var count := 0
	for chain in result:
		count += int(sizes[chain])
	var others: Array = sizes.keys().filter(func(c: int) -> bool: return not own.has(c))
	_shuffle(others, rng)
	for chain in others:
		if count >= DEX_TARGET:
			break
		result.append(chain)
		count += int(sizes[chain])
	return result


## Legendarios y singulares repartidos entre las regiones sin repetir.
static func _legendary_pool(rng: RandomNumberGenerator) -> Array:
	var ids: Array = []
	for species: SpeciesData in WildSpawner.ALL_SPECIES.species:
		if species.is_legendary or species.is_mythical:
			ids.append(species.identifier)
	_shuffle(ids, rng)
	var result: Array = []
	for i in COUNT:
		result.append([])
	for k in ids.size():
		(result[k % COUNT] as Array).append(ids[k])
	return result
