class_name GymLeaders
extends Node3D
## Vida de los líderes de gimnasio (pedido de Fernando el 2026-10-10: "que no se queden
## estáticos en su gimnasio, similar al profesor"):
## - Gimnasio de 9 a 15 h; de 15 a 20 h entrenan con su Pokémon en un lugar de su tipo
##   cerca del pueblo (agua, rocas, pasto…); de noche en su casa.
## - 1 día por semana viajan a otro pueblo o lugar del mapa (de 9 a 20 h).
## - Caminan por el pueblo entre el gimnasio, su lugar de entrenamiento y su casa.
## - La medalla solo se gana en el gimnasio. Fuera, combate amistoso (uno por día, con
##   dinero y sin medalla). Si no está, un entrenador del gimnasio dice dónde anda y se
##   marca en el mapa.

const SPAWN_DISTANCE := 260.0
const DESPAWN_DISTANCE := 320.0
const WALK_SPEED := 2.4
const TALK_RADIUS := 2.4
const GYM_START := 9.0
const GYM_END := 15.0
const TRAINING_END := 20.0
const FRIENDLY_MONEY := 900
## Hábitats preferidos para entrenar según el tipo del líder.
const TRAINING_HABITATS := {
	PokemonTypes.Type.WATER: [SpeciesData.Habitat.FRESHWATER, SpeciesData.Habitat.SEA],
	PokemonTypes.Type.ICE: [SpeciesData.Habitat.MOUNTAIN, SpeciesData.Habitat.FRESHWATER],
	PokemonTypes.Type.GRASS: [SpeciesData.Habitat.FOREST, SpeciesData.Habitat.MEADOW],
	PokemonTypes.Type.BUG: [SpeciesData.Habitat.FOREST],
	PokemonTypes.Type.POISON: [SpeciesData.Habitat.SWAMP, SpeciesData.Habitat.FOREST],
	PokemonTypes.Type.GHOST: [SpeciesData.Habitat.FOREST, SpeciesData.Habitat.SWAMP],
	PokemonTypes.Type.ROCK: [SpeciesData.Habitat.MOUNTAIN], PokemonTypes.Type.GROUND: [SpeciesData.Habitat.MOUNTAIN],
	PokemonTypes.Type.STEEL: [SpeciesData.Habitat.MOUNTAIN], PokemonTypes.Type.FIGHTING: [SpeciesData.Habitat.MOUNTAIN],
	PokemonTypes.Type.DRAGON: [SpeciesData.Habitat.MOUNTAIN], PokemonTypes.Type.FLYING: [SpeciesData.Habitat.MEADOW, SpeciesData.Habitat.MOUNTAIN],
}

var _world: WorldBuilder
var _player: Player
var _main: Node
## id del líder -> {"id", "settlement", "node", "pet", "point", "status", "route", "wait", "anchor"}.
var _active := {}
var _spots := {}
var _check := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"gym_leaders")
	_rng.randomize()
	_main = get_parent()
	_world = _main.get_node("World") as WorldBuilder
	_player = _main.get_node("Player") as Player


# --- Rutina ---------------------------------------------------------------------------

## ¿Viaja este día? (1 día por semana, fijo por líder y semilla).
static func traveling(id: String, day: int = -1) -> bool:
	if day < 0:
		day = GameState.game_day()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("leader_week:%s:%d:%d" % [id, day / 7, GameState.world_seed])
	return day % 7 == rng.randi() % 7


## "gym", "training", "home", "trip" (de viaje, visible allá) o "away" (de viaje, de noche).
static func status(id: String, hour: float = -1.0, day: int = -1) -> String:
	if hour < 0.0:
		hour = GameState.clock_hour()
	var awake := hour >= GYM_START and hour < TRAINING_END
	if traveling(id, day):
		return "trip" if awake else "away"
	if hour >= GYM_START and hour < GYM_END:
		return "gym"
	if awake:
		return "training"
	return "home"


## Pueblos con gimnasio: [{"settlement", "id"}].
func gyms() -> Array:
	var result: Array = []
	for settlement: Dictionary in _world.layout.settlements:
		var id := _world.structures.leader_of(settlement)
		if id != "":
			result.append({"settlement": settlement, "id": id})
	return result


func settlement_of(id: String) -> Dictionary:
	for entry: Dictionary in gyms():
		if entry["id"] == id:
			return entry["settlement"]
	return {}


