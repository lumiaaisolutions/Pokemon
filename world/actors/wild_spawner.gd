class_name WildSpawner
extends Node3D
## Hace aparecer Pokémon salvajes cerca del jugador según el hábitat del lugar:
## en la hierba alta (pradera, bosque, montaña, pantano), en la orilla del agua
## (tipo Agua que no nada) o dentro del agua (nadadores). La especie se sortea por
## su peso de rareza (etapa × poder) y hay 2 % de probabilidad de shiny.

signal wild_contact(actor: PokemonActor)

const WILD_GROUP := &"wild_pokemon"
const ACTOR_SCENE := preload("res://world/actors/pokemon_actor.tscn")
const ALL_SPECIES := preload("res://creatures/data/all_species.tres")
const SHINY_CHANCE := 0.02

@export var world_path: NodePath
@export var player_path: NodePath
@export var navigation_path: NodePath
@export var max_alive: int = 16
@export var spawn_interval: float = 1.0
## Aparecen entre estas distancias del jugador (para no surgir en su cara ni muy lejos).
@export var min_spawn_distance: float = 12.0
@export var max_spawn_distance: float = 60.0
@export var despawn_distance: float = 90.0
## Proporción de intentos en agua u orilla frente a hierba alta.
@export_range(0.0, 1.0) var water_attempt_ratio: float = 0.3

var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0
var _active := false
## Por hábitat: especies que pueden aparecer y sus pesos acumulados.
var _by_habitat := {}

@onready var _world: WorldBuilder = get_node(world_path)
@onready var _player: Node3D = get_node(player_path)


func _ready() -> void:
	_rng.randomize()
	_index_species()
	var navigation := get_node(navigation_path) as WorldNavigation
	if navigation.is_baked:
		_active = true
	else:
		navigation.baked.connect(func() -> void: _active = true)


func _index_species() -> void:
	for habitat in SpeciesData.Habitat.values():
		_by_habitat[habitat] = {"species": [] as Array[SpeciesData], "cumulative": PackedFloat32Array()}
	for species: SpeciesData in ALL_SPECIES.species:
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


## Sortea una especie del hábitat. water_mode: 0 tierra, 1 orilla, 2 agua (nadadores).
func pick_species(habitat: SpeciesData.Habitat, water_mode: int) -> SpeciesData:
	var entry: Dictionary = _by_habitat[habitat]
	var cumulative: PackedFloat32Array = entry.cumulative
	var candidates: Array[SpeciesData] = entry.species
	if cumulative.is_empty():
		return null
	for attempt in 12:
		var roll: float = _rng.randf() * cumulative[-1]
		var index: int = cumulative.bsearch(roll)
		var species: SpeciesData = candidates[mini(index, candidates.size() - 1)]
		var is_water_type := species.types.has(PokemonTypes.Type.WATER)
		if water_mode == 2 and not species.swims:
			continue
		if water_mode == 1 and (species.swims or not is_water_type):
			continue
		if water_mode == 0 and is_water_type:
			continue
		return species
	return null


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


## Hace aparecer un salvaje cerca del jugador. Devuelve null si no encontró sitio.
func spawn_one() -> PokemonActor:
	var water_mode := 0
	var point := Vector3.INF
	if _rng.randf() < water_attempt_ratio:
		water_mode = 2 if _rng.randf() < 0.5 else 1
		point = _world.random_water_point(_rng, _player.global_position, max_spawn_distance, water_mode == 2)
	else:
		point = _world.random_point_in_tall_grass(_rng, _player.global_position, max_spawn_distance)
	if point == Vector3.INF or point.distance_to(_player.global_position) < min_spawn_distance:
		return null
	var habitat := _world.habitat_at(point.x, point.z)
	var species := pick_species(habitat, water_mode)
	if species == null:
		return null
	return spawn_species(species, point, _rng.randf() < SHINY_CHANCE, water_mode == 2)


## Crea un salvaje de la especie dada en el punto (lo usan también las pruebas).
func spawn_species(species: SpeciesData, point: Vector3, shiny: bool, swimming: bool) -> PokemonActor:
	var actor := ACTOR_SCENE.instantiate() as PokemonActor
	actor.species = species
	actor.role = PokemonActor.Role.WILD
	actor.shiny = shiny
	actor.swimming = swimming
	actor.world = _world
	actor.player = _player
	actor.position = point + (Vector3.ZERO if swimming else Vector3.UP * 0.3)
	actor.add_to_group(WILD_GROUP)
	actor.contact_with_player.connect(func(a: PokemonActor) -> void: wild_contact.emit(a))
	add_child(actor)
	return actor
