class_name BossManager
extends Node3D
## Guardianes de bioma (Fase 6, 2026-10-11, ver docs/sistemas/jefes.md y la decisión de
## Fernando en plan_pulido_mundo.md): al cargar la región se busca, para cada bioma
## presente (menos el mar), el punto de ese bioma más alejado de los pueblos (su "zona
## más difícil") y ahí vive un guardián (Bosses.guardian_species) hasta que lo vencen.
## Es enorme (Bosses.size_scale) y fuerte (Bosses.hp_scale), con aura de su tipo; en
## combate tiene 2 cambios de fase (66 % y 33 % de vida: invoca ayudantes y ataca más
## seguido) y lanza ataques en área telegrafiados (círculo o línea en el suelo, igual
## que PokemonActor._telegraph pero más grandes) que no hacen daño si el compañero sale
## de la zona antes de que se resuelvan. Al caer da su premio único y queda registrado
## por región (Bosses._flags, dentro de GameState.world_flags, que ya es por región).

signal guardian_appeared(biome: int, species: SpeciesData)
signal guardian_defeated(biome: int, species: SpeciesData)

## Qué tan cerca hay que estar de la guarida para que el guardián aparezca.
const DISCOVER_RADIUS := 90.0
## Paso de la rejilla con que se busca el punto más alejado de cada bioma (4096 m / 160).
const GRID_STEP := 160.0

@export var world_path: NodePath
@export var player_path: NodePath
@export var spawner_path: NodePath

var _world: WorldBuilder
var _player: Node3D
var _spawner: WildSpawner
var _rng := RandomNumberGenerator.new()
## Bioma -> Vector3 (posición de su guarida en la región actual).
var _lairs: Dictionary = {}
## Bioma -> PokemonActor (el guardián ya creado, si está vivo).
var _guardians: Dictionary = {}
## Combate de jefe en curso: {actor, biome, phase, aoe_timer, aoe_pending}.
var _fight: Dictionary = {}
var _lairs_region := -1


func _ready() -> void:
	add_to_group(&"bosses")
	_rng.randomize()
	_world = get_node(world_path) as WorldBuilder
	_player = get_node(player_path) as Node3D
	_spawner = get_node(spawner_path) as WildSpawner
	_build_lairs()
	var battle := _battle()
	if battle != null:
		battle.started.connect(_on_battle_started)


func _battle() -> BattleManager:
	return get_parent().get_node_or_null("Battle") as BattleManager


## Para cada bioma presente (sin el mar), el punto más alejado de cualquier pueblo.
func _build_lairs() -> void:
	_lairs.clear()
	_lairs_region = Regions.index()
	var layout := _world.layout
	var half := layout.size * 0.5
	var farthest := {}
	var x := -half + GRID_STEP * 0.5
	while x < half:
		var z := -half + GRID_STEP * 0.5
		while z < half:
			var biome := int(layout.biome_at(x, z))
			if not (Bosses.NO_GUARDIAN as Array).has(biome):
				var dist := _distance_to_settlement(layout, x, z)
				var current: Dictionary = farthest.get(biome, {"dist": -1.0})
				if dist > float(current["dist"]):
					farthest[biome] = {"dist": dist, "x": x, "z": z}
			z += GRID_STEP
		x += GRID_STEP
	for biome: int in farthest:
		var info: Dictionary = farthest[biome]
		_lairs[biome] = Vector3(float(info["x"]), 0.0, float(info["z"]))


static func _distance_to_settlement(layout: RegionLayout, x: float, z: float) -> float:
	var best := 1.0e9
	for s: Dictionary in layout.settlements:
		best = minf(best, Vector2(x - float(s["x"]), z - float(s["z"])).length())
	return best


func _process(delta: float) -> void:
	if Regions.index() != _lairs_region:
		_build_lairs()
		_guardians.clear()
		_fight = {}
	_update_lair_spawns()
	if not _fight.is_empty():
		_update_fight(delta)


