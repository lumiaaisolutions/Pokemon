class_name Heroes
extends Node3D
## Héroes no elegidos (acordado con Fernando el 2026-10-10): los 9 protagonistas que no
## elegiste existen en el mundo como entrenadores únicos, fuertes y competitivos.
## - Viajan por la región: cada día están en un pueblo o lugar distinto (de 8 a 20 h).
## - El Rotom avisa rumores de dónde se vio a dos de ellos cada día (y se marcan en el mapa).
## - Equipo fijo e icónico de 6, con una mega; crecen contigo según tus medallas: de 2 a 6
##   Pokémon y de formas básicas a finales; megaevolucionan desde las 6 medallas.
## - IA lista: eligen al siguiente por ventaja de tipo, se curan 2 veces y esquivan.
## - Al hablarles te retan (premio grande); revancha al día siguiente.

const SPAWN_DISTANCE := 120.0
const DESPAWN_DISTANCE := 170.0
## Equipo icónico (en orden) y su mega.
const TEAMS := {
	"red": {"team": ["pikachu", "charizard", "venusaur", "blastoise", "snorlax", "lapras"], "mega": "charizard-mega-x",
		"lines": ["...", "(Te mira en silencio y saca una Pokéball.)"]},
	"leaf": {"team": ["venusaur", "clefable", "espeon", "ninetales", "pidgeot", "lapras"], "mega": "venusaur-mega",
		"lines": ["¡Hola! Vengo de Kanto buscando entrenadores fuertes.", "¿Me enseñas qué tan unido estás a tu equipo?"]},
	"ethan": {"team": ["typhlosion", "ampharos", "togekiss", "heracross", "quagsire", "ursaring"], "mega": "ampharos-mega",
		"lines": ["¡Eh! ¡Tú también recorres la región!", "Dicen que eres bueno. ¡A ver si es cierto!"]},
	"lyra": {"team": ["meganium", "azumarill", "steelix", "wigglytuff", "furret", "xatu"], "mega": "steelix-mega",
		"lines": ["¡Qué Pokémon tan bonitos tienes!", "Pero los míos también son fuertes, ¿peleamos?"]},
	"brendan": {"team": ["sceptile", "swellow", "breloom", "manectric", "aggron", "salamence"], "mega": "sceptile-mega",
		"lines": ["Mi padre es líder de gimnasio en Hoenn.", "¡No pienso perder contra nadie!"]},
	"may": {"team": ["blaziken", "beautifly", "delcatty", "altaria", "wailord", "glalie"], "mega": "blaziken-mega",
		"lines": ["¡Hola! Estoy investigando los Pokémon de esta región.", "¡Un combate es la mejor forma de conocerlos!"]},
	"lucas": {"team": ["infernape", "staraptor", "luxray", "garchomp", "roserade", "bronzong"], "mega": "garchomp-mega",
		"lines": ["El profesor me pidió registrar todo lo que vea.", "Y tú me pareces muy interesante. ¡Combate!"]},
	"dawn": {"team": ["empoleon", "lopunny", "togekiss", "pachirisu", "mamoswine", "froslass"], "mega": "lopunny-mega",
		"lines": ["¡No hay de qué preocuparse!", "¡Mi equipo está listo para lucirse! ¿Y el tuyo?"]},
	"calem": {"team": ["greninja", "talonflame", "aegislash", "gyarados", "hawlucha", "goodra"], "mega": "gyarados-mega",
		"lines": ["Busco al entrenador más fuerte de esta región.", "Tal vez seas tú. Demuéstralo."]},
	"serena": {"team": ["delphox", "sylveon", "pangoro", "absol", "florges", "tyrantrum"], "mega": "absol-mega",
		"lines": ["¡Qué gusto encontrarte!", "Quiero ver cómo combates. ¡Sin contenerte!"]},
}

@export var world_path: NodePath = NodePath("../World")
@export var player_path: NodePath = NodePath("../Player")

var _world: WorldBuilder
var _player: Player
var _main: Node
var _active := {}
var _check := 0.0
var _rumor_day := -1


func _ready() -> void:
	add_to_group(&"heroes")
	_main = get_parent()
	_world = get_node(world_path) as WorldBuilder
	_player = get_node(player_path) as Player


## Los 9 héroes de esta partida (todos menos tu personaje).
func roster() -> Array[String]:
	var result: Array[String] = []
	for entry in PlayerCharacters.LIST:
		if entry["id"] != GameState.character_id and TEAMS.has(entry["id"]):
			result.append(entry["id"])
	return result


