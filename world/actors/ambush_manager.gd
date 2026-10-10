class_name AmbushManager
extends Node3D
## Emboscadas desde los árboles: cuelga Pokémon Bicho de las ramas y posa aves en
## las copas de árboles cercanos al jugador (bosque y pradera). Los agresivos y
## territoriales caen o se lanzan en picada al pasar debajo (ver PokemonActor.perch_on).

@export var world_path: NodePath
@export var spawner_path: NodePath
@export var player_path: NodePath
@export var max_ambushers: int = 3
@export var scan_interval: float = 2.5
@export var min_distance: float = 18.0
@export var max_distance: float = 40.0
## Proporción de Bichos colgados frente a aves posadas.
@export_range(0.0, 1.0) var bug_ratio: float = 0.55

const AMBUSH_GROUP := &"ambushers"
const TREE_PREFIXES := ["Tree", "EdgeTree", "ShoreTree"]

var _trees: Array[Node3D] = []
var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var _world: WorldBuilder = get_node(world_path)
@onready var _spawner: WildSpawner = get_node(spawner_path)
@onready var _player: Node3D = get_node(player_path)


func _ready() -> void:
	_rng.randomize()
	for body in _world.find_children("*", "StaticBody3D", true, false):
		for prefix: String in TREE_PREFIXES:
			if body.name.begins_with(prefix):
				_trees.append(body as Node3D)
				break


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = scan_interval
	var ambushers := get_tree().get_nodes_in_group(AMBUSH_GROUP).filter(func(a: Node) -> bool: return (a as PokemonActor).perched)
	if ambushers.size() >= max_ambushers:
		return
	spawn_one()


## Cuelga o posa un emboscador en un árbol cercano. Devuelve null si no encontró.
func spawn_one() -> PokemonActor:
	var tree := _pick_tree()
	if tree == null:
		return null
	var as_bird := _rng.randf() >= bug_ratio
	var habitat := _world.habitat_at(tree.global_position.x, tree.global_position.z)
	var species := _pick_species(habitat, as_bird)
	if species == null:
		return null
	return place(species, tree, as_bird)


## Crea el emboscador de species en tree (lo usan también las pruebas).
func place(species: SpeciesData, tree: Node3D, as_bird: bool) -> PokemonActor:
	var actor := _spawner.spawn_species(species, tree.global_position, _rng.randf() < WildSpawner.SHINY_CHANCE, false)
	actor.add_to_group(AMBUSH_GROUP)
	actor.perch_on(tree, as_bird)
	tree.set_meta("ambusher", actor)
	return actor


func _pick_tree() -> Node3D:
	for attempt in 20:
		var tree := _trees[_rng.randi() % _trees.size()]
		var distance := tree.global_position.distance_to(_player.global_position)
		if distance < min_distance or distance > max_distance:
			continue
		var occupant: Variant = tree.get_meta("ambusher", null)
		if occupant != null and is_instance_valid(occupant):
			continue
		return tree
	return null


## Bicho pequeño o mediano, o ave voladora pequeña o mediana, del hábitat del árbol.
func _pick_species(habitat: SpeciesData.Habitat, as_bird: bool) -> SpeciesData:
	for attempt in 30:
		var species := _spawner.pick_species(habitat, 0)
		if species == null or species.size_scale > 1.5:
			continue
		if as_bird and species.types.has(PokemonTypes.Type.FLYING) and not species.types.has(PokemonTypes.Type.BUG):
			return species
		if not as_bird and species.types.has(PokemonTypes.Type.BUG):
			return species
	return null
