class_name WildSpawner
extends Node3D
## Hace aparecer Pokémon salvajes visibles dentro de la hierba alta según la tabla
## de encuentros del bioma, y los retira cuando quedan lejos del jugador.

signal wild_contact(actor: PokemonActor)

const WILD_GROUP := &"wild_pokemon"
const ACTOR_SCENE := preload("res://world/actors/pokemon_actor.tscn")

@export var encounters: EncounterTable
@export var biome_path: NodePath
@export var player_path: NodePath
@export var navigation_path: NodePath
@export var spawn_interval: float = 1.5
## No aparecen a menos de esta distancia del jugador (para no surgir en su cara).
@export var min_spawn_distance: float = 10.0
@export var despawn_distance: float = 90.0

var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0
var _active := false

@onready var _biome: BiomeBuilder = get_node(biome_path)
@onready var _player: Node3D = get_node(player_path)


func _ready() -> void:
	_rng.randomize()
	var navigation := get_node(navigation_path) as WorldNavigation
	if navigation.is_baked:
		_active = true
	else:
		navigation.baked.connect(func() -> void: _active = true)


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
	if get_tree().get_nodes_in_group(WILD_GROUP).size() < encounters.max_alive:
		spawn_one()


## Hace aparecer un salvaje en la hierba alta. Devuelve null si no encontró sitio.
func spawn_one() -> PokemonActor:
	for attempt in 10:
		var point := _biome.random_point_in_tall_grass(_rng)
		if point.distance_to(_player.global_position) < min_spawn_distance:
			continue
		var actor := ACTOR_SCENE.instantiate() as PokemonActor
		actor.species = encounters.pick(_rng)
		actor.role = PokemonActor.Role.WILD
		actor.player = _player
		actor.position = point + Vector3.UP * 0.3
		actor.add_to_group(WILD_GROUP)
		actor.contact_with_player.connect(func(a: PokemonActor) -> void: wild_contact.emit(a))
		add_child(actor)
		return actor
	return null
