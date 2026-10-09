class_name WildSpawner
extends Node3D
## Hace aparecer Pokémon salvajes cerca del jugador en cualquier lugar transitable
## (pradera, entre árboles y rocas, hierba alta), en la orilla del agua (tipo Agua
## que no nada) o dentro del agua (nadadores).
## - El mundo se divide en zonas de ZONE_SIZE m con un cupo de grupos según su
##   hábitat, para no saturar un solo lugar; cada zona tiene 2 especies
##   características que aparecen más ahí.
## - La especie se sortea por su peso de rareza (etapa × poder); 2 % de shiny.
## - 30 % de las apariciones son manadas de 3 a 6 de la misma línea evolutiva
##   (casi todos básicos y rara vez un líder evolucionado). Nunca dos manadas a
##   menos de PACK_SPACING m, salvo con 5 % de probabilidad (y entonces pueden pelear).

signal wild_contact(actor: PokemonActor)

const WILD_GROUP := &"wild_pokemon"
const ACTOR_SCENE := preload("res://world/actors/pokemon_actor.tscn")
const ALL_SPECIES := preload("res://creatures/data/all_species.tres")
const SHINY_CHANCE := 0.02
const ZONE_SIZE := 40.0
## Grupos (un solitario o una manada) que caben en cada zona según su hábitat.
const ZONE_QUOTA := {
	SpeciesData.Habitat.MEADOW: 3, SpeciesData.Habitat.FOREST: 4, SpeciesData.Habitat.MOUNTAIN: 2,
	SpeciesData.Habitat.FRESHWATER: 2, SpeciesData.Habitat.SEA: 2, SpeciesData.Habitat.SWAMP: 3,
}
const FEATURED_PER_ZONE := 2
## Proporción de apariciones de una zona que son de sus especies características.
const FEATURED_SHARE := 0.35
const PACK_CHANCE := 0.3
const PACK_SIZE_MIN := 3
const PACK_SIZE_MAX := 6
## Probabilidad de que una manada tenga líder evolucionado.
const PACK_LEADER_CHANCE := 0.25
const PACK_SPACING := 60.0
## Probabilidad de permitir una manada cerca de otra (manadas rivales).
const RIVAL_PACK_CHANCE := 0.05
const RIVAL_PACK_MIN_DISTANCE := 15.0
## Profundidad (terreno sobre el agua negativo) a partir de la cual ya no es tierra firme.
const DEEP_WATER_LIMIT := -0.2

@export var world_path: NodePath
@export var player_path: NodePath
@export var navigation_path: NodePath
## Máximo de Pokémon salvajes vivos alrededor del jugador (miembros de manadas incluidos).
@export var max_alive: int = 24
@export var spawn_interval: float = 1.0
## Aparecen entre estas distancias del jugador (para no surgir en su cara ni muy lejos).
@export var min_spawn_distance: float = 15.0
@export var max_spawn_distance: float = 70.0
@export var despawn_distance: float = 100.0

var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0
var _active := false
var _next_group_id: int = 0
## Por hábitat: especies que pueden aparecer y sus pesos acumulados.
var _by_habitat := {}
## Especies de cada línea evolutiva, ordenadas por etapa.
var _by_chain := {}
## Especies características de cada zona (Vector2i -> Array[SpeciesData]).
var _featured := {}

@onready var _world: WorldBuilder = get_node(world_path)
@onready var _player: Node3D = get_node(player_path)
@onready var _navigation: WorldNavigation = get_node(navigation_path)


func _ready() -> void:
	_rng.randomize()
	_index_species()
	if _navigation.is_baked:
		_active = true
	else:
		_navigation.baked.connect(func() -> void: _active = true)


func _index_species() -> void:
	for habitat in SpeciesData.Habitat.values():
		_by_habitat[habitat] = {"species": [] as Array[SpeciesData], "cumulative": PackedFloat32Array()}
	for species: SpeciesData in ALL_SPECIES.species:
		if not _by_chain.has(species.evolution_chain):
			_by_chain[species.evolution_chain] = [] as Array[SpeciesData]
		(_by_chain[species.evolution_chain] as Array[SpeciesData]).append(species)
		if species.spawn_weight <= 0.0:
			continue
		for habitat in species.habitats:
			var entry: Dictionary = _by_habitat[habitat]
			var cumulative: PackedFloat32Array = entry.cumulative
			var total: float = cumulative[-1] if cumulative.size() > 0 else 0.0
			(entry.species as Array[SpeciesData]).append(species)
			cumulative.append(total + species.spawn_weight)
			# Los Packed*Array se copian al asignarse: hay que guardarlo de vuelta.
			entry.cumulative = cumulative
	for chain: int in _by_chain:
		(_by_chain[chain] as Array[SpeciesData]).sort_custom(func(a: SpeciesData, b: SpeciesData) -> bool:
			return a.evolution_stage < b.evolution_stage)


