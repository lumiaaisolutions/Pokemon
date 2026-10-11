class_name BreakableRocks
extends Node3D
## Rocas pequeñas agrietadas del campo (fase 5.8, decisiones de Fernando 2026-10-10): se
## colocan con cada zona del mundo (siempre las mismas para la misma semilla), más en
## montaña, cañón, meseta, tundra y desierto. Cualquier compañero las rompe atacándolas
## (ver PokemonActor.command_move) y sueltan un premio (mezcla equilibrada); vuelven a su
## lugar a los 3 días (world_flags["rocks"][id] = día en que se rompió).

const PER_CHUNK := 3
const RESPAWN_DAYS := 3
## Probabilidad de que cada intento ponga una roca, por bioma.
const ROCKY_BIOMES := [RegionLayout.Biome.MOUNTAIN, RegionLayout.Biome.CANYON, RegionLayout.Biome.MESA, RegionLayout.Biome.TUNDRA, RegionLayout.Biome.DESERT]
const ROCKY_CHANCE := 0.7
const OTHER_CHANCE := 0.25
## Premios (pesos): minerales 55, Pokémon escondido 15, piedra evolutiva 10, fósil 5,
## Pepita/Perla 5, nada 10.
const REWARDS := {"mineral": 55, "pokemon": 15, "stone": 10, "fossil": 5, "treasure": 5, "nothing": 10}
const MINERALS := {"hard-stone": 60, "red-shard": 15, "blue-shard": 15, "star-piece": 10}
const STONES := ["fire-stone", "water-stone", "thunderstone", "leaf-stone", "moon-stone", "sun-stone", "shiny-stone", "dusk-stone", "dawn-stone"]
const TREASURES := ["nugget", "pearl"]
## Pokémon que se esconden en las rocas.
const HIDDEN_POOL := ["geodude", "roggenrola", "dwebble", "nosepass", "rolycoly", "shuckle", "onix", "larvitar", "sandshrew", "binacle"]

@export var world_path: NodePath

var _world: WorldBuilder
var _rng := RandomNumberGenerator.new()
var _check := 0.0


func _ready() -> void:
	add_to_group(&"breakable_rocks_manager")
	_rng.randomize()
	_world = get_node(world_path) as WorldBuilder
	_world.chunk_built.connect(_populate)
	var chunks := _world.near_chunks()
	for key: Vector2i in chunks:
		_populate(key, chunks[key])


static func _flags() -> Dictionary:
	if not GameState.world_flags.has("rocks"):
		GameState.world_flags["rocks"] = {}
	return GameState.world_flags["rocks"]


## ¿La roca id está rota (y aún no le toca volver)?
static func is_down(id: String) -> bool:
	var day := int(_flags().get(id, -999))
	return GameState.game_day() < day + RESPAWN_DAYS


func _populate(key: Vector2i, root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ (_world.config.seed * 53 + 11)
	for i in PER_CHUNK:
		var x := (key.x + rng.randf()) * WorldBuilder.CHUNK
		var z := (key.y + rng.randf()) * WorldBuilder.CHUNK
		var roll := rng.randf()
		var chance := ROCKY_CHANCE if _world.layout.biome_at(x, z) in ROCKY_BIOMES else OTHER_CHANCE
		if roll > chance or not _world.is_inside(x, z, 12.0):
			continue
		if _world.water_depth_at(x, z) > -0.3 or not _world.settlement_at(x, z, 6.0).is_empty() or _world.distance_to_paths(x, z) < 3.0:
			continue
		var id := "%d_%d_%d" % [key.x, key.y, i]
		var rock := BreakableRock.create(root, Vector3(x, _world.surface_height_at(x, z), z), id, false)
		rock.broken.connect(_on_broken)
		if is_down(id):
			rock.smash_silently()


func _process(delta: float) -> void:
	# Cada tanto revisa si a alguna roca rota ya le toca volver.
	_check -= delta
	if _check > 0.0:
		return
	_check = 5.0
	for node in get_tree().get_nodes_in_group(BreakableRock.GROUP):
		var rock := node as BreakableRock
		if not rock.big and rock.is_broken() and not is_down(rock.rock_id):
			rock.restore()


func _on_broken(rock: BreakableRock) -> void:
	_flags()[rock.rock_id] = GameState.game_day()
	reward(rock.global_position)


## Premio de una roca pequeña rota en at. Devuelve el tipo de premio (pruebas).
func reward(at: Vector3) -> String:
	var kind := _weighted(REWARDS)
	match kind:
		"mineral":
			_give(_weighted(MINERALS), _rng.randi_range(1, 2))
		"stone":
			_give(STONES[_rng.randi() % STONES.size()], 1)
		"fossil":
			_give(TownServices.FOSSILS.keys()[_rng.randi() % TownServices.FOSSILS.size()], 1)
		"treasure":
			_give(TREASURES[_rng.randi() % TREASURES.size()], 1)
		"pokemon":
			var species := _hidden_species()
			var spawner := get_parent().get_node_or_null("Spawner") as WildSpawner
			if species == null or spawner == null:
				_give(_weighted(MINERALS), 1)
				return "mineral"
			spawner.spawn_species(species, at + Vector3(0.8, 0.2, 0.8), _rng.randf() < spawner.shiny_chance(), false)
			GameState.notice.emit("¡Un %s estaba escondido en la roca!" % species.display_name)
		_:
			GameState.notice.emit("La roca se rompió, pero no había nada.")
	return kind


## Un Pokémon de roca de la Pokédex regional (o cualquiera de tipo Roca de la región).
func _hidden_species() -> SpeciesData:
	var pool: Array[SpeciesData] = []
	for id: String in HIDDEN_POOL:
		var species := MenuStyle.species(id)
		if species != null and Regions.allows(species):
			pool.append(species)
	if pool.is_empty():
		for species: SpeciesData in WildSpawner.ALL_SPECIES.species:
			if species.types.has(PokemonTypes.Type.ROCK) and species.evolution_stage == 1 and species.spawn_weight > 0.0 \
					and not species.is_legendary and not species.is_mythical and Regions.allows(species):
				pool.append(species)
	return pool[_rng.randi() % pool.size()] if not pool.is_empty() else null


func _give(item: String, amount: int) -> void:
	GameState.add_item(item, amount)
	AudioBus.play_jingle("me_item")
	GameState.notice.emit("Encontraste %s × %d en la roca." % [Items.display_name(item), amount])


func _weighted(table: Dictionary) -> String:
	var total := 0
	for key: String in table:
		total += int(table[key])
	var roll := _rng.randi_range(1, total)
	for key: String in table:
		roll -= int(table[key])
		if roll <= 0:
			return key
	return table.keys()[0]