## Dónde está hoy un héroe: un pueblo o lugar elegido por día (fijo por semilla).
func location(id: String, day: int = -1) -> Dictionary:
	if day < 0:
		day = GameState.game_day()
	var spots: Array = []
	for settlement: Dictionary in _world.layout.settlements:
		spots.append({"name": settlement["name"], "x": float(settlement["x"]) + 8.0, "z": float(settlement["z"]) + 8.0})
	for place: Dictionary in _world.layout.places:
		spots.append({"name": Structures.place_title(place), "x": float(place["x"]) + 10.0, "z": float(place["z"]) + 10.0})
	if spots.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d" % [id, day, GameState.world_seed])
	return spots[rng.randi() % spots.size()]


static func present(hour: float) -> bool:
	return hour >= 8.0 and hour < 20.0


func _process(delta: float) -> void:
	if _player == null:
		return
	_rumors()
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	var here := Vector2(_player.global_position.x, _player.global_position.z)
	var inside := _player.global_position.x > WorldBuilder.INTERIOR_X
	var hour := GameState.clock_hour()
	for id in roster():
		var spot := location(id)
		var at := Vector2(float(spot.get("x", 0.0)), float(spot.get("z", 0.0)))
		var near := not inside and present(hour) and not spot.is_empty() and at.distance_to(here) < (DESPAWN_DISTANCE if _active.has(id) else SPAWN_DISTANCE)
		if near and not _active.has(id):
			_active[id] = _spawn(id, at)
		elif not near and _active.has(id):
			_despawn(id)


## Rumores del día en el Rotom: dónde se vio a dos héroes.
func _rumors() -> void:
	var day := GameState.game_day()
	if day == _rumor_day:
		return
	_rumor_day = day
	var key := "hero_rumors:%d" % day
	if GameState.world_flags.has(key):
		return
	var ids := roster()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rumor:%d:%d" % [day, GameState.world_seed])
	var chosen: Array = []
	for i in mini(2, ids.size()):
		var id: String = ids[rng.randi() % ids.size()]
		if not chosen.has(id):
			chosen.append(id)
			GameState.add_news("Rumor: vieron a %s cerca de %s (de 8:00 a 20:00)." % [PlayerCharacters.find(id)["name"], location(id, day).get("name", "?")])
	GameState.world_flags[key] = chosen


## Héroes con rumor hoy (para el mapa).
func rumored_today() -> Array:
	return GameState.world_flags.get("hero_rumors:%d" % GameState.game_day(), [])


func _spawn(id: String, at: Vector2) -> Dictionary:
	var node := Node3D.new()
	node.name = "Hero_" + id
	add_child(node)
	node.global_position = Vector3(at.x, _world.surface_height_at(at.x, at.y), at.y)
	var sprite := DirectionalSprite.new()
	sprite.name = "Sprite"
	sprite.step_cycle = PackedInt32Array([0, 1, 0, 2])
	sprite.walk_fps = 6.0
	node.add_child(sprite)
	sprite.setup(PlayerCharacters.sheet(id), 3, 8, 0.057)
	var label := Label3D.new()
	label.text = "★ " + String(PlayerCharacters.find(id)["name"])
	label.font_size = 34
	label.pixel_size = 0.01
	label.outline_size = 8
	label.modulate = Color(1.0, 0.85, 0.3)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.2
	label.visibility_range_end = 20.0
	node.add_child(label)
	var hero := {"id": id, "node": node, "home": at, "wait": 2.0, "target": at}
	hero["point"] = _world.structures.add_point(node.global_position + Vector3.UP * 0.5, "Hablar con %s" % PlayerCharacters.find(id)["name"], _talk.bind(hero), 2.4)
	return hero


func _despawn(id: String) -> void:
	var hero: Dictionary = _active[id]
	_world.structures.remove_point(hero["point"])
	(hero["node"] as Node).queue_free()
	_active.erase(id)


