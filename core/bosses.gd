class_name Bosses
extends RefCounted
## Guardianes de bioma (Fase 6, 2026-10-11, ver docs/sistemas/jefes.md): cada bioma
## presente en una región tiene un guardián fijo (un Pokémon evolucionado fuerte del
## tipo del bioma, elegido al azar por la semilla de la región; puede ser de fuera de
## la Pokédex regional si no hay uno fuerte de esa región) en el punto del bioma más
## alejado de los pueblos. Vive ahí (world/bosses/boss_manager.gd lo crea y lo vigila)
## hasta que lo vencen; reaparece más fuerte en cada región siguiente.
## El mar (bioma SEA, revisión de Fernando 2026-10-11 mañana) sí tiene guardián de tipo
## Agua fuerte (Gyarados, Kingdra, Milotic…): vive junto a una isla del archipiélago del
## sur (o en un islote forzado si ahí no cayó ninguna isla natural, ver
## RegionLayout.ensure_islet) con su arena de combate en tierra; solo se llega
## surfeando, porque BossManager elige a propósito el punto de mar más alejado de los
## pueblos.

const T := PokemonTypes.Type

## Bioma (RegionLayout.Biome) -> tipo de su guardián; sin repetir tipo entre biomas
## para que, aunque coincidan varios en una región, casi nunca compartan especie.
const GUARDIAN_TYPE := {
	RegionLayout.Biome.MEADOW: T.NORMAL,
	RegionLayout.Biome.FOREST: T.BUG,
	RegionLayout.Biome.MOUNTAIN: T.ROCK,
	RegionLayout.Biome.BEACH: T.WATER,
	RegionLayout.Biome.DESERT: T.GROUND,
	RegionLayout.Biome.CANYON: T.FIGHTING,
	RegionLayout.Biome.SAVANNA: T.ELECTRIC,
	RegionLayout.Biome.JUNGLE: T.GRASS,
	RegionLayout.Biome.TUNDRA: T.ICE,
	RegionLayout.Biome.VOLCANO: T.FIRE,
	RegionLayout.Biome.FLOWERS: T.FAIRY,
	RegionLayout.Biome.MUSHROOM: T.PSYCHIC,
	RegionLayout.Biome.DARK_FOREST: T.GHOST,
	RegionLayout.Biome.SWAMP: T.DARK,
	RegionLayout.Biome.TOXIC_SWAMP: T.POISON,
	RegionLayout.Biome.MESA: T.FLYING,
	RegionLayout.Biome.SEA: T.WATER,
}
## Biomas sin guardián: ninguno (el mar ya tiene el suyo desde la revisión de Fernando
## del 2026-10-11 mañana); se deja la lista para futuros biomas que no deban tener uno.
const NO_GUARDIAN: Array[RegionLayout.Biome] = []

## Piedra evolutiva que entrega el guardián si su tipo tiene una (si no, Caramelo Raro).
const STONE_FOR_TYPE := {
	T.FIRE: "fire-stone", T.WATER: "water-stone", T.ELECTRIC: "thunderstone", T.GRASS: "leaf-stone",
	T.FAIRY: "shiny-stone", T.GHOST: "dusk-stone", T.DARK: "dusk-stone", T.PSYCHIC: "dawn-stone",
	T.NORMAL: "moon-stone",
}
## Color del aura del guardián según su tipo (aprox. a TypeChart, sin depender de él).
const AURA_COLOR := {
	T.NORMAL: Color(0.85, 0.8, 0.7), T.BUG: Color(0.6, 0.8, 0.2), T.ROCK: Color(0.7, 0.6, 0.35),
	T.WATER: Color(0.3, 0.55, 1.0), T.GROUND: Color(0.8, 0.6, 0.3), T.FIGHTING: Color(0.75, 0.3, 0.25),
	T.ELECTRIC: Color(1.0, 0.9, 0.2), T.GRASS: Color(0.35, 0.85, 0.35), T.ICE: Color(0.6, 0.9, 1.0),
	T.FIRE: Color(1.0, 0.4, 0.15), T.FAIRY: Color(1.0, 0.6, 0.85), T.PSYCHIC: Color(0.9, 0.35, 0.75),
	T.GHOST: Color(0.5, 0.35, 0.7), T.DARK: Color(0.3, 0.25, 0.35), T.POISON: Color(0.6, 0.25, 0.75),
	T.FLYING: Color(0.65, 0.75, 1.0), T.DRAGON: Color(0.4, 0.3, 1.0),
}

