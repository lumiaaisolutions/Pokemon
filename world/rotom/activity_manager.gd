class_name ActivityManager
extends Node
## Rotom Móvil: actividades con plazo en días del juego para los 4 caminos (todos
## abiertos y sin orden). Al cumplirlas dan dinero, objetos, reputación y progreso
## en su camino. Si vence el plazo: se pierde la recompensa, baja la reputación del
## grupo y pasa una consecuencia (el rival se adelanta o el equipo criminal toma una
## zona), con su noticia. El elenco (profesor, rival y equipo criminal) sale al azar.

const MAX_ACTIVE := 3
const PATHS := {
	"gimnasios": {"name": "Gimnasios y Campeón", "group": "Liga Pokémon", "goal": "medallas", "max": 8},
	"concursos": {"name": "Concursos", "group": "Concursos", "goal": "cintas", "max": 5},
	"investigacion": {"name": "Investigación y mitos", "group": "Laboratorio", "goal": "descubrimientos", "max": 10},
	"academia": {"name": "Academia y Tesoro", "group": "Academia", "goal": "tesoros", "max": 6},
}
const PROFESSORS := ["Oak", "Elm", "Birch", "Rowan", "Encina", "Sycamore", "Kukui", "Magnolia", "Sada", "Turo"]
## Rival: solo los que tienen sprite original de BW2 (acordado con Fernando: de Hugh,
## Cheren y Bianca, solo Hugh está en la hoja de B2W2).
const RIVALS := ["Hugh"]
const TEAMS := ["Team Rocket", "Team Aqua", "Team Magma", "Team Galaxia", "Team Plasma", "Team Flare", "Team Skull", "Team Star"]
const TYPE_NAMES := MenuStyle.TYPE_NAMES

@export var world_path: NodePath
@export var player_path: NodePath

var _rng := RandomNumberGenerator.new()
var _last_day := -1


func _ready() -> void:
	_rng.randomize()
	if GameState.professor == "":
		GameState.professor = PROFESSORS[_rng.randi() % PROFESSORS.size()]
		GameState.rival = RIVALS[_rng.randi() % RIVALS.size()]
		GameState.villain_team = TEAMS[_rng.randi() % TEAMS.size()]
	# Partidas viejas con otro rival: pasa a uno con sprite.
	if not RIVALS.has(GameState.rival):
		GameState.rival = RIVALS[_rng.randi() % RIVALS.size()]
	for path: String in PATHS:
		if not GameState.reputation.has(PATHS[path]["group"]):
			GameState.reputation[PATHS[path]["group"]] = 50
	GameState.species_caught.connect(_on_caught)
	GameState.dex_changed.connect(_on_dex_changed)
	GameState.gathered.connect(func(_id: String, amount: int) -> void:
		_advance("gather", "", amount)
		Achievements.add("gathered", amount))
	GameState.wild_defeated.connect(func(identifier: String) -> void:
		_advance("defeat", identifier, 1)
		Achievements.add("defeated"))
	_last_day = GameState.game_day()


func _process(_delta: float) -> void:
	if GameState.party.is_empty():
		return
	var day := GameState.game_day()
	if day != _last_day:
		_last_day = day
		_check_deadlines()
		_clear_old_zones()
	_fill()


## Mantiene MAX_ACTIVE actividades (menos con reputación baja).
func _fill() -> void:
	var limit := MAX_ACTIVE
	while _active().size() < limit:
		GameState.activities.append(_generate())
		var activity: Dictionary = GameState.activities[-1]
		GameState.add_news("Nueva actividad (%s): %s. Plazo: %d días." % [PATHS[activity["path"]]["name"], activity["title"], int(activity["deadline_day"]) - GameState.game_day()])


func _active() -> Array:
	return GameState.activities.filter(func(a: Dictionary) -> bool: return not a.get("done", false) and not a.get("failed", false))


## Actividad al azar para un camino; más difícil si el rival va adelante.
func _generate() -> Dictionary:
	var path: String = PATHS.keys()[_rng.randi() % PATHS.size()]
	var extra := int(GameState.rival_progress.get(path, 0))
	var kind: String = ["capture_type", "register", "see", "gather", "defeat", "behind"][_rng.randi() % 6]
	var activity := {"id": GameState.next_activity_id(), "path": path, "kind": kind, "progress": 0,
			"deadline_day": GameState.game_day() + _rng.randi_range(1, 5), "money": 0, "item": "", "item_amount": 0}
	match kind:
		"capture_type":
			var type := _rng.randi() % 18
			activity["param"] = type
			activity["target"] = 1 + extra
			activity["title"] = "Captura %d Pokémon de tipo %s" % [activity["target"], TYPE_NAMES[type]]
		"register":
			activity["target"] = 2 + extra
			activity["title"] = "Registra %d especies nuevas como capturadas" % activity["target"]
		"see":
			activity["target"] = 4 + extra * 2
			activity["title"] = "Encuentra %d especies que no habías visto" % activity["target"]
		"gather":
			activity["target"] = 5 + extra * 2
			activity["title"] = "Recolecta %d objetos (bayas, bonguris, setas, minerales)" % activity["target"]
		"defeat":
			activity["target"] = 2 + extra
			activity["title"] = "Debilita a %d salvajes con tu compañero" % activity["target"]
		"behind":
			activity["target"] = 1 + extra
			activity["title"] = "Captura %d Pokémon por la espalda" % activity["target"]
	var rep := float(GameState.reputation.get(PATHS[path]["group"], 50))
	activity["money"] = int(round((500 + 250 * int(activity["target"])) * (0.5 + rep / 100.0)))
	var items := ["great-ball", "ultra-ball", "potion", "super-potion", "sitrus-berry", "rare-candy", "quick-ball", "net-ball", "dusk-ball", "honey"]
	activity["item"] = items[_rng.randi() % items.size()]
	activity["item_amount"] = _rng.randi_range(1, 3)
	return activity