## Si el jugador se acerca a la guarida de un bioma sin guardián vivo ni vencido, aparece.
func _update_lair_spawns() -> void:
	if _player == null or _player.global_position.x > WorldBuilder.INTERIOR_X:
		return
	for biome: int in _lairs.keys():
		if Bosses.is_defeated(biome):
			continue
		var actor: PokemonActor = _guardians.get(biome)
		if actor != null and not is_instance_valid(actor):
			_guardians.erase(biome)
			actor = null
		if actor != null:
			continue
		var center: Vector3 = _lairs[biome]
		if _player.global_position.distance_to(center) > DISCOVER_RADIUS:
			continue
		if not _world.is_near_loaded(center):
			continue
		_spawn_guardian(biome, center)


func _spawn_guardian(biome: int, center: Vector3) -> PokemonActor:
	var region := Regions.index()
	var seed_value: int = hash([int(Regions.current().get("seed", 0)), biome])
	var excluded: Array[String] = []
	for other: PokemonActor in _guardians.values():
		if is_instance_valid(other):
			excluded.append(other.species.identifier)
	var species := Bosses.guardian_species(biome, seed_value, excluded)
	if species == null:
		return null
	var spot := Vector3(center.x, _world.surface_height_at(center.x, center.z), center.z)
	var actor := _spawner.spawn_species(species, spot, false, false, false, Bosses.size_scale(region))
	if actor == null:
		return null
	actor.hp_max *= Bosses.hp_scale(region)
	actor._heal_to(1.0)
	actor.set_meta("guardian", true)
	actor.set_meta("guardian_biome", biome)
	var aura := OmniLight3D.new()
	aura.light_color = Bosses.AURA_COLOR.get(int(species.types[0]), Color(1.0, 0.65, 0.15))
	aura.omni_range = 6.0
	aura.light_energy = 1.8
	aura.position.y = 1.2
	actor.add_child(aura)
	_guardians[biome] = actor
	actor.stunned.connect(_on_guardian_stunned.bind(biome), CONNECT_ONE_SHOT)
	var biome_name: String = RegionLayout.BIOME_NAMES[biome]
	GameState.add_news("Rotom: ¡sientes una presencia enorme en el bioma %s! Un guardián vigila la zona." % biome_name)
	GameState.notice.emit("¡Un %s guardián de %s te vigila! Cuidado con sus ataques en área." % [species.display_name, biome_name])
	guardian_appeared.emit(biome, species)
	return actor


func _on_guardian_stunned(actor: PokemonActor, biome: int) -> void:
	_fight = {}
	Bosses.mark_defeated(biome)
	var region := Regions.index()
	var biome_name: String = RegionLayout.BIOME_NAMES[biome]
	GameState.add_money(Bosses.reward_money(region), "Guardián de %s" % biome_name)
	var items := Bosses.reward_items(biome)
	for item: String in items:
		GameState.add_item(item, 1)
	GameState.add_news("¡%s venció al guardián de %s!" % [GameState.player_name, biome_name.to_lower()])
	GameState.notice.emit("¡Venciste al guardián de %s! Premio: %s y %s." % [biome_name, Items.display_name(items[0]), Items.display_name(items[1])])
	Achievements.add("guardians")
	guardian_defeated.emit(biome, actor.species if is_instance_valid(actor) else null)
	_guardians.erase(biome)


# --- Combate de jefe: fases y ataques en área -------------------------------------------

func _on_battle_started(opponent: PokemonActor) -> void:
	if opponent != null and is_instance_valid(opponent) and opponent.has_meta("guardian"):
		_fight = {"actor": opponent, "biome": int(opponent.get_meta("guardian_biome")), "phase": 1,
				"aoe_timer": Bosses.phase_interval(1), "aoe_pending": false}


func _update_fight(delta: float) -> void:
	var actor: PokemonActor = _fight.get("actor")
	var battle := _battle()
	if actor == null or not is_instance_valid(actor) or battle == null or not battle.active or battle.opponent != actor:
		_fight = {}
		return
	var ratio := actor.hp / actor.hp_max
	var phase: int = _fight["phase"]
	if phase < 2 and ratio <= Bosses.PHASE_THRESHOLDS[0]:
		_advance_phase(2)
	elif phase < 3 and ratio <= Bosses.PHASE_THRESHOLDS[1]:
		_advance_phase(3)
	if _fight.get("aoe_pending", false):
		return
	_fight["aoe_timer"] = float(_fight["aoe_timer"]) - delta
	if float(_fight["aoe_timer"]) <= 0.0:
		_fight["aoe_timer"] = Bosses.phase_interval(int(_fight["phase"]))
		launch_aoe(actor)


