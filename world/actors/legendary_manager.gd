class_name LegendaryManager
extends Node3D
## Los legendarios y singulares solo aparecen en santuarios: pocos lugares especiales
## por hábitat (la cumbre más alta incluida). Cada vez que el jugador llega a un
## santuario hay SUMMON_CHANCE de que aparezca uno de los legendarios de ese hábitat.
## Nunca hay dos del mismo; si ya se capturó, solo vuelve con la tirada del 2 % de
## GameState. Son cautelosos (ver PokemonActor.legendary). La hora y el clima como
## condición llegan con la capa 2.7.

const LEGENDARY_GROUP := &"legendary_pokemon"
const ALL_SPECIES := preload("res://creatures/data/all_species.tres")
const SUMMON_CHANCE := 0.1
## Santuarios por hábitat.
const SANCTUARIES_PER_HABITAT := {
	SpeciesData.Habitat.MEADOW: 2, SpeciesData.Habitat.FOREST: 2, SpeciesData.Habitat.MOUNTAIN: 2,
	SpeciesData.Habitat.FRESHWATER: 1, SpeciesData.Habitat.SEA: 1, SpeciesData.Habitat.SWAMP: 1,
}

@export var world_path: NodePath
@export var spawner_path: NodePath
@export var player_path: NodePath
## Al entrar a este radio de un santuario cuenta como visita.
@export var visit_radius: float = 50.0
## Al salir de este radio la visita termina (y el legendario se retira).
@export var leave_radius: float = 130.0
@export var min_spacing: float = 80.0
@export var spawn_clear_radius: float = 60.0

## Santuarios: posición y hábitat.
var sanctuaries: Array[Dictionary] = []
var _pool_by_habitat := {}
## Índice de santuario -> legendario activo (o null).
var _active := {}
var _visiting := {}
var _rng := RandomNumberGenerator.new()

@onready var _world: WorldBuilder = get_node(world_path)
@onready var _spawner: WildSpawner = get_node(spawner_path)
@onready var _player: Node3D = get_node(player_path)


func _ready() -> void:
	_rng.randomize()
	for species: SpeciesData in ALL_SPECIES.species:
		if not (species.is_legendary or species.is_mythical):
			continue
		for habitat in species.habitats:
			if not _pool_by_habitat.has(habitat):
				_pool_by_habitat[habitat] = [] as Array[SpeciesData]
			(_pool_by_habitat[habitat] as Array[SpeciesData]).append(species)
	_place_sanctuaries()


## Santuarios de la región: los lugares "sanctuary" del mapa (con el hábitat de donde
## cayeron), la cumbre más alta, la orilla de un lago (agua dulce) y un faro (mar);
## cada hábitat tiene al menos uno.
func _place_sanctuaries() -> void:
	var layout := _world.layout
	var rng := RandomNumberGenerator.new()
	rng.seed = _world.config.seed + 97
	for place: Dictionary in layout.places_of("sanctuary"):
		if place.get("summit", false):
			var sx := float(place["x"])
			var sz := float(place["z"])
			# Frente al santuario (el altar está en el centro).
			sz += 7.0
			sanctuaries.append({"position": Vector3(sx, _world.height_at(sx, sz), sz), "habitat": SpeciesData.Habitat.MOUNTAIN})
	for place: Dictionary in layout.places_of("sanctuary"):
		if place.get("summit", false):
			continue
		var x := float(place["x"])
		var z := float(place["z"])
		z += 7.0
		sanctuaries.append({"position": Vector3(x, _world.height_at(x, z), z), "habitat": _world.habitat_at(x, z)})
	if not layout.lakes.is_empty():
		var lake: Vector4 = layout.lakes[rng.randi() % layout.lakes.size()]
		var x := lake.x + lake.z + RegionLayout.LAKE_BANK + 2.0
		sanctuaries.append({"position": Vector3(x, _world.height_at(x, lake.y), lake.y), "habitat": SpeciesData.Habitat.FRESHWATER})
	var coast := layout.places_of("lighthouse")
	if not coast.is_empty():
		var x := float(coast[0]["x"]) + 6.0
		var z := float(coast[0]["z"])
		sanctuaries.append({"position": Vector3(x, _world.height_at(x, z), z), "habitat": SpeciesData.Habitat.SEA})
	for habitat: SpeciesData.Habitat in SANCTUARIES_PER_HABITAT:
		if sanctuaries.any(func(s: Dictionary) -> bool: return s.habitat == habitat):
			continue
		for attempt in 3000:
			var half := _world.config.size * 0.5 - RegionLayout.EDGE_MOUNTAIN
			var x := rng.randf_range(-half, half)
			var z := rng.randf_range(-half, half)
			if _world.habitat_at(x, z) != habitat or layout.water_level_at(x, z) - layout.height_at(x, z) > -0.3:
				continue
			sanctuaries.append({"position": Vector3(x, _world.height_at(x, z), z), "habitat": habitat})
			break


func _process(_delta: float) -> void:
	for i in sanctuaries.size():
		var position: Vector3 = sanctuaries[i].position
		var distance := position.distance_to(_player.global_position)
		var actor: PokemonActor = _active.get(i)
		if actor != null and not is_instance_valid(actor):
			_active.erase(i)
			actor = null
		if distance < visit_radius and not _visiting.get(i, false):
			_visiting[i] = true
			if actor == null and _rng.randf() < SUMMON_CHANCE:
				summon(i)
		elif distance > leave_radius and _visiting.get(i, false):
			_visiting[i] = false
			if actor != null:
				actor.queue_free()
				_active.erase(i)


## Hace aparecer un legendario en el santuario i. identifier vacío = uno al azar del
## hábitat que no esté ya en el mundo y esté disponible. Devuelve null si no hay.
func summon(i: int, identifier: String = "") -> PokemonActor:
	var sanctuary := sanctuaries[i]
	var candidates: Array[SpeciesData] = []
	for species: SpeciesData in _pool_by_habitat.get(sanctuary.habitat, []):
		if identifier != "" and species.identifier != identifier:
			continue
		if _is_active(species.identifier) or not GameState.is_legendary_available(species.identifier):
			continue
		candidates.append(species)
	if candidates.is_empty():
		return null
	var species := candidates[_rng.randi() % candidates.size()]
	var actor := _spawner.spawn_species(species, sanctuary.position, false, false, true)
	_active[i] = actor
	return actor


func _is_active(identifier: String) -> bool:
	for actor in _active.values():
		if is_instance_valid(actor) and (actor as PokemonActor).species.identifier == identifier:
			return true
	return false