## ¿Está el líder en su gimnasio ahora? (si no, no se puede ganar la medalla).
func in_gym(settlement: Dictionary) -> bool:
	return status(_world.structures.leader_of(settlement)) == "gym"


func _building(settlement: Dictionary, kind: String, seed_key: String) -> Dictionary:
	var options: Array = (settlement["buildings"] as Array).filter(func(b: Dictionary) -> bool: return b["kind"] == kind)
	if options.is_empty():
		return {}
	return options[absi(hash(seed_key)) % options.size()]


func _door(settlement: Dictionary, building: Dictionary) -> Vector2:
	var b := Vector2(float(building["x"]), float(building["z"]))
	var to_center := (Vector2(float(settlement["x"]), float(settlement["z"])) - b).normalized()
	return b + to_center * (float(building["d"]) * 0.5 + 1.6)


func _plaza(settlement: Dictionary) -> Vector2:
	return Vector2(float(settlement["x"]), float(settlement["z"]))


func gym_door(settlement: Dictionary) -> Vector2:
	var gym := _building(settlement, "gym", "gym")
	return _door(settlement, gym) if not gym.is_empty() else _plaza(settlement)


func home_door(settlement: Dictionary, id: String) -> Vector2:
	var home := _building(settlement, "house", "leader_home:" + id)
	if home.is_empty():
		home = _building(settlement, "cabin", "leader_home:" + id)
	return _door(settlement, home) if not home.is_empty() else _plaza(settlement) + Vector2(6, 6)


