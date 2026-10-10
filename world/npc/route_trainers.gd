class_name RouteTrainers
extends Node3D
## Entrenadores en los caminos (Fase 5.6), estilo BW: cada ~SPACING m de camino, fuera
## de los pueblos, hay un entrenador parado a un lado mirando el camino. Si entras en su
## campo de visión (cono de VIEW_DISTANCE m y VIEW_ANGLE°) con tu Pokémon fuera, aparece
## "¡!", suena el aviso, camina hacia ti y empieza un combate en arena con su equipo (2–4
## Pokémon de la zona, más fuertes lejos del inicio). Al vencerlo da dinero y un objeto;
## la revancha es al día siguiente (su equipo cambia cada día). Los lugares son fijos por
## semilla; los entrenadores se crean al acercarte y se liberan al alejarte.

const SPACING := 260.0
const SIDE_OFFSET := 3.5
const SPAWN_DISTANCE := 110.0
const DESPAWN_DISTANCE := 160.0
const VIEW_DISTANCE := 13.0
const VIEW_ANGLE := 32.0
const WALK_SPEED := 3.2
const RETRY_SECONDS := 12.0
const CLASSES := {
	RegionLayout.Biome.FOREST: ["Bichero", "Dominguera"], RegionLayout.Biome.JUNGLE: ["Bichero", "Pokéfan"],
	RegionLayout.Biome.MOUNTAIN: ["Montañero", "Karateka"], RegionLayout.Biome.CANYON: ["Montañero", "Ruinamaníaco"],
	RegionLayout.Biome.DESERT: ["Ruinamaníaco", "Montañero"], RegionLayout.Biome.BEACH: ["Nadadora", "Pescador"],
	RegionLayout.Biome.SEA: ["Nadador", "Pescador"], RegionLayout.Biome.TUNDRA: ["Esquiadora", "Montañero"],
	RegionLayout.Biome.SWAMP: ["Médium", "Pescador"], RegionLayout.Biome.DARK_FOREST: ["Médium", "Bichero"],
	RegionLayout.Biome.VOLCANO: ["Karateka", "Motorista"],
}
const DEFAULT_CLASSES := ["Joven", "Chica", "Entrenador Guay", "Entrenadora Guay", "Dominguero", "Ornitólogo"]
const PRIZES := ["potion", "great-ball", "super-potion", "oran-berry", "sitrus-berry", "ultra-ball", "star-piece", "rare-candy"]
const LINES := ["¡Nuestras miradas se cruzaron! ¡A pelear!", "¡Eh, tú! ¡Quiero ver qué tan fuerte es tu Pokémon!",
		"¡Llevo todo el día esperando un rival!", "¡No pasarás sin un combate!", "¡Mi equipo está listo! ¿Y el tuyo?"]

@export var world_path: NodePath = NodePath("../World")
@export var player_path: NodePath = NodePath("../Player")

var spots: Array[Dictionary] = []
var _world: WorldBuilder
var _player: Player
var _main: Node
var _active := {}
var _check := 0.0


func _ready() -> void:
	_main = get_parent()
	_world = get_node(world_path) as WorldBuilder
	_player = get_node(player_path) as Player
	_build_spots()


## Lugares fijos (por semilla) a lo largo de los caminos.
func _build_spots() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.world_seed + 5606
	var start := _world.start_position()
	for road_index in _world.layout.roads.size():
		var road: PackedVector2Array = _world.layout.roads[road_index]
		var walked := SPACING * 0.5
		for i in range(1, road.size()):
			var a := road[i - 1]
			var b := road[i]
			var segment := a.distance_to(b)
			while walked < segment:
				var at := a.lerp(b, walked / segment)
				walked += SPACING
				var along := (b - a).normalized()
				var side := Vector2(-along.y, along.x) * (1.0 if rng.randf() < 0.5 else -1.0)
				var pos := at + side * SIDE_OFFSET
				if not _world.settlement_at(pos.x, pos.y, 45.0).is_empty() or not _world.structures.place_at(pos.x, pos.y, 25.0).is_empty():
					continue
				if not _world._dry_land(pos.x, pos.y, 2.0):
					continue
				var biome := _world.region_biome_at(pos.x, pos.y)
				var classes: Array = CLASSES.get(biome, DEFAULT_CLASSES)
				var id := "%d:%d" % [road_index, spots.size()]
				var trainer_class: String = classes[rng.randi() % classes.size()]
				var look := NpcLooks.for_class(trainer_class, rng)
				spots.append({"id": id, "name": TownNPCs.name_for(NpcLooks.gender(look), rng), "pos": pos, "facing": Vector3(-side.x, 0, -side.y),
						"class": trainer_class, "look": look, "strength": clampf(pos.distance_to(Vector2(start.x, start.z)) / 1800.0, 0.0, 1.0)})
			walked -= segment