## Escala de vida (hp_max) y de tamaño del guardián según la región (0 a 5): más
## fuerte y más grande en regiones avanzadas ("reaparece más fuerte"), hasta el tope
## pedido de ×2–3 de tamaño.
static func hp_scale(region: int) -> float:
	return clampf(2.4 + float(region) * 0.3, 2.4, 3.9)


static func size_scale(region: int) -> float:
	return clampf(2.0 + float(region) * 0.18, 2.0, 3.0)


## Umbrales de fase (66 % y 33 %) y el intervalo entre ataques en área de cada fase.
const PHASE_THRESHOLDS := [0.66, 0.33]
const PHASE_AOE_INTERVAL := {1: 7.5, 2: 5.6, 3: 4.2}
const PHASE_AOE_RADIUS := {1: 3.2, 2: 3.9, 3: 4.6}


static func phase_interval(phase: int) -> float:
	return float(PHASE_AOE_INTERVAL.get(phase, 7.5))


static func phase_radius(phase: int) -> float:
	return float(PHASE_AOE_RADIUS.get(phase, 3.2))


## Especie del guardián de ese bioma: entre las 5 más fuertes de su tipo (evolución
## final si existe alguna), al azar según seed_value (semilla de la región + bioma).
## excluded: identificadores ya usados por otro guardián de la misma región.
static func guardian_species(biome: int, seed_value: int, excluded: Array[String] = []) -> SpeciesData:
	if not GUARDIAN_TYPE.has(biome):
		return null
	var type: int = GUARDIAN_TYPE[biome]
	var options: Array[SpeciesData] = []
	for species: SpeciesData in WildSpawner.ALL_SPECIES.species:
		if species.types.has(type) and not species.is_legendary and not species.is_mythical and not excluded.has(species.identifier):
			options.append(species)
	if options.is_empty():
		return null
	options.sort_custom(func(a: SpeciesData, b: SpeciesData) -> bool: return a.base_total > b.base_total)
	var finals := options.filter(func(s: SpeciesData) -> bool: return s.evolution_stage >= 2)
	var pool := finals if not finals.is_empty() else options
	var top := pool.slice(0, mini(5, pool.size()))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return top[rng.randi() % top.size()]


## Objeto clave de recuerdo (uno por bioma, registrado en Items al cargar).
static func crest_item_id(biome: int) -> String:
	return "guardian-crest-%d" % biome


static func crest_item_name(biome: int) -> String:
	return "Insignia del Guardián de %s" % RegionLayout.BIOME_NAMES[biome]


## Premio único al vencerlo: la insignia de recuerdo y una piedra (o Caramelo Raro).
static func reward_items(biome: int) -> Array[String]:
	var type: int = GUARDIAN_TYPE.get(biome, T.NORMAL)
	var stone: String = STONE_FOR_TYPE.get(type, "")
	var items: Array[String] = [crest_item_id(biome)]
	items.append(stone if stone != "" else "rare-candy")
	return items


static func reward_money(region: int) -> int:
	return 2000 + region * 600


# --- Registro por región (GameState.world_flags, ya es por región) ----------------------

static func _flags() -> Dictionary:
	if not GameState.world_flags.has("bosses"):
		GameState.world_flags["bosses"] = {"defeated": []}
	return GameState.world_flags["bosses"]


static func is_defeated(biome: int) -> bool:
	return (_flags().get("defeated", []) as Array).has(biome)


static func mark_defeated(biome: int) -> void:
	var list: Array = _flags()["defeated"]
	if not list.has(biome):
		list.append(biome)


# --- Geometría de los ataques en área (círculos y líneas que se esquivan) ---------------

static func circle_hit(point: Vector3, center: Vector3, radius: float) -> bool:
	return Vector2(point.x - center.x, point.z - center.z).length() <= radius


## ¿point está a menos de half_width del segmento from-to? (ataque en línea).
static func segment_hit(point: Vector3, from: Vector3, to: Vector3, half_width: float) -> bool:
	var dir := to - from
	var length_sq := dir.length_squared()
	if length_sq < 0.0001:
		return point.distance_to(from) <= half_width
	var t := clampf((point - from).dot(dir) / length_sq, 0.0, 1.0)
	var closest: Vector3 = from + dir * t
	return point.distance_to(closest) <= half_width