func _advance_phase(phase: int) -> void:
	_fight["phase"] = phase
	var actor: PokemonActor = _fight["actor"]
	if actor == null or not is_instance_valid(actor):
		return
	GameState.notice.emit("¡%s cambia de fase! Se vuelve más rápido%s." % [actor.species.display_name, " e invoca ayudantes" if phase >= 2 else ""])
	_summon_helpers(actor, phase - 1)


## Invoca a 1 o 2 Pokémon del mismo bioma como ayudantes (se suman a la horda del combate).
func _summon_helpers(actor: PokemonActor, count: int) -> void:
	var battle := _battle()
	if battle == null or not battle.active or _spawner == null:
		return
	var companion := battle.companion()
	for i in count:
		var habitat := _world.habitat_at(actor.global_position.x, actor.global_position.z)
		var helper_species := _spawner.pick_species(habitat, 0)
		if helper_species == null:
			continue
		var angle := _rng.randf() * TAU
		var spot := actor.global_position + Vector3(cos(angle), 0, sin(angle)) * 3.5
		var helper := _spawner.spawn_species(helper_species, spot, false, false, false, 1.0)
		if helper == null:
			continue
		helper.battle_center = battle.center
		helper.battle_radius = BattleManager.ARENA_RADIUS - 0.5
		battle.horde.append(helper)
		if companion != null and is_instance_valid(companion):
			helper.start_fight(companion)
	battle.horde_size = maxi(battle.horde_size, battle.horde.size() + 1)


## Lanza un ataque en área (círculo bajo el compañero, o línea desde el guardián) que se
## telegrafía y, al cumplirse, solo daña a quien se haya quedado dentro. force_shape:
## "circle" o "line" para pruebas; "" elige al azar según la fase.
func launch_aoe(actor: PokemonActor, force_shape: String = "") -> void:
	var battle := _battle()
	if battle == null:
		return
	var companion := battle.companion()
	if companion == null or not is_instance_valid(companion):
		return
	_fight["aoe_pending"] = true
	var phase: int = int(_fight.get("phase", 1))
	var radius := Bosses.phase_radius(phase)
	var duration := maxf(1.7 - phase * 0.15, 1.1)
	var shape := force_shape if force_shape != "" else ("line" if phase >= 3 and _rng.randf() < 0.5 else "circle")
	var center := companion.global_position
	var line_to := Vector3.ZERO
	if shape == "circle":
		actor.telegraph_zone(center, radius, duration)
	else:
		var dir := center - actor.global_position
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
		line_to = actor.global_position + dir * (radius * 2.6)
		actor.telegraph_line(actor.global_position, line_to, radius * 0.9, duration)
	await actor.get_tree().create_timer(duration).timeout
	_fight["aoe_pending"] = false
	if not is_instance_valid(actor) or not is_instance_valid(companion):
		return
	var hit := Bosses.circle_hit(companion.global_position, center, radius) if shape == "circle" \
			else Bosses.segment_hit(companion.global_position, actor.global_position, line_to, radius * 0.9)
	if hit:
		companion.receive_hit(companion.hp_max * (0.14 + phase * 0.05), actor)
		GameState.notice.emit("¡El ataque en área golpeó a %s!" % companion.species.display_name)
	else:
		GameState.notice.emit("¡%s esquivó el ataque en área del guardián!" % companion.species.display_name)


## Para la Brújula de objetivos del Rotom: una entrada por bioma con guardián.
func guardian_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var biomes: Array = _lairs.keys()
	biomes.sort()
	for biome: int in biomes:
		var center: Vector3 = _lairs[biome]
		result.append({"biome": biome, "x": center.x, "z": center.z, "defeated": Bosses.is_defeated(biome),
				"label": "Guardián de %s" % RegionLayout.BIOME_NAMES[biome]})
	return result
