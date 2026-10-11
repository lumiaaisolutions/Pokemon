class_name WildSpawner
extends Node3D
## Hace aparecer Pokémon salvajes cerca del jugador en cualquier lugar transitable
## (pradera, entre árboles y rocas, hierba alta), en la orilla del agua (tipo Agua
## que no nada) o dentro del agua (nadadores).
## - El mundo se divide en zonas de ZONE_SIZE m con un cupo de grupos según su
##   hábitat, para no saturar un solo lugar; cada zona tiene 2 especies
##   características que aparecen más ahí.
## - La especie se sortea por su peso de rareza (etapa × poder); 1 % de shiny.
## - Zonas propias (estilo Escarlata y Púrpura): con la semilla, cada especie tiene de 1
##   a 3 áreas del mapa donde vive (según su hábitat y clima). Ahí es común; fuera es
##   rara. Algunas son nómadas y cambian de área cada día del juego. La Pokédex
##   muestra estas áreas según su nivel de investigación.
## - 30 % de las apariciones son manadas de 3 a 6 de la misma línea evolutiva
##   (casi todos básicos y rara vez un líder evolucionado). Nunca dos manadas a
##   menos de PACK_SPACING m, salvo con 5 % de probabilidad (y entonces pueden pelear).

signal wild_contact(actor: PokemonActor)

const WILD_GROUP := &"wild_pokemon"
const ACTOR_SCENE := preload("res://world/actors/pokemon_actor.tscn")
const ALL_SPECIES := preload("res://creatures/data/all_species.tres")
const SHINY_CHANCE := 0.01
## Áreas propias de cada especie: cuántas, de qué radio, y su peso dentro y fuera.
const HOME_AREAS_MAX := 3
const HOME_RADIUS_MIN := 28.0
const HOME_RADIUS_MAX := 50.0
const HOME_BOOST := 12.0
const OUTSIDE_FACTOR := 0.12
const NOMAD_SHARE := 0.08
const ZONE_SIZE := 40.0
## Grupos (un solitario o una manada) que caben en cada zona según su hábitat.
## (La mitad que antes: ~8 a 12 Pokémon alrededor, como en Escarlata y Púrpura.)
const ZONE_QUOTA := {
	SpeciesData.Habitat.MEADOW: 2, SpeciesData.Habitat.FOREST: 2, SpeciesData.Habitat.MOUNTAIN: 1,
	SpeciesData.Habitat.FRESHWATER: 1, SpeciesData.Habitat.SEA: 1, SpeciesData.Habitat.SWAMP: 2,
}
const FEATURED_PER_ZONE := 2
## Comunes y raros (pedido de Fernando, 2026-10-10): cada parcela de 160 m tiene de 3 a 5
## especies comunes que se ven varias veces sueltas; la rareza sale de la especie (ratio de
## captura oficial: Pidgey 255 común, Eevee o Dratini 45 raros), igual en todas las regiones.
const COMMON_PATCH := 160.0
const COMMONS_MIN := 3
const COMMONS_MAX := 5
const COMMON_BOOST := 30.0
## Solo pueden ser comunes las especies fáciles de ver (rareza mínima).
const COMMON_MIN_RARITY := 0.45
## Proporción de apariciones de una zona que son de sus especies características.
const FEATURED_SHARE := 0.35
const PACK_CHANCE := 0.2
## Hordas (fase 5.8, decisión de Fernando 2026-10-10): 2 % de las apariciones, en cualquier
## lugar, 5 de la misma especie que te rodean y pelean a la vez; el 1 % de las hordas trae un
## líder evolucionado. Shiny ×3 en las hordas.
const HORDE_CHANCE := 0.02
const HORDE_SIZE := 5
const HORDE_LEADER_CHANCE := 0.01
const HORDE_SHINY_BOOST := 3.0
const HORDE_GROUP := &"hordes"
var _next_horde_id := 0
const PACK_SIZE_MIN := 2
const PACK_SIZE_MAX := 4
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
@export var max_alive: int = 12
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
## Áreas propias: identifier -> Array de Vector3(x, z, radio). Nómadas aparte.
var _home_areas := {}
var _nomads: Array[String] = []
var _nomad_day := -1