func _physics_process(delta: float) -> void:
	for hero: Dictionary in _active.values():
		var node: Node3D = hero["node"]
		var sprite := node.get_node("Sprite") as DirectionalSprite
		var velocity := Vector3.ZERO
		if hero.get("busy", false):
			sprite.look_at_point(_player.global_position)
		else:
			# Pasea por el lugar (radio de 6 m) y mira a su alrededor.
			hero["wait"] = float(hero["wait"]) - delta
			var here := Vector2(node.global_position.x, node.global_position.z)
			var to: Vector2 = (hero["target"] as Vector2) - here
			if to.length() > 0.3:
				var step := to.normalized() * minf(2.2 * delta, to.length())
				node.global_position.x += step.x
				node.global_position.z += step.y
				velocity = Vector3(to.normalized().x, 0, to.normalized().y) * 2.2
			elif float(hero["wait"]) <= 0.0:
				hero["wait"] = randf_range(3.0, 7.0)
				hero["target"] = (hero["home"] as Vector2) + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 6.0)
		node.global_position.y = TownNPCs.swim_height(_world, node)
		sprite.animate(velocity, delta)
		(hero["point"] as Dictionary)["pos"] = node.global_position + Vector3.UP * 0.5


func beaten_today(id: String) -> bool:
	return int(GameState.world_flags.get("trainer_beaten:hero:" + id, -1)) == GameState.game_day()


func _talk(hero: Dictionary) -> void:
	var id: String = hero["id"]
	var dialog := get_tree().get_first_node_in_group(&"dialog_box") as DialogBox
	var name: String = PlayerCharacters.find(id)["name"]
	var portrait := AtlasTexture.new()
	portrait.atlas = PlayerCharacters.sheet(id)
	portrait.region = Rect2(0, 0, 32, 32)
	hero["busy"] = true
	var lines: Array = (TEAMS[id]["lines"] as Array).duplicate()
	var options: Array = ["Retar", "Adiós"]
	if beaten_today(id):
		lines = ["Hoy me ganaste... pero mañana será distinto.", "¡Entrenaré con mi equipo!"]
		options = []
	if dialog == null:
		hero["busy"] = false
		return
	dialog.open(name, lines, portrait, options, func(index: int) -> void:
		if index == 0:
			_challenge(hero))
	dialog.closed.connect(func() -> void:
		if not hero.get("battling", false):
			hero["busy"] = false, CONNECT_ONE_SHOT)


## Equipo según tus medallas: de 2 a 6 Pokémon y de formas básicas a finales.
static func team_for(id: String, badges: int) -> Array[SpeciesData]:
	var size := clampi(2 + int(ceil(badges / 2.0)), 2, 6)
	var stage := 1 if badges < 2 else (2 if badges < 5 else 3)
	var result: Array[SpeciesData] = []
	for identifier: String in (TEAMS[id]["team"] as Array).slice(0, size):
		result.append(MenuStyle.species(_stage_form(identifier, stage)))
	return result


## La forma de esa etapa de su línea evolutiva (si la final es etapa 3 y piden 1, la básica).
static func _stage_form(identifier: String, stage: int) -> String:
	var current := identifier
	var species := MenuStyle.species(current)
	while species != null and species.evolution_stage > stage:
		var previous := _pre_evolution(current)
		if previous == "":
			break
		current = previous
		species = MenuStyle.species(current)
	return current


static var _reverse := {}


static func _pre_evolution(identifier: String) -> String:
	if _reverse.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Evolution.PATH))
		for from: String in data:
			for option: Dictionary in data[from]:
				_reverse[option["to"]] = from
	return _reverse.get(identifier, "")


func _challenge(hero: Dictionary) -> void:
	var battle := _main.get_node_or_null("Battle") as BattleManager
	var id: String = hero["id"]
	if battle == null or not battle.ready_to_fight():
		GameState.notice.emit("%s: Saca a tu Pokémon y peleamos." % PlayerCharacters.find(id)["name"])
		hero["busy"] = false
		return
	var badges := Regions.total_badges()
	var node: Node3D = hero["node"]
	var info := {"id": "hero:" + id, "name": PlayerCharacters.find(id)["name"], "team": team_for(id, badges),
			"money": 1500 + 600 * badges, "item": ["rare-candy", "star-piece", "ultra-ball", "nugget"][badges % 4],
			"smart": true, "heals": 2, "mega": TEAMS[id]["mega"] if badges >= 6 else "",
			"at": node.global_position + (_player.global_position - node.global_position).normalized() * 3.0}
	hero["battling"] = true
	info["on_end"] = func(_result: String) -> void:
		hero["battling"] = false
		hero["busy"] = false
	if not battle.start_trainer(info):
		hero["battling"] = false
		hero["busy"] = false


func active_heroes() -> Array:
	return _active.values()
