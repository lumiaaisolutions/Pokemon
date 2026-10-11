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
## El árbol mide al menos esto veces la altura del Pokémon posado o colgado.
const TREE_RATIO := 2.5
## Bicho al pie del árbol en vez de colgado (decisión de Fernando, 2026-10-10).
const GROUND_BUG_SHARE := 0.4
const TREE_PREFIXES := ["Tree", "EdgeTree", "ShoreTree"]

var _trees: Array[Node3D] = []
var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var _world: WorldBuilder = get_node(world_path)
@onready var _spawner: WildSpawner = get_node(spawner_path)
@onready var _player: Node3D = get_node(player_path)


func _ready() -> void:
	_rng.randomize()


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
## Primero el Pokémon y luego un árbol al menos TREE_RATIO veces más alto que él (pedido
## de Fernando, 2026-10-10: el árbol siempre más grande). Parte de los Bicho salen al pie
## del tronco en vez de colgados.
func spawn_one() -> PokemonActor:
	var near := _pick_tree()
	if near == null:
		return null
	var as_bird := _rng.randf() >= bug_ratio
	var habitat := _world.habitat_at(near.global_position.x, near.global_position.z)
	var species := _pick_species(habitat, as_bird)
	if species == null:
		return null
	var tree := _pick_tree(pokemon_height(species) * TREE_RATIO)
	if tree == null:
		return null
	if not as_bird and _rng.randf() < GROUND_BUG_SHARE:
		return place_at_foot(species, tree)
	return place(species, tree, as_bird)


## Altura visible del Pokémon (m): su celda de sprite a su tamaño.
static func pokemon_height(species: SpeciesData) -> float:
	return PokemonActor.PIXEL_SIZE * 32.0 * species.size_scale


## Altura del árbol (m): la guarda _obstacle en world_builder.gd al crearlo (los árboles
## ahora son una malla 3D, no un Sprite3D con su textura).
static func tree_height(tree: Node3D) -> float:
	return float(tree.get_meta("obstacle_height", 0.0))


## Bicho al pie del tronco (entre las raíces), como salvaje normal.
func place_at_foot(species: SpeciesData, tree: Node3D) -> PokemonActor:
	var angle := _rng.randf() * TAU
	var at := tree.global_position + Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(1.4, 2.4)
	at.y = _world.surface_height_at(at.x, at.z)
	return _spawner.spawn_species(species, at, _rng.randf() < _spawner.shiny_chance(), false)


## Crea el emboscador de species en tree (lo usan también las pruebas).
func place(species: SpeciesData, tree: Node3D, as_bird: bool) -> PokemonActor:
	var actor := _spawner.spawn_species(species, tree.global_position, _rng.randf() < WildSpawner.SHINY_CHANCE, false)
	actor.add_to_group(AMBUSH_GROUP)
	actor.perch_on(tree, as_bird)
	tree.set_meta("ambusher", actor)
	return actor


func _pick_tree(min_height: float = 0.0) -> Node3D:
	# Los árboles de las zonas cercanas cargadas.
	_trees.assign(get_tree().get_nodes_in_group(WorldBuilder.TREES_GROUP))
	if _trees.is_empty():
		return null
	for attempt in 40:
		var tree := _trees[_rng.randi() % _trees.size()]
		var distance := tree.global_position.distance_to(_player.global_position)
		if distance < min_distance or distance > max_distance:
			continue
		if tree.has_meta("ambusher") and is_instance_valid(tree.get_meta("ambusher")):
			continue
		if tree_height(tree) < min_height:
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