@onready var _world: WorldBuilder = get_node(world_path)
@onready var _player: Node3D = get_node(player_path)
@onready var _navigation: WorldNavigation = get_node(navigation_path)


func _ready() -> void:
	_rng.randomize()
	_index_species()
	_build_home_areas()
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
		# Solo las especies de la Pokédex de esta región (ver Regions).
		if species.spawn_weight <= 0.0 or not Regions.allows(species):
			continue
		for habitat in species.habitats:
			var entry: Dictionary = _by_habitat[habitat]
			var cumulative: PackedFloat32Array = entry.cumulative
			var total: float = cumulative[-1] if cumulative.size() > 0 else 0.0
			(entry.species as Array[SpeciesData]).append(species)
			cumulative.append(total + species.spawn_weight * rarity(species))
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
	# Una manada cuenta solo en la zona de su primer miembro (el líder), aunque los demás
	# queden al otro lado del borde.
	var group_zone := {}
	for node in get_tree().get_nodes_in_group(WILD_GROUP):
		var actor := node as PokemonActor
		var zone := zone_of(actor.home)
		if actor.group_id >= 0:
			if not group_zone.has(actor.group_id):
				group_zone[actor.group_id] = zone
			zone = group_zone[actor.group_id]
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


# --- Áreas propias de cada especie ---------------------------------------------------

## Con la semilla del mundo, de 1 a 3 áreas por especie en lugares de su hábitat y clima.
func _build_home_areas() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _world.config.seed * 7919 + 17
	var half := _world.config.size * 0.5 - 20.0
	for species: SpeciesData in ALL_SPECIES.species:
		if species.spawn_weight <= 0.0 or species.is_legendary or species.is_mythical or not Regions.allows(species):
			continue
		if rng.randf() < NOMAD_SHARE:
			_nomads.append(species.identifier)
		_home_areas[species.identifier] = _areas_for(species, rng, half)
	_refresh_nomads()


func _areas_for(species: SpeciesData, rng: RandomNumberGenerator, half: float) -> Array[Vector3]:
	var areas: Array[Vector3] = []
	var wanted := rng.randi_range(1, HOME_AREAS_MAX)
	for attempt in 60:
		if areas.size() >= wanted:
			break
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if not species.habitats.has(_world.habitat_at(x, z)):
			continue
		var y := _world.surface_height_at(x, z)
		if attempt < 45 and not climate_ok(species, Vector3(x, y, z)):
			continue
		areas.append(Vector3(x, z, rng.randf_range(HOME_RADIUS_MIN, HOME_RADIUS_MAX)))
	return areas


## Los nómadas cambian de área cada día del juego.
func _refresh_nomads() -> void:
	var day := GameState.game_day()
	if day == _nomad_day:
		return
	_nomad_day = day
	var half := _world.config.size * 0.5 - 20.0
	for identifier in _nomads:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(identifier) ^ (_world.config.seed + day * 104729)
		var species := MenuStyle.species(identifier)
		if species != null:
			_home_areas[identifier] = _areas_for(species, rng, half)


var _regional := {}


## Número de la Pokédex regional (1…): las líneas evolutivas ordenadas por qué tan cerca
## del pueblo inicial viven (como en los juegos, lo primero que ves va primero), cada
## línea con sus evoluciones seguidas; los legendarios al final. 0 = no vive en la región.
func regional_number(identifier: String) -> int:
	if _regional.is_empty():
		_build_regional()
	return int(_regional.get(identifier, 0))


func regional_size() -> int:
	if _regional.is_empty():
		_build_regional()
	return _regional.size()