func _on_caught(identifier: String, behind: bool) -> void:
	var species := MenuStyle.species(identifier)
	for activity: Dictionary in _active():
		if activity["kind"] == "capture_type" and species != null and species.types.has(int(activity["param"])):
			_progress(activity, 1)
		elif activity["kind"] == "behind" and behind:
			_progress(activity, 1)


func _on_dex_changed(identifier: String) -> void:
	var entry: Dictionary = GameState.dex.get(identifier, {})
	for activity: Dictionary in _active():
		if activity["kind"] == "register" and int(entry.get("caught", 0)) == 1 and not activity.get("counted", {}).has(identifier):
			_count_once(activity, identifier)
		elif activity["kind"] == "see" and int(entry.get("seen", 0)) == 1 and not activity.get("counted", {}).has(identifier):
			_count_once(activity, identifier)


func _count_once(activity: Dictionary, identifier: String) -> void:
	var counted: Dictionary = activity.get("counted", {})
	counted[identifier] = true
	activity["counted"] = counted
	_progress(activity, 1)


func _advance(kind: String, _identifier: String, amount: int) -> void:
	for activity: Dictionary in _active():
		if activity["kind"] == kind:
			_progress(activity, amount)


func _progress(activity: Dictionary, amount: int) -> void:
	activity["progress"] = mini(int(activity["progress"]) + amount, int(activity["target"]))
	if int(activity["progress"]) >= int(activity["target"]):
		_complete(activity)


func _complete(activity: Dictionary) -> void:
	activity["done"] = true
	var path: Dictionary = PATHS[activity["path"]]
	GameState.add_money(int(activity["money"]), "Actividad: " + activity["title"])
	Achievements.add("activities")
	GameState.add_item(activity["item"], int(activity["item_amount"]))
	var group: String = path["group"]
	GameState.reputation[group] = mini(int(GameState.reputation.get(group, 50)) + 6, 100)
	GameState.path_progress[activity["path"]] = mini(int(GameState.path_progress.get(activity["path"], 0)) + 1, int(path["max"]))
	GameState.add_news("¡Actividad cumplida! %s. Ganaste $%d y %s × %d. (%s: %d/%d %s)" % [activity["title"], int(activity["money"]),
			Items.display_name(activity["item"]), int(activity["item_amount"]), path["name"], int(GameState.path_progress[activity["path"]]), int(path["max"]), path["goal"]])


## Plazos vencidos: se pierde la recompensa, baja la reputación y pasa algo en el mundo.
func _check_deadlines() -> void:
	for activity: Dictionary in _active():
		if GameState.game_day() <= int(activity["deadline_day"]):
			continue
		activity["failed"] = true
		var path: Dictionary = PATHS[activity["path"]]
		var group: String = path["group"]
		GameState.reputation[group] = maxi(int(GameState.reputation.get(group, 50)) - 10, 0)
		if _rng.randf() < 0.5:
			GameState.rival_progress[activity["path"]] = int(GameState.rival_progress.get(activity["path"], 0)) + 1
			GameState.add_news("Se venció el plazo de \"%s\". Tu rival %s se adelantó en %s; la próxima prueba será más difícil." % [activity["title"], GameState.rival, path["name"]])
		else:
			_occupy_zone()
			GameState.add_news("Se venció el plazo de \"%s\". ¡El %s tomó una zona de la región! Los Pokémon de ahí están alterados." % [activity["title"], GameState.villain_team])


## El equipo criminal toma una zona por 3 días: ahí aparecen más tipos Siniestro y Veneno.
func _occupy_zone() -> void:
	var world := get_node_or_null(world_path) as WorldBuilder
	var half := (world.config.size * 0.5 - 40.0) if world != null else 200.0
	GameState.occupied_zones.append({"x": _rng.randf_range(-half, half), "z": _rng.randf_range(-half, half), "radius": 45.0, "until_day": GameState.game_day() + 3})


func _clear_old_zones() -> void:
	GameState.occupied_zones = GameState.occupied_zones.filter(func(z: Dictionary) -> bool: return int(z["until_day"]) >= GameState.game_day())


## ¿El punto está en una zona tomada por el equipo criminal?
static func is_occupied(point: Vector3) -> bool:
	for zone: Dictionary in GameState.occupied_zones:
		if Vector2(point.x - float(zone["x"]), point.z - float(zone["z"])).length() <= float(zone["radius"]):
			return true
	return false