func _process(delta: float) -> void:
	if _player == null:
		return
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_update_spawns()
	var battle := _main.get_node_or_null("Battle") as BattleManager
	for trainer: Dictionary in _active.values():
		_update_trainer(trainer, battle, delta)


func _update_spawns() -> void:
	var p := Vector2(_player.global_position.x, _player.global_position.z)
	var inside := _player.global_position.x > WorldBuilder.INTERIOR_X
	for id: String in _active.keys():
		var trainer: Dictionary = _active[id]
		if inside or (trainer["spot"]["pos"] as Vector2).distance_to(p) > DESPAWN_DISTANCE:
			_free(trainer)
	if inside:
		return
	for spot: Dictionary in spots:
		if not _active.has(spot["id"]) and (spot["pos"] as Vector2).distance_to(p) < SPAWN_DISTANCE:
			_active[spot["id"]] = _make(spot)


func _make(spot: Dictionary) -> Dictionary:
	var node := Node3D.new()
	node.name = "Trainer"
	add_child(node)
	var pos: Vector2 = spot["pos"]
	node.global_position = Vector3(pos.x, _world.surface_height_at(pos.x, pos.y), pos.y)
	var sprite := DirectionalSprite.new()
	sprite.name = "Sprite"
	sprite.step_cycle = PackedInt32Array([0, 1, 0, 2])
	sprite.walk_fps = 6.0
	node.add_child(sprite)
	sprite.setup(NpcLooks.sheet(String(spot["look"])), 3, 8, 0.057)
	sprite.facing_world = spot["facing"]
	var mark := Label3D.new()
	mark.name = "Mark"
	mark.text = "!"
	mark.font_size = 96
	mark.outline_size = 18
	mark.modulate = Color(1.0, 0.25, 0.2)
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.no_depth_test = true
	mark.position = Vector3(0, 2.6, 0)
	mark.visible = false
	node.add_child(mark)
	var trainer := {"spot": spot, "node": node, "state": "watch", "retry": 0.0}
	trainer["point"] = _world.structures.add_point(node.global_position + Vector3.UP * 0.5, "Hablar con %s %s" % [spot["class"], spot["name"]], _talk.bind(trainer), 2.4)
	return trainer


func _free(trainer: Dictionary) -> void:
	_world.structures.remove_point(trainer["point"])
	(trainer["node"] as Node).queue_free()
	_active.erase(trainer["spot"]["id"])


func beaten_today(spot: Dictionary) -> bool:
	return int(GameState.world_flags.get("trainer_beaten:" + String(spot["id"]), -1)) == GameState.game_day()


func _update_trainer(trainer: Dictionary, battle: BattleManager, delta: float) -> void:
	var node: Node3D = trainer["node"]
	var sprite := node.get_node("Sprite") as DirectionalSprite
	var spot: Dictionary = trainer["spot"]
	trainer["retry"] = maxf(float(trainer["retry"]) - delta, 0.0)
	var velocity := Vector3.ZERO
	match String(trainer["state"]):
		"watch":
			sprite.facing_world = spot["facing"]
			if BattleManager.enabled and battle != null and not battle.active and float(trainer["retry"]) <= 0.0 and not beaten_today(spot) and sees_player(trainer):
				_spotted(trainer)
		"approach":
			var to := _player.global_position - node.global_position
			to.y = 0.0
			if to.length() > 2.6:
				velocity = to.normalized() * WALK_SPEED
				node.global_position += velocity * delta
				node.global_position.y = TownNPCs.swim_height(_world, node)
			else:
				_challenge(trainer)
		"battle":
			sprite.look_at_point(_player.global_position)
		"return":
			var home := Vector3((spot["pos"] as Vector2).x, node.global_position.y, (spot["pos"] as Vector2).y)
			var back := home - node.global_position
			back.y = 0.0
			if back.length() > 0.3:
				velocity = back.normalized() * WALK_SPEED * 0.7
				node.global_position += velocity * delta
				node.global_position.y = TownNPCs.swim_height(_world, node)
			else:
				trainer["state"] = "watch"
	sprite.animate(velocity, delta)
	(trainer["point"] as Dictionary)["pos"] = node.global_position + Vector3.UP * 0.5