func _build_regional() -> void:
	var start := Vector2(_world.layout.start)
	var chain_distance := {}
	for identifier: String in _home_areas:
		var species := MenuStyle.species(identifier)
		if species == null:
			continue
		for area: Vector3 in _home_areas[identifier]:
			var d := Vector2(area.x, area.y).distance_to(start)
			chain_distance[species.evolution_chain] = minf(float(chain_distance.get(species.evolution_chain, INF)), d)
	var chains: Array = chain_distance.keys()
	chains.sort_custom(func(a: int, b: int) -> bool: return float(chain_distance[a]) < float(chain_distance[b]))
	var number := 0
	for chain: int in chains:
		for species: SpeciesData in _by_chain.get(chain, []):
			if not _regional.has(species.identifier):
				number += 1
				_regional[species.identifier] = number
	for species: SpeciesData in ALL_SPECIES.species:
		if (species.is_legendary or species.is_mythical) and Regions.allows(species) and not _regional.has(species.identifier):
			number += 1
			_regional[species.identifier] = number


## Áreas donde vive la especie (Vector3(x, z, radio)); vacío si no tiene.
func home_areas(identifier: String) -> Array[Vector3]:
	var areas: Array[Vector3] = []
	areas.assign(_home_areas.get(identifier, []))
	return areas


func is_nomad(identifier: String) -> bool:
	return _nomads.has(identifier)


## Pokémon nocturnos además de los tipos Fantasma y Siniestro.
const NOCTURNAL := ["hoothoot", "noctowl", "zubat", "golbat", "crobat", "oddish", "gloom", "venonat", "venomoth", "clefairy",
		"murkrow", "spinarak", "ariados", "gastly", "haunter", "kricketot", "kricketune", "woobat", "swoobat", "noibat", "noivern", "rockruff"]


## Peso según la hora: de noche salen más los nocturnos, Fantasma y Siniestro.
func time_factor(species: SpeciesData) -> float:
	var night_lover := species.types.has(PokemonTypes.Type.GHOST) or species.types.has(PokemonTypes.Type.DARK) or NOCTURNAL.has(species.identifier)
	if GameState.is_night():
		return 4.0 if night_lover else 0.7
	return 0.3 if night_lover else 1.0


## Especies de temporada (fase 5.8, decisión de Fernando 2026-10-10): por tipo y estación
## (Weather: 0 Primavera, 1 Verano, 2 Otoño, 3 Invierno). Multiplicadores por tipo:
const SEASON_TYPES := [
	{PokemonTypes.Type.FAIRY: 2.2, PokemonTypes.Type.NORMAL: 1.5, PokemonTypes.Type.FLYING: 1.6},
	{PokemonTypes.Type.BUG: 2.0, PokemonTypes.Type.GRASS: 1.6, PokemonTypes.Type.FIRE: 1.8},
	{PokemonTypes.Type.GHOST: 2.5, PokemonTypes.Type.DARK: 2.0},
	{PokemonTypes.Type.ICE: 3.0, PokemonTypes.Type.BUG: 0.3, PokemonTypes.Type.GRASS: 0.4},
]
## Especies que solo salen en su estación (línea completa).
const SEASON_ONLY := {
	"cherubi": 0, "cherrim": 0, "combee": 0, "vespiquen": 0,
	"volbeat": 1, "illumise": 1, "surskit": 1, "masquerain": 1,
	"deerling": 2, "sawsbuck": 2, "phantump": 2, "trevenant": 2, "pumpkaboo": 2, "gourgeist": 2,
	"snover": 3, "abomasnow": 3, "delibird": 3, "cubchoo": 3, "beartic": 3,
	"vanillite": 3, "vanillish": 3, "vanilluxe": 3, "spheal": 3, "sealeo": 3, "walrein": 3,
}


static func current_season() -> int:
	return Weather.season(GameState.game_day())


## ¿Sale species en la estación actual? (las de temporada solo en la suya).
static func in_season(species: SpeciesData) -> bool:
	return not SEASON_ONLY.has(species.identifier) or int(SEASON_ONLY[species.identifier]) == current_season()


## Peso por la estación: según sus tipos; 0 si es de otra temporada.
static func season_factor(species: SpeciesData) -> float:
	if not in_season(species):
		return 0.0
	var table: Dictionary = SEASON_TYPES[current_season()]
	var factor := 1.0
	for type in species.types:
		factor *= float(table.get(type, 1.0))
	return factor