## Lugar de entrenamiento: fuera del pueblo, en un hábitat de su tipo si lo hay cerca.
func training_spot(settlement: Dictionary, id: String) -> Vector2:
	if _spots.has(id):
		return _spots[id]
	var plaza := _plaza(settlement)
	var wanted: Array = TRAINING_HABITATS.get(int(Leaders.info(id).get("type", -1)), [SpeciesData.Habitat.MEADOW])
	var radius := float(settlement["radius"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("leader_spot:" + id) ^ _world.layout.seed
	var best := plaza + Vector2.from_angle(rng.randf() * TAU) * (radius + 18.0)
	var best_score := -1
	for i in 24:
		var angle := TAU * i / 24.0 + rng.randf_range(-0.1, 0.1)
		var at := plaza + Vector2.from_angle(angle) * rng.randf_range(radius + 12.0, radius + 40.0)
		if _world.height_at(at.x, at.y) < _world.layout.sea_level + 0.6:
			continue
		var score := 0
		# Al lado de su hábitat (los de agua, en la orilla).
		for k in 4:
			var near := at + Vector2.from_angle(TAU * k / 4.0) * 6.0
			if wanted.has(_world.habitat_at(near.x, near.y)):
				score += 1
		if wanted.has(_world.habitat_at(at.x, at.y)) and not (_world.habitat_at(at.x, at.y) in [SpeciesData.Habitat.FRESHWATER, SpeciesData.Habitat.SEA]):
			score += 2
		if score > best_score:
			best_score = score
			best = at
	_spots[id] = best
	return best


## Viaje de hoy: otro pueblo o un lugar del mapa (fijo por día).
func trip_spot(id: String, day: int = -1) -> Dictionary:
	if day < 0:
		day = GameState.game_day()
	var home := settlement_of(id)
	var spots: Array = []
	for settlement: Dictionary in _world.layout.settlements:
		if settlement != home:
			spots.append({"name": settlement["name"], "x": float(settlement["x"]) - 9.0, "z": float(settlement["z"]) + 7.0})
	for place: Dictionary in _world.layout.places:
		spots.append({"name": Structures.place_title(place), "x": float(place["x"]) - 9.0, "z": float(place["z"]) + 9.0})
	if spots.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("leader_trip:%s:%d:%d" % [id, day, GameState.world_seed])
	return spots[rng.randi() % spots.size()]


## Dónde anda ahora: {"text", "x", "z"} (para el entrenador del gimnasio y el mapa).
func where(id: String) -> Dictionary:
	var settlement := settlement_of(id)
	var name := Leaders.name_of(id)
	match status(id):
		"gym":
			var door := gym_door(settlement)
			return {"text": "%s está en el gimnasio (de 9:00 a 15:00)." % name, "x": door.x, "z": door.y}
		"training":
			var spot := training_spot(settlement, id)
			return {"text": "%s salió a entrenar cerca del pueblo hasta las 20:00. ¡Te lo marco en el mapa!" % name, "x": spot.x, "z": spot.y}
		"trip", "away":
			var trip := trip_spot(id)
			return {"text": "%s se fue de viaje hoy a %s. ¡Te lo marco en el mapa! Vuelve mañana al gimnasio." % [name, trip.get("name", "otro lugar")],
					"x": float(trip.get("x", 0.0)), "z": float(trip.get("z", 0.0))}
	var home := home_door(settlement, id)
	return {"text": "%s ya se fue a su casa. Abre el gimnasio mañana a las 9:00." % name, "x": home.x, "z": home.y}


## El entrenador del gimnasio dice dónde está el líder y lo marca en el mapa (hoy).
func mark_on_map(id: String) -> String:
	var hints: Dictionary = GameState.world_flags.get("leader_hints", {})
	hints[id] = GameState.game_day()
	GameState.world_flags["leader_hints"] = hints
	return String(where(id)["text"])


## Marcas del mapa: los líderes que te dijeron hoy dónde andan.
func map_marks() -> Array:
	var result: Array = []
	var hints: Dictionary = GameState.world_flags.get("leader_hints", {})
	for id: String in hints:
		if int(hints[id]) == GameState.game_day() and status(id) in ["training", "trip"]:
			var spot := where(id)
			result.append({"id": id, "x": spot["x"], "z": spot["z"], "text": spot["text"]})
	return result


# --- Presencia en el mundo ------------------------------------------------------------

func _process(delta: float) -> void:
	if _world == null or _player == null:
		return
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		_update_presence()
	for leader: Dictionary in _active.values():
		_update_leader(leader, delta)


## Dónde debería verse: el pueblo (rutina) o el lugar del viaje.
func _anchor(id: String, settlement: Dictionary) -> Vector2:
	var s := status(id)
	if s in ["trip", "away"]:
		var trip := trip_spot(id)
		return Vector2(float(trip.get("x", 0.0)), float(trip.get("z", 0.0)))
	return _plaza(settlement)


func _update_presence() -> void:
	var p := Vector2(_player.global_position.x, _player.global_position.z)
	var outside := _player.global_position.x < WorldBuilder.INTERIOR_X
	for entry: Dictionary in gyms():
		var id: String = entry["id"]
		var anchor := _anchor(id, entry["settlement"])
		var distance := p.distance_to(anchor)
		var visible_status := status(id) != "away"
		if outside and visible_status and distance < SPAWN_DISTANCE and not _active.has(id):
			_active[id] = _spawn(id, entry["settlement"])
		elif _active.has(id) and (not visible_status or distance > DESPAWN_DISTANCE or not outside):
			_despawn(id)


func _spawn(id: String, settlement: Dictionary) -> Dictionary:
	var node := Node3D.new()
	node.name = "Leader_" + id
	add_child(node)
	var sprite := DirectionalSprite.new()
	sprite.name = "Sprite"
	sprite.step_cycle = PackedInt32Array([0, 1, 0, 2])
	sprite.walk_fps = 5.0
	node.add_child(sprite)
	sprite.setup(Leaders.sheet(id), 3, 8, 0.057)
	sprite.material_override = SpriteMaterials.for_texture(sprite.texture)
	var label := Label3D.new()
	label.text = "Líder " + Leaders.name_of(id)
	label.font_size = 34
	label.pixel_size = 0.01
	label.outline_size = 8
	label.modulate = Color(1.0, 0.85, 0.4)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.2
	label.visibility_range_end = 22.0
	node.add_child(label)
	var leader := {"id": id, "settlement": settlement, "node": node, "status": "", "route": [] as Array[Vector2], "wait": 0.0}
	leader["pet"] = _make_pet(id)
	var start := _start_position(id, settlement)
	node.global_position = Vector3(start.x, _world.surface_height_at(start.x, start.y), start.y)
	leader["point"] = _world.structures.add_point(node.global_position, "Hablar con el líder %s" % Leaders.name_of(id), talk.bind(leader), TALK_RADIUS)
	return leader


## Al aparecer: ya en su lugar de la hora (el trayecto se ve en los cambios de hora).
func _start_position(id: String, settlement: Dictionary) -> Vector2:
	match status(id):
		"gym":
			return gym_door(settlement)
		"training":
			return training_spot(settlement, id)
		"trip":
			return _anchor(id, settlement)
	return home_door(settlement, id)


func _despawn(id: String) -> void:
	var leader: Dictionary = _active[id]
	_world.structures.remove_point(leader["point"])
	(leader["node"] as Node).queue_free()
	if leader.has("pet") and is_instance_valid(leader["pet"]):
		(leader["pet"] as Node).queue_free()
	_active.erase(id)


## Su Pokémon estrella (el más fuerte que no sea enorme) lo acompaña a entrenar.
func _make_pet(id: String) -> Node3D:
	var pet := Node3D.new()
	pet.name = "LeaderPet_" + id
	add_child(pet)
	var team: Array = Leaders.info(id).get("team", [])
	for i in range(team.size() - 1, -1, -1):
		var species := MenuStyle.species(team[i])
		if species != null and species.overworld_sheet != null and species.size_scale <= 1.4:
			var sprite := DirectionalSprite.new()
			sprite.name = "Sprite"
			pet.add_child(sprite)
			sprite.setup(species.overworld_sheet, 2, 4, PokemonActor.PIXEL_SIZE * species.size_scale * 32.0 / species.overworld_cell, species.foot_offset_px)
			pet.set_meta("species", species.identifier)
			break
	return pet


func _update_leader(leader: Dictionary, delta: float) -> void:
	var node: Node3D = leader["node"]
	var sprite := node.get_node("Sprite") as DirectionalSprite
	var settlement: Dictionary = leader["settlement"]
	var id: String = leader["id"]
	if leader.get("busy", false):
		sprite.look_at_point(_player.global_position)
		sprite.animate(Vector3.ZERO, delta)
		_pet_follow(leader, sprite, Vector3.ZERO, delta, false)
		return
	var s := status(id)
	if s != leader["status"]:
		leader["status"] = s
		var target: Vector2 = {"gym": gym_door(settlement), "training": training_spot(settlement, id), "home": home_door(settlement, id)}.get(s, _anchor(id, settlement))
		var here := Vector2(node.global_position.x, node.global_position.z)
		# Salto de hora (dormir, o lejos de tu vista): ya está en su lugar.
		if here.distance_to(target) > 60.0 and node.global_position.distance_to(_player.global_position) > 40.0:
			node.global_position = Vector3(target.x, _world.surface_height_at(target.x, target.y), target.y)
			here = target
		var route: Array[Vector2] = []
		if s != "trip":
			# Por la plaza, como los habitantes (las puertas miran a ella).
			var plaza := _plaza(settlement)
			if here.distance_to(plaza) > 4.0 and target.distance_to(plaza) > 4.0:
				route.append(plaza)
		route.append(target)
		leader["route"] = route
		leader["post"] = target
		node.visible = true
	var route: Array[Vector2] = leader["route"]
	var velocity := Vector3.ZERO
	if not route.is_empty():
		var here := Vector2(node.global_position.x, node.global_position.z)
		var to := route[0] - here
		if to.length() < 0.3:
			route.pop_front()
			# Llegó al gimnasio o a su casa: entra.
			if route.is_empty() and s in ["gym", "home"]:
				node.visible = false
		else:
			var step := to.normalized() * minf(WALK_SPEED * delta, to.length())
			velocity = Vector3(to.normalized().x, 0, to.normalized().y) * WALK_SPEED
			node.global_position.x += step.x
			node.global_position.z += step.y
	elif s in ["training", "trip"]:
		# Entrena: da vueltas cortas alrededor de su lugar con su Pokémon.
		leader["wait"] = float(leader["wait"]) - delta
		if float(leader["wait"]) <= 0.0:
			leader["wait"] = _rng.randf_range(4.0, 9.0)
			leader["route"] = [(leader["post"] as Vector2) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.5, 3.0)] as Array[Vector2]
	node.global_position.y = TownNPCs.swim_height(_world, node)
	if velocity == Vector3.ZERO and node.visible and _player.global_position.distance_to(node.global_position) < 5.0:
		sprite.look_at_point(_player.global_position)
	sprite.animate(velocity, delta)
	_pet_follow(leader, sprite, velocity, delta, s == "training" and route.is_empty())
	var point: Dictionary = leader["point"]
	point["pos"] = node.global_position + Vector3.UP * 0.5
	point["radius"] = TALK_RADIUS if node.visible else 0.0


## El Pokémon lo sigue; entrenando, se queda frente a él dando saltitos.
func _pet_follow(leader: Dictionary, owner_sprite: DirectionalSprite, velocity: Vector3, delta: float, training: bool) -> void:
	var pet: Node3D = leader.get("pet")
	if pet == null or not is_instance_valid(pet):
		return
	var node: Node3D = leader["node"]
	pet.visible = node.visible
	var target := node.global_position + owner_sprite.facing_world * 1.8 if training else node.global_position - owner_sprite.facing_world * 1.3
	var before := pet.global_position
	if before.distance_to(target) > 8.0:
		pet.global_position = target
	else:
		pet.global_position = before.lerp(target, minf(delta * 3.0, 1.0))
	pet.global_position.y = TownNPCs.swim_height(_world, pet)
	var sprite := pet.get_node_or_null("Sprite") as DirectionalSprite
	if sprite != null:
		if training:
			sprite.position.y = absf(sin(GameState.play_time * 6.0)) * 0.25
			sprite.look_at_point(node.global_position)
		else:
			sprite.position.y = 0.0
		sprite.animate((pet.global_position - before) / maxf(delta, 0.001) if velocity != Vector3.ZERO else Vector3.ZERO, delta)


# --- Hablar y combate amistoso ----------------------------------------------------------

func _dialog() -> DialogBox:
	return get_tree().get_first_node_in_group(&"dialog_box") as DialogBox


func friendly_done_today(id: String) -> bool:
	return int(GameState.world_flags.get("leader_friendly:" + id, -1)) == GameState.game_day()


func talk(leader: Dictionary) -> void:
	var id: String = leader["id"]
	var speaker := "Líder " + Leaders.name_of(id)
	var settlement: Dictionary = leader["settlement"]
	var s := status(id)
	var lines: Array = []
	match s:
		"training":
			lines = ["Estoy entrenando con mi equipo de tipo %s. El gimnasio abre de 9:00 a 15:00." % Leaders.type_name(id)]
		"trip":
			lines = ["Hoy vine de visita desde %s. ¡Mañana vuelvo a mi gimnasio!" % settlement.get("name", "mi pueblo")]
		_:
			lines = ["¡Hola! Soy %s, líder del Gimnasio de %s." % [Leaders.name_of(id), settlement.get("name", "")]]
	var dialog := _dialog()
	if friendly_done_today(id):
		lines.append("Ya tuvimos un combate hoy. ¡Mañana otro!")
		if dialog != null:
			dialog.open(speaker, lines, Leaders.portrait(id))
		return
	lines.append("La medalla solo la doy en el gimnasio, pero ¿un combate amistoso?")
	if dialog == null:
		friendly_battle(leader)
		return
	leader["busy"] = true
	dialog.open(speaker, lines, Leaders.portrait(id), ["¡Combate!", "Ahora no"], func(choice: int) -> void:
		leader["busy"] = false
		if choice == 0:
			friendly_battle(leader))


func friendly_battle(leader: Dictionary) -> bool:
	var id: String = leader["id"]
	var battle := _main.get_node_or_null("Battle") as BattleManager
	if battle == null or not battle.ready_to_fight():
		var dialog := _dialog()
		var wait_text := "Saca a tu Pokémon y peleamos."
		if dialog != null:
			dialog.open("Líder " + Leaders.name_of(id), [wait_text], Leaders.portrait(id))
		else:
			GameState.notice.emit("Líder %s: %s" % [Leaders.name_of(id), wait_text])
		return false
	var node: Node3D = leader["node"]
	var region := Regions.index()
	var team := Leaders.gym_team(id, region, Regions.badges())
	var info := {"id": "friendly:" + id, "name": "Líder " + Leaders.name_of(id), "team": team,
			"money": FRIENDLY_MONEY * (region + 1), "item": "", "smart": true, "heals": 1,
			"at": node.global_position + (_player.global_position - node.global_position).normalized() * 3.0, "node": node}
	leader["busy"] = true
	info["on_end"] = func(_result: String) -> void:
		leader["busy"] = false
		GameState.world_flags["leader_friendly:" + id] = GameState.game_day()
	if not battle.start_trainer(info):
		leader["busy"] = false
		return false
	return true


func active_leaders() -> Array:
	return _active.values()