## ¿El jugador está en su cono de visión, sin nada que tape?
func sees_player(trainer: Dictionary) -> bool:
	if _player.mode != Player.Mode.WALK:
		return false
	var node: Node3D = trainer["node"]
	var to := _player.global_position - node.global_position
	to.y = 0.0
	if to.length() > VIEW_DISTANCE or to.length() < 0.1:
		return false
	var facing: Vector3 = trainer["spot"]["facing"]
	if rad_to_deg(facing.angle_to(to.normalized())) > VIEW_ANGLE:
		return false
	var query := PhysicsRayQueryParameters3D.create(node.global_position + Vector3.UP * 1.2, _player.global_position + Vector3.UP * 1.0, 2)
	return node.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _spotted(trainer: Dictionary) -> void:
	trainer["state"] = "approach"
	var mark := (trainer["node"] as Node3D).get_node("Mark") as Label3D
	mark.visible = true
	var tween := create_tween()
	tween.tween_property(mark, "position:y", 3.0, 0.12)
	tween.tween_property(mark, "position:y", 2.6, 0.12)
	AudioBus.play_sfx("spotted")
	AudioBus.play_jingle("bw1_spotted")


func _talk(trainer: Dictionary) -> void:
	var spot: Dictionary = trainer["spot"]
	if beaten_today(spot):
		GameState.notice.emit("%s %s: ¡Qué buen combate! Mañana quiero la revancha." % [spot["class"], spot["name"]])
		return
	if trainer["state"] == "watch":
		_spotted(trainer)


## Arma su equipo del día y empieza el combate en arena.
func _challenge(trainer: Dictionary) -> void:
	var spot: Dictionary = trainer["spot"]
	var node: Node3D = trainer["node"]
	var battle := _main.get_node_or_null("Battle") as BattleManager
	(node.get_node("Mark") as Label3D).visible = false
	if battle == null or not battle.ready_to_fight():
		GameState.notice.emit("%s %s: ¡Saca a tu Pokémon y peleamos!" % [spot["class"], spot["name"]])
		trainer["state"] = "return"
		trainer["retry"] = RETRY_SECONDS
		return
	var info := team_for(spot)
	info["at"] = node.global_position + (_player.global_position - node.global_position).normalized() * 3.0
	info["on_end"] = func(result: String) -> void:
		if not is_instance_valid(node):
			return
		trainer["state"] = "return"
		trainer["retry"] = RETRY_SECONDS
		if result == "trainer_win":
			GameState.notice.emit("%s %s: ¡Increíble! Mañana quiero la revancha." % [spot["class"], spot["name"]])
	GameState.notice.emit("%s %s: %s" % [spot["class"], spot["name"], LINES[absi(hash(spot["id"])) % LINES.size()]])
	if battle.start_trainer(info):
		trainer["state"] = "battle"
	else:
		trainer["state"] = "return"
		trainer["retry"] = RETRY_SECONDS


## Equipo, dinero y premio del día (cambian cada día: revancha distinta).
func team_for(spot: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d" % [spot["id"], GameState.game_day(), GameState.world_seed])
	var spawner := _main.get_node("Spawner") as WildSpawner
	var pos: Vector2 = spot["pos"]
	var strength: float = spot["strength"]
	var size := clampi(2 + int(strength * 2.0 + rng.randf() * 0.8), 2, 4)
	var team: Array[SpeciesData] = []
	for i in size * 3:
		if team.size() >= size:
			break
		var species := spawner.pick_species(_world.habitat_at(pos.x + rng.randf_range(-40, 40), pos.y + rng.randf_range(-40, 40)), 0)
		if species == null or species.is_legendary or species.is_mythical:
			continue
		# Lejos del inicio prefieren Pokémon evolucionados.
		if species.evolution_stage < 2 and rng.randf() < strength * 0.7:
			var options := Evolution.options(species.identifier)
			if not options.is_empty():
				var evolved := MenuStyle.species(options[0]["to"])
				if evolved != null:
					species = evolved
		team.append(species)
	var prize: String = PRIZES[mini(int(strength * PRIZES.size() + rng.randf() * 2.0), PRIZES.size() - 1)]
	return {"id": spot["id"], "name": "%s %s" % [spot["class"], spot["name"]], "team": team,
			"money": int(300 * size * (1.0 + strength * 2.0)), "item": prize}


func active_trainers() -> Array:
	return _active.values()
