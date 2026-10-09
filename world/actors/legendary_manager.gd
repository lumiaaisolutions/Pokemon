class_name LegendaryManager
extends Node3D
## Cada legendario y singular tiene un lugar fijo del mundo en una zona acorde a su
## tipo (hábitat). Aparece uno solo, moviéndose en su territorio, cuando el jugador
## se acerca, y se retira cuando se aleja. Si ya fue capturado, solo vuelve con la
## tirada del 2 % de GameState.

const LEGENDARY_GROUP := &"legendary_pokemon"
const ALL_SPECIES := preload("res://creatures/data/all_species.tres")

@export var world_path: NodePath
@export var spawner_path: NodePath
@export var player_path: NodePath
@export var appear_distance: float = 80.0
@export var vanish_distance: float = 110.0
## Separación mínima entre lugares de legendarios y respecto al inicio.
@export var min_spacing: float = 22.0
@export var spawn_clear_radius: float = 45.0

## identifier -> posición del lugar.
var spots := {}
var _species_by_id := {}
var _active := {}

@onready var _world: WorldBuilder = get_node(world_path)
@onready var _spawner: WildSpawner = get_node(spawner_path)
@onready var _player: Node3D = get_node(player_path)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _world.config.seed + 97
	var placed: Array[Vector3] = []
	for species: SpeciesData in ALL_SPECIES.species:
		if not (species.is_legendary or species.is_mythical):
			continue
		var spot := _find_spot(species, rng, placed)
		if spot == Vector3.INF:
			push_warning("Sin lugar para el legendario %s" % species.identifier)
			continue
		placed.append(spot)
		spots[species.identifier] = spot
		_species_by_id[species.identifier] = species


func _find_spot(species: SpeciesData, rng: RandomNumberGenerator, placed: Array[Vector3]) -> Vector3:
	var half := _world.config.size * 0.5 - 12.0
	for attempt in 600:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if Vector2(x, z).length() < spawn_clear_radius:
			continue
		if not species.habitats.has(_world.habitat_at(x, z)):
			continue
		if _world.water_depth_at(x, z) > -0.3:
			continue
		var point := Vector3(x, _world.surface_height_at(x, z), z)
		var too_close := false
		for other in placed:
			if other.distance_to(point) < min_spacing:
				too_close = true
				break
		if not too_close:
			return point
	return Vector3.INF


func _process(_delta: float) -> void:
	for identifier: String in spots:
		var spot: Vector3 = spots[identifier]
		var distance := spot.distance_to(_player.global_position)
		var actor: PokemonActor = _active.get(identifier)
		if actor != null and not is_instance_valid(actor):
			_active.erase(identifier)
			actor = null
		if actor == null and distance < appear_distance and GameState.is_legendary_available(identifier):
			actor = _spawner.spawn_species(_species_by_id[identifier], spot, false, false)
			actor.remove_from_group(WildSpawner.WILD_GROUP)
			actor.add_to_group(LEGENDARY_GROUP)
			_active[identifier] = actor
		elif actor != null and distance > vanish_distance:
			actor.queue_free()
			_active.erase(identifier)