func zone_of(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / ZONE_SIZE), floori(point.z / ZONE_SIZE))


## Cupo de grupos de la zona según el hábitat de su centro.
func zone_quota(zone: Vector2i) -> int:
	var center := (Vector2(zone) + Vector2(0.5, 0.5)) * ZONE_SIZE
	return ZONE_QUOTA[_world.habitat_at(center.x, center.y)]


## Grupos vivos por zona (una manada cuenta como un grupo).
func groups_per_zone() -> Dictionary:
	var groups := {}
	for node in get_tree().get_nodes_in_group(WILD_GROUP):
		var actor := node as PokemonActor
		var zone := zone_of(actor.home)
		if not groups.has(zone):
			groups[zone] = {}
		(groups[zone] as Dictionary)[actor.group_id if actor.group_id >= 0 else -actor.get_instance_id()] = true
	var counts := {}
	for zone: Vector2i in groups:
		counts[zone] = (groups[zone] as Dictionary).size()
	return counts


## Especies características de una zona (fijas por semilla del mundo).
func featured_species(zone: Vector2i, habitat: SpeciesData.Habitat) -> Array[SpeciesData]:
	var key := Vector3i(zone.x, zone.y, habitat)
	if _featured.has(key):
		return _featured[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ _world.config.seed
	var picked: Array[SpeciesData] = []
	for i in FEATURED_PER_ZONE:
		var species := _weighted_pick(habitat, rng)
		if species != null and not picked.has(species) and species.spawn_weight >= 0.05:
			picked.append(species)
	_featured[key] = picked
	return picked


## Sortea una especie del hábitat. water_mode: 0 tierra, 1 orilla, 2 agua (nadadores).
## Una parte (FEATURED_SHARE) de las apariciones son las características de la zona.
func pick_species(habitat: SpeciesData.Habitat, water_mode: int, zone: Vector2i = Vector2i(9999, 9999)) -> SpeciesData:
	var featured: Array[SpeciesData] = []
	if zone != Vector2i(9999, 9999):
		featured = featured_species(zone, habitat)
	for attempt in 16:
		var species: SpeciesData
		if not featured.is_empty() and _rng.randf() < FEATURED_SHARE:
			species = featured[_rng.randi() % featured.size()]
		else:
			species = _weighted_pick(habitat, _rng)
		if species == null:
			return null
		var is_water_type := species.types.has(PokemonTypes.Type.WATER)
		if water_mode == 2 and not species.swims:
			continue
		if water_mode == 1 and (species.swims or not is_water_type):
			continue
		if water_mode == 0 and is_water_type:
			continue
		return species
	return null


func _weighted_pick(habitat: SpeciesData.Habitat, rng: RandomNumberGenerator) -> SpeciesData:
	var entry: Dictionary = _by_habitat[habitat]
	var cumulative: PackedFloat32Array = entry.cumulative
	var candidates: Array[SpeciesData] = entry.species
	if cumulative.is_empty():
		return null
	var roll: float = rng.randf() * cumulative[-1]
	var index: int = cumulative.bsearch(roll)
	return candidates[mini(index, candidates.size() - 1)]


func _process(delta: float) -> void:
	if not _active:
		return
	for node in get_tree().get_nodes_in_group(WILD_GROUP):
		var actor := node as PokemonActor
		if actor.global_position.distance_to(_player.global_position) > despawn_distance:
			actor.queue_free()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = spawn_interval
	if get_tree().get_nodes_in_group(WILD_GROUP).size() < max_alive:
		spawn_one()


## Hace aparecer un solitario o una manada cerca del jugador. Devuelve el primero
## creado (el líder si es manada), o null si no encontró sitio.
func spawn_one() -> PokemonActor:
	var counts := groups_per_zone()
	for attempt in 8:
		var angle := _rng.randf() * TAU
		var distance := _rng.randf_range(min_spawn_distance, max_spawn_distance)
		var point := _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		var half := _world.config.size * 0.5 - 8.0
		if absf(point.x) > half or absf(point.z) > half:
			continue
		var zone := zone_of(point)
		if counts.get(zone, 0) >= zone_quota(zone):
			continue
		var depth := _world.water_depth_at(point.x, point.z)
		var water_mode := 0
		if depth > 0.8:
			water_mode = 2
			point.y = _world.water_level_at(point.x, point.z)
		elif depth > DEEP_WATER_LIMIT:
			continue
		else:
			point = _snap_to_walkable(point)
			if point == Vector3.INF:
				continue
			# Junto al agua: mitad de las veces sale uno de tipo Agua en la orilla.
			if _world.random_water_point(_rng, point, 6.0, true) != Vector3.INF and _rng.randf() < 0.5:
				water_mode = 1
		var habitat := _world.habitat_at(point.x, point.z)
		var species := pick_species(habitat, water_mode, zone)
		if species == null:
			continue
		if water_mode != 2 and _rng.randf() < PACK_CHANCE and _pack_allowed(point):
			return _spawn_pack(species, point, habitat)
		return spawn_species(species, point, _rng.randf() < SHINY_CHANCE, water_mode == 2)
	return null



## Punto transitable más cercano según la navegación (fuera de árboles y rocas).
func _snap_to_walkable(point: Vector3) -> Vector3:
	point.y = _world.surface_height_at(point.x, point.z)
	var map := _navigation.get_navigation_map()
	var snapped := NavigationServer3D.map_get_closest_point(map, point)
	if Vector2(snapped.x, snapped.z).distance_to(Vector2(point.x, point.z)) > 2.0:
		return Vector3.INF
	# El ajuste puede caer en la orilla mojada: solo se acepta tierra firme.
	if _world.water_depth_at(snapped.x, snapped.z) > DEEP_WATER_LIMIT:
		return Vector3.INF
	snapped.y = _world.surface_height_at(snapped.x, snapped.z)
	return snapped


func _pack_allowed(point: Vector3) -> bool:
	var nearest := INF
	for node in get_tree().get_nodes_in_group(WILD_GROUP):
		var actor := node as PokemonActor
		if actor.group_id >= 0:
			nearest = minf(nearest, actor.global_position.distance_to(point))
	if nearest >= PACK_SPACING:
		return true
	return nearest >= RIVAL_PACK_MIN_DISTANCE and _rng.randf() < RIVAL_PACK_CHANCE


## Manada de la línea evolutiva de species: casi todos en etapa básica y, rara vez,
## un líder evolucionado (o species misma si ya está evolucionada). Solo entran
## especies de la línea que viven en este hábitat (p. ej. no Marill en la pradera).
func _spawn_pack(species: SpeciesData, point: Vector3, habitat: SpeciesData.Habitat = -1) -> PokemonActor:
	var line: Array[SpeciesData] = (_by_chain.get(species.evolution_chain, [species]) as Array[SpeciesData]).filter(
			func(s: SpeciesData) -> bool: return s.spawn_weight > 0.0 and (habitat < 0 or s.habitats.has(habitat)))
	if line.is_empty():
		line = [species]
	var lowest_stage: int = line.map(func(s: SpeciesData) -> int: return s.evolution_stage).min()
	var basics := line.filter(func(s: SpeciesData) -> bool: return s.evolution_stage == lowest_stage)
	var basic: SpeciesData = species if basics.has(species) else basics[0]
	var leader_species := basic
	if species.evolution_stage > lowest_stage:
		leader_species = species
	elif _rng.randf() < PACK_LEADER_CHANCE:
		var evolved := line.filter(func(s: SpeciesData) -> bool: return s.evolution_stage > lowest_stage)
		if not evolved.is_empty():
			leader_species = evolved[_rng.randi() % evolved.size()]
	var group := _next_group_id
	_next_group_id += 1
	var leader := spawn_species(leader_species, point, _rng.randf() < SHINY_CHANCE, false)
	leader.group_id = group
	var count := _rng.randi_range(PACK_SIZE_MIN, PACK_SIZE_MAX) - 1
	for i in count:
		var angle := TAU * i / count + _rng.randf_range(-0.3, 0.3)
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(1.8, 3.2) * maxf(1.0, basic.size_scale)
		var member_point := _snap_to_walkable(point + offset)
		if member_point == Vector3.INF:
			continue
		var member := spawn_species(basic, member_point, _rng.randf() < SHINY_CHANCE, false)
		member.group_id = group
		member.leader = leader
		member.pack_offset = offset
	return leader


## Crea un salvaje de la especie dada en el punto (lo usan también las pruebas).
func spawn_species(species: SpeciesData, point: Vector3, shiny: bool, swimming: bool, legendary := false) -> PokemonActor:
	var actor := ACTOR_SCENE.instantiate() as PokemonActor
	actor.species = species
	actor.legendary = legendary
	actor.role = PokemonActor.Role.WILD
	actor.shiny = shiny
	actor.swimming = swimming
	actor.world = _world
	actor.player = _player
	actor.position = point + (Vector3.ZERO if swimming else Vector3.UP * 0.3)
	actor.add_to_group(LegendaryManager.LEGENDARY_GROUP if legendary else WILD_GROUP)
	actor.contact_with_player.connect(func(a: PokemonActor) -> void: wild_contact.emit(a))
	add_child(actor)
	return actor