## Peso extra de la especie en point: común en su área, rara fuera.
## Rareza de la especie (0.05–1) por su ratio de captura oficial.
static func rarity(species: SpeciesData) -> float:
	return clampf(pow(species.capture_rate / 255.0, 1.2), 0.05, 1.0)


var _commons := {}


## Especies comunes de la parcela (fijas por semilla): las que más se repiten ahí.
func commons_at(habitat: SpeciesData.Habitat, point: Vector3) -> Array[SpeciesData]:
	var key := Vector3i(floori(point.x / COMMON_PATCH), floori(point.z / COMMON_PATCH), habitat)
	if _commons.has(key):
		return _commons[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ (_world.config.seed + 271)
	var wanted := rng.randi_range(COMMONS_MIN, COMMONS_MAX)
	var picked: Array[SpeciesData] = []
	for attempt in 60:
		if picked.size() >= wanted:
			break
		var species := _weighted_pick(habitat, rng)
		if species != null and not picked.has(species) and rarity(species) >= COMMON_MIN_RARITY and species.evolution_stage <= 2:
			picked.append(species)
	_commons[key] = picked
	return picked


func common_factor(species: SpeciesData, habitat: SpeciesData.Habitat, point: Vector3) -> float:
	return COMMON_BOOST if commons_at(habitat, point).has(species) else 1.0


func home_factor(identifier: String, point: Vector3) -> float:
	for area: Vector3 in _home_areas.get(identifier, []):
		if Vector2(point.x - area.x, point.z - area.y).length() <= area.z:
			return HOME_BOOST
	return OUTSIDE_FACTOR


const REPEL_DISTANCE := 45.0


## Probabilidad de shiny con los potenciadores: Huevo Suerte ×2, Amuleto Iris ×3.
func shiny_chance() -> float:
	var chance := SHINY_CHANCE
	if GameState.boost_active("shiny"):
		chance *= 2.0
	if GameState.item_count("shiny-charm") > 0:
		chance *= 3.0
	return chance


## Miel: aparecen hasta 2 Pokémon del lugar cerca de center. Devuelve cuántos.
func spawn_lure(center: Vector3) -> int:
	var count := 0
	for i in 6:
		if count >= 2:
			break
		var angle := _rng.randf() * TAU
		var point := center + Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(6.0, 10.0)
		point = _snap_to_walkable(point)
		if point == Vector3.INF:
			continue
		var species := pick_species(_world.habitat_at(point.x, point.z), 0, Vector2i(9999, 9999), point)
		if species == null or not climate_ok(species, point):
			continue
		spawn_species(species, point, _rng.randf() < shiny_chance(), false)
		count += 1
	return count


## Sortea una especie del hábitat. water_mode: 0 tierra, 1 orilla, 2 agua (nadadores).
## Con point, pesan las áreas propias de cada especie (común en su área, rara fuera).
func pick_species(habitat: SpeciesData.Habitat, water_mode: int, zone: Vector2i = Vector2i(9999, 9999), point: Vector3 = Vector3.INF) -> SpeciesData:
	var featured: Array[SpeciesData] = []
	if zone != Vector2i(9999, 9999) and point == Vector3.INF:
		featured = featured_species(zone, habitat)
	for attempt in 16:
		var species: SpeciesData
		if point != Vector3.INF:
			species = _weighted_pick_at(habitat, point)
		elif not featured.is_empty() and _rng.randf() < FEATURED_SHARE:
			species = featured[_rng.randi() % featured.size()]
		else:
			species = _weighted_pick(habitat, _rng)
		if species == null:
			return null
		if not in_season(species):
			continue
		var is_water_type := species.types.has(PokemonTypes.Type.WATER)
		if water_mode == 2 and not species.swims:
			continue
		if water_mode == 1 and (species.swims or not is_water_type):
			continue
		if water_mode == 0 and is_water_type:
			continue
		return _region_evolve(species)
	return null


## Dificultad por región: en las regiones siguientes los salvajes salen más evolucionados
## (12 % más de probabilidad por región de subir una etapa en su línea).
func _region_evolve(species: SpeciesData) -> SpeciesData:
	var chance := Regions.index() * 0.12
	if chance <= 0.0 or _rng.randf() >= chance:
		return species
	for next: SpeciesData in _by_chain.get(species.evolution_chain, []):
		if next.evolution_stage == species.evolution_stage + 1 and next.spawn_weight > 0.0 and not next.habitats.is_empty() \
				and species.habitats.any(func(h: int) -> bool: return next.habitats.has(h)):
			return next
	return species


func _weighted_pick_at(habitat: SpeciesData.Habitat, point: Vector3) -> SpeciesData:
	var candidates: Array[SpeciesData] = _by_habitat[habitat].species
	if candidates.is_empty():
		return null
	var weights := PackedFloat32Array()
	var total := 0.0
	for species in candidates:
		var occupied := 6.0 if ActivityManager.is_occupied(point) and (species.types.has(PokemonTypes.Type.DARK) or species.types.has(PokemonTypes.Type.POISON)) else 1.0
		var place := _world.type_affinity(species.types, point.x, point.z) * weather_factor(species)
		total += species.spawn_weight * rarity(species) * common_factor(species, habitat, point) * home_factor(species.identifier, point) * time_factor(species) * season_factor(species) * occupied * place
		weights.append(total)
	var index := weights.bsearch(_rng.randf() * total)
	return candidates[mini(index, candidates.size() - 1)]


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
	_refresh_nomads()
	for node in get_tree().get_nodes_in_group(WILD_GROUP):
		var actor := node as PokemonActor
		if actor.global_position.distance_to(_player.global_position) > despawn_distance:
			actor.queue_free()
	# Dentro de un interior aparecen solo los Pokémon del interior.
	if _player.global_position.x > WorldBuilder.INTERIOR_X:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = spawn_interval
	# Densidad elegida en Opciones (baja, media o alta).
	max_alive = GameOptions.DENSITY_MAX_ALIVE[clampi(GameOptions.density, 0, 2)]
	if get_tree().get_nodes_in_group(WILD_GROUP).size() < max_alive:
		spawn_one()


## Hace aparecer un solitario o una manada cerca del jugador. Devuelve el primero
## creado (el líder si es manada), o null si no encontró sitio.
func spawn_one() -> PokemonActor:
	var counts := groups_per_zone()
	for attempt in 8:
		var angle := _rng.randf() * TAU
		var distance := _rng.randf_range(min_spawn_distance, max_spawn_distance)
		# Con repelente no aparece nada cerca del jugador.
		if GameState.boost_active("repel"):
			distance = maxf(distance, REPEL_DISTANCE)
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
			# Al ajustarse al suelo caminable puede caer en otra zona: se revisa su cupo.
			zone = zone_of(point)
			if counts.get(zone, 0) >= zone_quota(zone):
				continue
			# Junto al agua: mitad de las veces sale uno de tipo Agua en la orilla.
			if _world.random_water_point(_rng, point, 6.0, true) != Vector3.INF and _rng.randf() < 0.5:
				water_mode = 1
		var habitat := _world.habitat_at(point.x, point.z)
		# Migración (fase 5.8): donde aterrizó la bandada sale sobre todo esa especie, aunque
		# sea de fuera de la región, con más probabilidad de shiny.
		var migrations := get_tree().get_first_node_in_group(&"migrations") as Migrations
		var migrant := migrations.species_at(point) if migrations != null and water_mode == 0 else null
		if migrant != null and _rng.randf() < Migrations.LAND_SHARE:
			return spawn_species(migrant, point, _rng.randf() < shiny_chance() * Migrations.SHINY_BOOST, false)
		var species := pick_species(habitat, water_mode, zone, point)
		# Arrecife: en el mar del sur salen nadadores propios del fondo.
		if water_mode == 2 and _world.region_biome_at(point.x, point.z) == RegionLayout.Biome.SEA and _rng.randf() < 0.4:
			var reef := MenuStyle.species(REEF_POOL[_rng.randi() % REEF_POOL.size()])
			if reef != null and reef.swims:
				species = reef
		# Lugares con Pokémon propios (Zona Safari, ruinas) y eventos del mundo.
		if water_mode == 0:
			var special := special_pick(point)
			if special != null:
				species = special
		# Clima: en la nieve no hay Fuego, Planta ni Bicho; el Hielo vive en la nieve o el mar.
		for retry in CLIMATE_RETRIES:
			if species == null or climate_ok(species, point):
				break
			species = pick_species(habitat, water_mode, Vector2i(9999, 9999), point)
		if species == null or not climate_ok(species, point):
			continue
		if water_mode != 2 and _rng.randf() < HORDE_CHANCE:
			return spawn_horde(species, point, habitat)
		if water_mode != 2 and _rng.randf() < PACK_CHANCE and _pack_allowed(point):
			return _spawn_pack(species, point, habitat)
		return spawn_species(species, point, _rng.randf() < shiny_chance(), water_mode == 2)
	return null



const CLIMATE_RETRIES := 8
## Metros bajo la línea de nieve donde ya hace frío.
const COLD_MARGIN := 4.0


## Pokémon de un lugar especial o de un evento en point (o null): Zona Safari, Unown
## junto a las ruinas, y los de los eventos activos (brotes masivos).
func special_pick(point: Vector3) -> SpeciesData:
	var events := get_tree().get_first_node_in_group(&"world_events") as WorldEvents
	if events != null:
		var outbreak := events.outbreak_species_at(point)
		if outbreak != null and _rng.randf() < 0.7:
			return outbreak
	var services := _world.structures.services if _world.structures != null else null
	if services != null and not services.safari_place_at(point).is_empty() and _rng.randf() < 0.6:
		var pool := services.safari_species()
		if not pool.is_empty():
			return pool[_rng.randi() % pool.size()]
	if _world.structures != null:
		var place := _world.structures.place_at(point.x, point.z, 50.0)
		if not place.is_empty():
			var pool: Array = PLACE_POOLS.get(place["kind"], [])
			var chance := 0.5 if place["kind"] == "ruins" else 0.6
			if not pool.is_empty() and _rng.randf() < chance:
				return MenuStyle.species(pool[_rng.randi() % pool.size()])
	return null


## Pokémon propios de algunos lugares (cerca de ellos).
const PLACE_POOLS := {
	"ruins": ["unown"],
	"ranch": ["miltank", "mareep", "tauros", "ponyta", "wooloo", "skiddo", "mudbray", "lechonk"],
	"grotto": ["carbink", "sableye", "zubat", "geodude", "roggenrola", "nosepass", "noibat"],
	"berry_farm": ["combee", "cutiefly", "pichu", "bounsweet", "applin", "skwovet"],
	"oasis": ["lotad", "marill", "maractus", "sandile", "trapinch", "cacnea"],
	"power_plant": ["voltorb", "magnemite", "electrike"],
	"tower": ["gastly", "litwick", "duskull"],
}
## Arrecife: nadadores del fondo del mar del sur.
const REEF_POOL := ["corsola", "luvdisc", "clamperl", "relicanth", "mantine", "wailmer", "lanturn", "alomomola", "finneon", "staryu", "qwilfish"]


## Peso por el clima del momento (ver Weather): lluvia más Agua, nieve más Hielo…
func weather_factor(species: SpeciesData) -> float:
	var weather := get_tree().get_first_node_in_group(&"weather") as Weather
	return weather.type_factor(species.types) if weather != null else 1.0


## ¿Puede vivir species en point según el clima (frío de la nieve)?
func climate_ok(species: SpeciesData, point: Vector3) -> bool:
	var biome := _world.region_biome_at(point.x, point.z)
	if biome in [RegionLayout.Biome.DESERT, RegionLayout.Biome.VOLCANO] and species.types.has(PokemonTypes.Type.ICE):
		return false
	var cold := point.y >= _world.config.snow_height - COLD_MARGIN or biome == RegionLayout.Biome.TUNDRA
	var types := species.types
	if cold:
		return not (types.has(PokemonTypes.Type.FIRE) or types.has(PokemonTypes.Type.GRASS) or types.has(PokemonTypes.Type.BUG)) \
				or types.has(PokemonTypes.Type.ICE)
	if types.has(PokemonTypes.Type.ICE):
		return _world.habitat_at(point.x, point.z) == SpeciesData.Habitat.SEA and _world.region_biome_at(point.x, point.z) != RegionLayout.Biome.BEACH
	return true


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


## Horda de HORDE_SIZE de la etapa básica de la línea de species, en círculo alrededor de
## point; a veces (HORDE_LEADER_CHANCE) el primero es un líder evolucionado.
func spawn_horde(species: SpeciesData, point: Vector3, habitat: SpeciesData.Habitat = -1, force_leader := false) -> PokemonActor:
	var line: Array[SpeciesData] = (_by_chain.get(species.evolution_chain, [species]) as Array[SpeciesData]).filter(
			func(s: SpeciesData) -> bool: return s.spawn_weight > 0.0 and (habitat < 0 or s.habitats.has(habitat)))
	if line.is_empty():
		line = [species]
	var lowest: int = line.map(func(s: SpeciesData) -> int: return s.evolution_stage).min()
	var basic: SpeciesData = line.filter(func(s: SpeciesData) -> bool: return s.evolution_stage == lowest)[0]
	var evolved := line.filter(func(s: SpeciesData) -> bool: return s.evolution_stage > lowest)
	var horde_id := _next_horde_id
	_next_horde_id += 1
	var group := _next_group_id
	_next_group_id += 1
	var first: PokemonActor = null
	for i in HORDE_SIZE:
		var angle := TAU * i / HORDE_SIZE
		var at := _snap_to_walkable(point + Vector3(cos(angle), 0.0, sin(angle)) * 2.6 * maxf(1.0, basic.size_scale))
		if at == Vector3.INF:
			at = point
		var kind := basic
		if i == 0 and not evolved.is_empty() and (force_leader or _rng.randf() < HORDE_LEADER_CHANCE):
			kind = evolved[_rng.randi() % evolved.size()]
		var actor := spawn_species(kind, at, _rng.randf() < shiny_chance() * HORDE_SHINY_BOOST, false)
		actor.group_id = group
		actor.set_meta("horde", horde_id)
		actor.add_to_group(HORDE_GROUP)
		if first == null:
			first = actor
	return first


## Miembros vivos de una horda.
func horde_members(horde_id: int) -> Array[PokemonActor]:
	var result: Array[PokemonActor] = []
	for node in get_tree().get_nodes_in_group(HORDE_GROUP):
		var actor := node as PokemonActor
		if is_instance_valid(actor) and not actor.is_queued_for_deletion() and int(actor.get_meta("horde", -1)) == horde_id:
			result.append(actor)
	return result


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
	elif _rng.randf() < PACK_LEADER_CHANCE + Regions.index() * 0.08:
		var evolved := line.filter(func(s: SpeciesData) -> bool: return s.evolution_stage > lowest_stage)
		if not evolved.is_empty():
			leader_species = evolved[_rng.randi() % evolved.size()]
	var group := _next_group_id
	_next_group_id += 1
	var leader := spawn_species(leader_species, point, _rng.randf() < shiny_chance(), false)
	leader.group_id = group
	var count := _rng.randi_range(PACK_SIZE_MIN, PACK_SIZE_MAX) - 1
	for i in count:
		var angle := TAU * i / count + _rng.randf_range(-0.3, 0.3)
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(1.8, 3.2) * maxf(1.0, basic.size_scale)
		var member_point := _snap_to_walkable(point + offset)
		if member_point == Vector3.INF:
			continue
		var member := spawn_species(basic, member_point, _rng.randf() < shiny_chance(), false)
		member.group_id = group
		member.leader = leader
		member.pack_offset = offset
	return leader


## Crea un salvaje de la especie dada en el punto (lo usan también las pruebas).
func spawn_species(species: SpeciesData, point: Vector3, shiny: bool, swimming: bool, legendary := false, size := 1.0) -> PokemonActor:
	var actor := ACTOR_SCENE.instantiate() as PokemonActor
	actor.species = species
	if not is_equal_approx(size, 1.0):
		actor.size_factor = size
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
