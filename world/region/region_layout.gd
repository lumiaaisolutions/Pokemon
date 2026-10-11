class_name RegionLayout
extends RefCounted
## Región de 4 × 4 km generada con la semilla de la partida: clima (temperatura y
## humedad) y altura deciden el bioma; ríos que bajan de las montañas al mar, lagos en
## las hondonadas, mar con islas al sur, cordillera en los demás bordes; pueblos y
## ciudades unidos por caminos, y lugares especiales (ruinas, cuevas, santuarios…).
## Todo son funciones puras de (x, z): las usan el terreno por zonas, el mapa, la
## navegación y la aparición de Pokémon. Ejes: +X este, +Z sur.

enum Biome { MEADOW, FOREST, MOUNTAIN, BEACH, DESERT, CANYON, SAVANNA, JUNGLE, TUNDRA, VOLCANO,
	FLOWERS, MUSHROOM, DARK_FOREST, SWAMP, TOXIC_SWAMP, MESA, SEA }

const BIOME_NAMES := ["Pradera", "Bosque", "Montaña", "Costa", "Desierto", "Cañón", "Sabana", "Selva", "Tundra",
	"Volcán", "Campo de flores", "Bosque de hongos", "Bosque oscuro", "Pantano", "Pantano tóxico", "Mesetas", "Mar"]
## Familia de textura del suelo de cada bioma: 0 pasto, 1 bosque, 2 roca, 3 arena, 4 pantano.
const FAMILY := [0, 1, 2, 3, 3, 2, 0, 1, 2, 2, 0, 1, 1, 4, 4, 2, 3]
## Tinte del suelo por bioma (pantano: verde oliva oscuro; pantano tóxico: morado
## apagado, para que se note el bioma, pedido de Fernando el 2026-10-10).
const TINT := [Color(1, 1, 1), Color(1, 1, 1), Color(1, 1, 1), Color(1, 1, 1), Color(1.08, 0.98, 0.78),
	Color(1.15, 0.72, 0.55), Color(1.12, 1.0, 0.62), Color(0.78, 1.0, 0.75), Color(0.92, 0.97, 1.08),
	Color(0.55, 0.5, 0.5), Color(1.05, 1.0, 0.95), Color(0.92, 0.82, 1.05), Color(0.62, 0.7, 0.7),
	Color(0.72, 0.78, 0.55), Color(0.72, 0.55, 0.85), Color(1.1, 0.78, 0.6), Color(1, 1, 1)]
## Hábitat de Pokémon de cada bioma (los de SpeciesData).
const HABITAT := [SpeciesData.Habitat.MEADOW, SpeciesData.Habitat.FOREST, SpeciesData.Habitat.MOUNTAIN, SpeciesData.Habitat.SEA,
	SpeciesData.Habitat.MOUNTAIN, SpeciesData.Habitat.MOUNTAIN, SpeciesData.Habitat.MEADOW, SpeciesData.Habitat.FOREST,
	SpeciesData.Habitat.MOUNTAIN, SpeciesData.Habitat.MOUNTAIN, SpeciesData.Habitat.MEADOW, SpeciesData.Habitat.FOREST,
	SpeciesData.Habitat.FOREST, SpeciesData.Habitat.SWAMP, SpeciesData.Habitat.SWAMP, SpeciesData.Habitat.MOUNTAIN, SpeciesData.Habitat.SEA]
## Afinidad de tipos por bioma (peso extra al aparecer): bioma -> {tipo: factor}.
const TYPE_AFFINITY := {
	Biome.DESERT: {PokemonTypes.Type.GROUND: 4.0, PokemonTypes.Type.ROCK: 3.0, PokemonTypes.Type.FIRE: 2.0, PokemonTypes.Type.WATER: 0.05, PokemonTypes.Type.GRASS: 0.2},
	Biome.CANYON: {PokemonTypes.Type.ROCK: 4.0, PokemonTypes.Type.GROUND: 3.0, PokemonTypes.Type.FIGHTING: 2.0},
	Biome.SAVANNA: {PokemonTypes.Type.NORMAL: 3.0, PokemonTypes.Type.GROUND: 2.0, PokemonTypes.Type.FIRE: 2.0, PokemonTypes.Type.ELECTRIC: 1.5},
	Biome.JUNGLE: {PokemonTypes.Type.GRASS: 3.0, PokemonTypes.Type.BUG: 3.0, PokemonTypes.Type.POISON: 1.5},
	Biome.TUNDRA: {PokemonTypes.Type.ICE: 8.0, PokemonTypes.Type.WATER: 1.5, PokemonTypes.Type.FIRE: 0.05},
	Biome.VOLCANO: {PokemonTypes.Type.FIRE: 8.0, PokemonTypes.Type.ROCK: 2.0, PokemonTypes.Type.GROUND: 2.0, PokemonTypes.Type.ICE: 0.02, PokemonTypes.Type.GRASS: 0.05},
	Biome.FLOWERS: {PokemonTypes.Type.FAIRY: 5.0, PokemonTypes.Type.BUG: 3.0, PokemonTypes.Type.GRASS: 2.0},
	Biome.MUSHROOM: {PokemonTypes.Type.GRASS: 3.0, PokemonTypes.Type.FAIRY: 3.0, PokemonTypes.Type.POISON: 3.0, PokemonTypes.Type.BUG: 2.0},
	Biome.DARK_FOREST: {PokemonTypes.Type.GHOST: 5.0, PokemonTypes.Type.DARK: 5.0, PokemonTypes.Type.POISON: 2.0},
	Biome.TOXIC_SWAMP: {PokemonTypes.Type.POISON: 6.0, PokemonTypes.Type.GHOST: 2.0},
	Biome.MESA: {PokemonTypes.Type.ROCK: 3.0, PokemonTypes.Type.FLYING: 3.0, PokemonTypes.Type.GROUND: 2.0},
}

var size := 4096.0
var seed := 1
var sea_level := -1.5
## Ríos: cada uno es {"points": PackedVector2Array, "levels": PackedFloat32Array, "width": float}.
var rivers: Array[Dictionary] = []
## Lagos: Vector4(x, z, radio, nivel).
var lakes: Array[Vector4] = []
## Asentamientos: {"name", "kind" (city/town/village/cabins), "x", "z", "radius", "buildings": [...]}.
var settlements: Array[Dictionary] = []
## Caminos entre asentamientos: Array de PackedVector2Array (y su tipo de pavimento).
var roads: Array[PackedVector2Array] = []
var road_kinds: PackedInt32Array = PackedInt32Array()
## Lugares especiales: {"kind", "name", "x", "z", "radius", ...}.
var places: Array[Dictionary] = []
## Punto de inicio (en el pueblo inicial).
var start := Vector2.ZERO

var _continent := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _temperature := FastNoiseLite.new()
var _moisture := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _special := FastNoiseLite.new()
## Índices espaciales (celdas de BUCKET m): segmentos de río y de camino, lagos y lugares.
const BUCKET := 256.0
var _river_buckets := {}
var _road_buckets := {}
var _flat_buckets := {}
var _lake_buckets := {}
## Lago -> congelado (tundra): su superficie es hielo plano y no hay agua.
var _frozen := {}
## Ancho de la costa sur y de la franja de montaña del borde.
const SEA_BAND := 520.0
const EDGE_MOUNTAIN := 260.0
const RIVER_BANK := 7.0
const LAKE_BANK := 10.0
const WATER_EDGE := 0.92
const ROAD_WIDTH := 3.2
const TOWN_NAMES := ["Pueblo Raíz", "Ciudad Aurora", "Villa Musgo", "Pueblo Brisa", "Ciudad Coral", "Aldea Ceniza", "Pueblo Escarcha",
	"Ciudad Ámbar", "Villa Rocío", "Pueblo Duna", "Ciudad Arrecife", "Aldea Hongo", "Pueblo Ocaso", "Ciudad Cumbre", "Villa Pétalo", "Pueblo Lumen"]


func _init(world_seed: int, world_size: float = 4096.0) -> void:
	seed = world_seed
	size = world_size
	_setup_noise(_continent, seed, 0.00035, 4)
	_setup_noise(_ridge, seed + 11, 0.0011, 4)
	_setup_noise(_detail, seed + 17, 0.012, 3)
	_setup_noise(_temperature, seed + 23, 0.00045, 2)
	_setup_noise(_moisture, seed + 31, 0.0006, 2)
	_setup_noise(_warp, seed + 41, 0.003, 2)
	_setup_noise(_special, seed + 53, 0.0025, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 2654435761 + 7
	_place_volcanoes(rng)
	_place_lakes(rng)
	_trace_rivers(rng)
	_place_settlements(rng)
	_connect_roads(rng)
	_place_places(rng)
	# Lagos congelados en la tundra (hielo que se puede pisar).
	for lake in lakes:
		_frozen[lake] = biome_at(lake.x, lake.y) == Biome.TUNDRA


static func _setup_noise(noise: FastNoiseLite, noise_seed: int, frequency: float, octaves: int) -> void:
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.fractal_octaves = octaves


# --- Clima, bioma y altura -----------------------------------------------------------

## 0 en el centro, 1 en el borde (para la costa y la cordillera).
func _edge(x: float, z: float) -> Dictionary:
	var half := size * 0.5
	var warp := _warp.get_noise_2d(x, z) * 60.0
	return {"south": smoothstep(half - SEA_BAND - 120.0, half - SEA_BAND + 120.0, z + warp),
			"rim": smoothstep(half - EDGE_MOUNTAIN, half, maxf(absf(x), -z) + warp)}


## Temperatura (0 frío a 1 calor): más fría al norte y con la altura.
func temperature_at(x: float, z: float) -> float:
	var t := 0.5 + _temperature.get_noise_2d(x, z) * 0.6 + (z / size) * 0.3
	return clampf(t, 0.0, 1.0)


func moisture_at(x: float, z: float) -> float:
	return clampf(0.5 + _moisture.get_noise_2d(x, z) * 0.7, 0.0, 1.0)


## Altura base sin agua ni allanados.
func base_height(x: float, z: float) -> float:
	var edge := _edge(x, z)
	var continent := _continent.get_noise_2d(x, z)
	var ridge := 1.0 - absf(_ridge.get_noise_2d(x, z))
	var mountainous := smoothstep(0.05, 0.45, continent)
	var h := 6.0 + continent * 18.0 + _detail.get_noise_2d(x, z) * 3.0
	# Tierra adentro nunca baja del nivel del mar (las hondonadas quedan como lagos).
	if h < 2.0:
		h = 2.0 - (2.0 - h) * 0.05
	h += ridge * ridge * 70.0 * mountainous
	# Mesetas: escalones en zonas secas y templadas.
	if _is_mesa(x, z):
		h = maxf(h, 18.0 + floorf((h + 8.0) / 9.0) * 9.0)
	# Volcanes: conos con cráter.
	for place in _volcano_cones:
		var d := Vector2(x - place.x, z - place.y).length()
		if d < place.z:
			var cone := (1.0 - d / place.z) * 85.0
			h = maxf(h, cone - (12.0 if d < place.z * 0.15 else 0.0))
	# Costa sur: el terreno baja al fondo del mar.
	h = lerpf(h, sea_level - 8.0, float(edge["south"]))
	# Islas del archipiélago en el mar.
	if float(edge["south"]) > 0.6:
		var island := _special.get_noise_2d(x * 1.5, z * 1.5)
		if island > 0.45:
			h = maxf(h, sea_level + (island - 0.45) * 40.0)
	# Cordillera del borde (norte, este y oeste).
	h += float(edge["rim"]) * 90.0 * (1.0 - float(edge["south"]))
	return h


func _is_mesa(x: float, z: float) -> bool:
	return temperature_at(x, z) > 0.62 and moisture_at(x, z) < 0.35 and _special.get_noise_2d(x + 999.0, z) > 0.35


## Conos de volcán: Vector3(x, z, radio). Se generan con los lugares.
var _volcano_cones: Array[Vector3] = []


func biome_at(x: float, z: float) -> Biome:
	var edge := _edge(x, z)
	if float(edge["south"]) > 0.55:
		var island_h := base_height(x, z)
		return Biome.SEA if island_h < sea_level else Biome.BEACH
	if float(edge["south"]) > 0.35:
		return Biome.BEACH
	for cone in _volcano_cones:
		if Vector2(x - cone.x, z - cone.y).length() < cone.z * 0.8:
			return Biome.VOLCANO
	var h := base_height(x, z)
	var t := temperature_at(x, z) - maxf(h - 30.0, 0.0) * 0.006
	var m := moisture_at(x, z)
	var special := _special.get_noise_2d(x, z)
	if h > 42.0 or float(edge["rim"]) > 0.4:
		return Biome.TUNDRA if t < 0.22 else Biome.MOUNTAIN
	if _is_mesa(x, z):
		return Biome.MESA
	if t < 0.2:
		return Biome.TUNDRA
	if t > 0.68:
		if m < 0.3:
			return Biome.CANYON if special > 0.25 else Biome.DESERT
		if m < 0.55:
			return Biome.SAVANNA
		return Biome.JUNGLE
	if m > 0.72:
		if h < 10.0:
			return Biome.TOXIC_SWAMP if special > 0.4 else Biome.SWAMP
		return Biome.MUSHROOM if special > 0.3 else Biome.DARK_FOREST
	if m > 0.52:
		return Biome.FOREST
	if special > 0.42:
		return Biome.FLOWERS
	return Biome.MEADOW


## Altura final con ríos, lagos, asentamientos y caminos (sin las charcas del
## pantano, que agrega el terreno por zonas).
func height_at(x: float, z: float) -> float:
	var h := base_height(x, z)
	var flat := _flatten_info(x, z)
	if flat.x > 0.0:
		h = lerpf(h, flat.y, flat.x)
	var river := river_info(x, z)
	if river.x < INF:
		h = _carve(h, river.x, river.z * 0.5, RIVER_BANK, river.y, 2.0, 0.8)
	for lake in _lakes_near(x, z):
		var d := Vector2(x - lake.x, z - lake.y).length()
		if _frozen.get(lake, false):
			# Hielo: el lago queda plano a su nivel.
			h = _carve(h, d, lake.z, LAKE_BANK, lake.w + 0.05, 0.0, 0.8)
		else:
			h = _carve(h, d, lake.z, LAKE_BANK, lake.w, 3.0, 0.8)
	return h


static func _carve(h: float, d: float, radius: float, bank: float, level: float, depth: float, rise: float) -> float:
	if d >= radius + bank:
		return h
	var t := smoothstep(radius, radius + bank, d)
	return lerpf(level - depth, maxf(h, level + rise), t)


## Allanado de asentamientos y caminos: Vector2(peso, altura objetivo).
func _flatten_info(x: float, z: float) -> Vector2:
	var best := Vector2(0.0, 0.0)
	for s in _flat_buckets.get(_bucket(x, z), []):
		var d := Vector2(x - float(s["x"]), z - float(s["z"])).length()
		var radius := float(s["radius"])
		if d < radius + 20.0:
			var w := 1.0 - smoothstep(radius, radius + 20.0, d)
			if w > best.x:
				best = Vector2(w, float(s["height"]))
	var road := road_info(x, z)
	if road.x < ROAD_WIDTH + 4.0:
		var w := (1.0 - smoothstep(ROAD_WIDTH * 0.5, ROAD_WIDTH + 4.0, road.x)) * 0.6
		if w > best.x:
			best = Vector2(w, road.y)
	return best


# --- Agua -----------------------------------------------------------------------------

## Río más cercano: Vector3(distancia, nivel, ancho); distancia INF si no hay cerca.
func river_info(x: float, z: float) -> Vector3:
	var point := Vector2(x, z)
	var best := Vector3(INF, 0.0, 0.0)
	for entry: Array in _river_buckets.get(_bucket(x, z), []):
		var river: Dictionary = rivers[entry[0]]
		var i: int = entry[1]
		var pts: PackedVector2Array = river["points"]
		var a := pts[i]
		var b := pts[i + 1]
		var ab := b - a
		var t := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := point.distance_to(a + ab * t)
		if d < best.x:
			var levels: PackedFloat32Array = river["levels"]
			best = Vector3(d, lerpf(levels[i], levels[i + 1], t), float(river["width"]))
	return best


func _lakes_near(x: float, z: float) -> Array:
	return _lake_buckets.get(_bucket(x, z), [])


## Nivel del agua (ríos, lagos y mar; las charcas las agrega el terreno).
func water_level_at(x: float, z: float) -> float:
	var level := sea_level
	var river := river_info(x, z)
	if river.x < river.z * 0.5 + RIVER_BANK * WATER_EDGE:
		level = maxf(level, river.y)
	for lake in _lakes_near(x, z):
		if not _frozen.get(lake, false) and Vector2(x - lake.x, z - lake.y).length() < lake.z + LAKE_BANK * WATER_EDGE:
			level = maxf(level, lake.w)
	return level


## Volcanes primero: cambian la altura de su zona (y con ella ríos, lagos y pueblos).
func _place_volcanoes(rng: RandomNumberGenerator) -> void:
	var half := size * 0.5 - EDGE_MOUNTAIN - 200.0
	var attempts := 0
	while _volcano_cones.size() < 2 and attempts < 300:
		attempts += 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half - SEA_BAND)
		if temperature_at(x, z) < 0.5 or Vector2(x, z).length() < 600.0:
			continue
		if _volcano_cones.any(func(c: Vector3) -> bool: return Vector2(c.x, c.y).distance_to(Vector2(x, z)) < 900.0):
			continue
		var radius := rng.randf_range(110.0, 160.0)
		_volcano_cones.append(Vector3(x, z, radius))
		places.append({"kind": "volcano", "x": x, "z": z, "radius": radius, "id": places.size()})


func _place_lakes(rng: RandomNumberGenerator) -> void:
	var half := size * 0.5 - EDGE_MOUNTAIN - 100.0
	var attempts := 0
	while lakes.size() < 9 and attempts < 400:
		attempts += 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half - SEA_BAND)
		var h := base_height(x, z)
		if h < 2.0 or h > 30.0:
			continue
		# Hondonada: más baja que sus alrededores.
		var around := 0.0
		for i in 8:
			var angle := TAU * i / 8.0
			around += base_height(x + cos(angle) * 60.0, z + sin(angle) * 60.0)
		if h > around / 8.0 - 1.0:
			continue
		if lakes.any(func(l: Vector4) -> bool: return Vector2(l.x, l.y).distance_to(Vector2(x, z)) < 350.0):
			continue
		var radius := rng.randf_range(22.0, 55.0)
		lakes.append(Vector4(x, z, radius, h - 1.0))
	# Oasis: lagos pequeños en el desierto (sin necesidad de hondonada).
	var oasis := 0
	attempts = 0
	while oasis < 2 and attempts < 600:
		attempts += 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half - SEA_BAND)
		var h := base_height(x, z)
		if biome_at(x, z) != Biome.DESERT or h < 3.0 or h > 30.0:
			continue
		if lakes.any(func(l: Vector4) -> bool: return Vector2(l.x, l.y).distance_to(Vector2(x, z)) < 300.0):
			continue
		lakes.append(Vector4(x, z, rng.randf_range(12.0, 18.0), h - 1.0))
		places.append({"kind": "oasis", "x": x, "z": z, "radius": 30.0, "id": places.size()})
		oasis += 1
	for lake in lakes:
		_index_circle(_lake_buckets, lake, Vector2(lake.x, lake.y), lake.z + LAKE_BANK)


## Ríos: nacen en las montañas y bajan siguiendo la pendiente hasta el mar o un lago.
func _trace_rivers(rng: RandomNumberGenerator) -> void:
	var half := size * 0.5 - EDGE_MOUNTAIN
	var attempts := 0
	while rivers.size() < 6 and attempts < 200:
		attempts += 1
		var p := Vector2(rng.randf_range(-half, half), rng.randf_range(-half - 100.0, size * 0.1))
		if base_height(p.x, p.y) < 24.0:
			continue
		var points := PackedVector2Array([p])
		var levels := PackedFloat32Array([base_height(p.x, p.y) - 1.5])
		var direction := Vector2(0, 1)
		for step in 260:
			# Hacia abajo, con algo de inercia y un empujón hacia el mar (sur).
			var best := p + direction * 24.0
			var best_h := INF
			for k in 7:
				var angle := direction.angle() + (k - 3) * 0.32
				var candidate := p + Vector2(cos(angle), sin(angle)) * 24.0
				var hh := base_height(candidate.x, candidate.y) - candidate.y * 0.025
				if hh < best_h:
					best_h = hh
					best = candidate
			direction = (best - p).normalized()
			p = best
			# Hondonada sin salida (el río da vueltas): termina en un lago nuevo.
			var looped := false
			for k in range(0, points.size() - 8):
				if points[k].distance_to(p) < 30.0:
					looped = true
					break
			if looped:
				if not lakes.any(func(l: Vector4) -> bool: return Vector2(l.x, l.y).distance_to(p) < l.z + 40.0):
					var lake := Vector4(p.x, p.y, rng.randf_range(24.0, 36.0), levels[-1])
					lakes.append(lake)
					_index_circle(_lake_buckets, lake, p, lake.z + LAKE_BANK)
				break
			var level := minf(levels[-1], base_height(p.x, p.y) - 1.0)
			points.append(p)
			levels.append(maxf(level, sea_level))
			if level <= sea_level + 0.2 or _edge(p.x, p.y)["south"] > 0.6:
				break
			if absf(p.x) > size * 0.5 - 100.0 or absf(p.y) > size * 0.5 - 100.0:
				break
		if points.size() < 12:
			continue
		var width := rng.randf_range(6.0, 11.0)
		rivers.append({"points": points, "levels": levels, "width": width})
	for r in rivers.size():
		var pts: PackedVector2Array = rivers[r]["points"]
		for i in pts.size() - 1:
			var margin := float(rivers[r]["width"]) * 0.5 + RIVER_BANK + 4.0
			for key in _segment_buckets(pts[i], pts[i + 1], margin):
				if not _river_buckets.has(key):
					_river_buckets[key] = []
				(_river_buckets[key] as Array).append([r, i])


# --- Asentamientos, caminos y lugares --------------------------------------------------

func _place_settlements(rng: RandomNumberGenerator) -> void:
	var half := size * 0.5 - EDGE_MOUNTAIN - 150.0
	# Pueblo inicial cerca del centro.
	var kinds := ["town", "city", "city", "town", "town", "village", "village", "town", "city", "village", "cabins", "cabins", "town"]
	var attempts := 0
	while settlements.size() < kinds.size() and attempts < 3000:
		attempts += 1
		var x := rng.randf_range(-half, half) if not settlements.is_empty() else rng.randf_range(-200.0, 200.0)
		var z := rng.randf_range(-half, half - SEA_BAND * 0.6) if not settlements.is_empty() else rng.randf_range(-200.0, 200.0)
		var biome := biome_at(x, z)
		if biome in [Biome.SEA, Biome.MOUNTAIN, Biome.TUNDRA, Biome.VOLCANO, Biome.CANYON] and not settlements.is_empty():
			continue
		var h := base_height(x, z)
		if h < sea_level + 2.0 or h > 40.0:
			continue
		if _slope(x, z, 40.0) > 14.0:
			continue
		if settlements.any(func(s: Dictionary) -> bool: return Vector2(float(s["x"]), float(s["z"])).distance_to(Vector2(x, z)) < 520.0):
			continue
		if lakes.any(func(l: Vector4) -> bool: return Vector2(l.x, l.y).distance_to(Vector2(x, z)) < l.z + 80.0):
			continue
		var kind: String = kinds[settlements.size()]
		var radius: float = {"city": 90.0, "town": 60.0, "village": 40.0, "cabins": 28.0}[kind]
		var settlement := {"name": TOWN_NAMES[settlements.size() % TOWN_NAMES.size()], "kind": kind, "x": x, "z": z,
				"radius": radius, "height": maxf(h, sea_level + 1.5), "biome": biome}
		settlement["buildings"] = _plan_buildings(settlement, rng)
		settlements.append(settlement)
	# 8 gimnasios por región (ver Regions): ciudades y pueblos; si faltan, en aldeas.
	var gyms := settlements.filter(func(s: Dictionary) -> bool: return s["kind"] in ["city", "town"]).size()
	for s: Dictionary in settlements:
		if gyms >= 8:
			break
		if s["kind"] == "village":
			s["gym"] = true
			s["buildings"] = _plan_buildings(s, rng)
			gyms += 1
	if not settlements.is_empty():
		# En la plaza del pueblo inicial (los edificios quedan a más de 10 m).
		start = Vector2(float(settlements[0]["x"]), float(settlements[0]["z"]) + 2.0)
	for s in settlements:
		_index_circle(_flat_buckets, s, Vector2(float(s["x"]), float(s["z"])), float(s["radius"]) + 24.0)


func _slope(x: float, z: float, d: float) -> float:
	var h := base_height(x, z)
	var worst := 0.0
	for i in 4:
		var angle := TAU * i / 4.0
		worst = maxf(worst, absf(base_height(x + cos(angle) * d, z + sin(angle) * d) - h))
	return worst


## Edificios de un asentamiento: Centro Pokémon y tienda en pueblos y ciudades,
## gimnasio en ciudades, laboratorio en el pueblo inicial, casas, cabañas o carpas.
func _plan_buildings(settlement: Dictionary, rng: RandomNumberGenerator) -> Array:
	var list: Array = []
	var kind: String = settlement["kind"]
	var cx := float(settlement["x"])
	var cz := float(settlement["z"])
	var radius := float(settlement["radius"])
	var wanted: Array = []
	match kind:
		"city":
			wanted = ["center", "mart", "gym", "contest", "restaurant", "food_stall", "house", "house", "house", "house", "house", "house", "tower_small", "manhole"]
		"town":
			wanted = ["center", "mart", "gym", "food_stall", "house", "house", "house", "house"]
			if settlements.is_empty():
				wanted.append("lab")
		"village":
			wanted = ["center", "house", "house", "cabin"]
			if settlement.get("gym", false):
				wanted.append("gym")
		"cabins":
			wanted = ["cabin", "cabin", "tent", "tent"]
	for i in wanted.size():
		var angle := TAU * i / wanted.size() + rng.randf_range(-0.2, 0.2)
		var distance := radius * rng.randf_range(0.45, 0.8)
		if wanted[i] in ["center", "mart"]:
			distance = radius * 0.32
		var footprint: Vector2 = {"center": Vector2(14, 11), "mart": Vector2(11, 9), "gym": Vector2(20, 18), "contest": Vector2(18, 14),
				"restaurant": Vector2(15, 9), "food_stall": Vector2(15, 8),
				"lab": Vector2(16, 11), "house": Vector2(9, 8), "cabin": Vector2(7, 6), "tent": Vector2(5, 5), "tower_small": Vector2(8, 8), "manhole": Vector2(2, 2)}[wanted[i]]
		list.append({"kind": wanted[i], "x": cx + cos(angle) * distance, "z": cz + sin(angle) * distance,
				"w": footprint.x, "d": footprint.y, "facing": angle + PI, "color": rng.randi() % 6})
	return list


## Caminos: árbol de expansión mínima entre asentamientos más algunos extra.
func _connect_roads(rng: RandomNumberGenerator) -> void:
	if settlements.size() < 2:
		return
	var connected := [0]
	var pending := range(1, settlements.size())
	while not pending.is_empty():
		var best := [-1, -1, INF]
		for a: int in connected:
			for b: int in pending:
				var d := _settlement_pos(a).distance_to(_settlement_pos(b))
				if d < best[2]:
					best = [a, b, d]
		_add_road(_settlement_pos(best[0]), _settlement_pos(best[1]), rng)
		connected.append(best[1])
		pending.erase(best[1])
	for extra in 3:
		var a := rng.randi() % settlements.size()
		var b := rng.randi() % settlements.size()
		if a != b:
			_add_road(_settlement_pos(a), _settlement_pos(b), rng)


func _settlement_pos(i: int) -> Vector2:
	return Vector2(float(settlements[i]["x"]), float(settlements[i]["z"]))


## Camino con curvas suaves (desvío por ruido); pavimento según los pueblos que une.
func _add_road(a: Vector2, b: Vector2, rng: RandomNumberGenerator) -> void:
	var points := PackedVector2Array()
	var steps := maxi(int(a.distance_to(b) / 30.0), 2)
	var normal := (b - a).normalized().orthogonal()
	var bend := rng.randf_range(-0.15, 0.15) * a.distance_to(b)
	for i in steps + 1:
		var t := float(i) / steps
		var p := a.lerp(b, t) + normal * sin(t * PI) * bend
		p += Vector2(_warp.get_noise_2d(p.x, p.y), _warp.get_noise_2d(p.y, p.x)) * 25.0 * sin(t * PI)
		points.append(p)
	roads.append(points)
	road_kinds.append(rng.randi() % 3)
	var r := roads.size() - 1
	for i in points.size() - 1:
		for key in _segment_buckets(points[i], points[i + 1], ROAD_WIDTH + 6.0):
			if not _road_buckets.has(key):
				_road_buckets[key] = []
			(_road_buckets[key] as Array).append([r, i])


## Distancia al camino más cercano y la altura del suelo ahí: Vector2(distancia, altura).
func road_info(x: float, z: float) -> Vector2:
	var point := Vector2(x, z)
	var best := Vector2(INF, 0.0)
	for entry: Array in _road_buckets.get(_bucket(x, z), []):
		var pts: PackedVector2Array = roads[entry[0]]
		var a := pts[entry[1]]
		var b := pts[entry[1] + 1]
		var ab := b - a
		var t := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var closest := a + ab * t
		var d := point.distance_to(closest)
		if d < best.x:
			best = Vector2(d, maxf(base_height(closest.x, closest.y), sea_level + 1.0))
	return best


## Lugares especiales repartidos por la región (ver docs/sistemas/mundo_grande.md).
func _place_places(rng: RandomNumberGenerator) -> void:
	# Hasta dentro de la cordillera del borde (ahí van muchas cuevas y la Liga).
	var half := size * 0.5 - 140.0
	var wanted := [
		["ruins", 5], ["cave", 8], ["sanctuary", 8], ["tower", 1], ["mansion", 1], ["power_plant", 1],
		["shipwreck", 2], ["lighthouse", 2], ["lab_ruins", 1], ["giant_tree", 1], ["league", 1], ["floating_ruins", 2],
		["portal", 2], ["safari", 1], ["daycare", 1], ["hot_spring", 4], ["alpha", 8], ["fountain", 3],
		["ranch", 3], ["berry_farm", 3], ["mine", 2], ["grotto", 6], ["villain_base", 1],
	]
	for entry: Array in wanted:
		var placed := 0
		var attempts := 0
		while placed < int(entry[1]) and attempts < 600:
			attempts += 1
			var x := rng.randf_range(-half, half)
			var z := rng.randf_range(-half, half)
			if not _place_ok(entry[0], x, z):
				continue
			if places.any(func(p: Dictionary) -> bool: return Vector2(float(p["x"]), float(p["z"])).distance_to(Vector2(x, z)) < 140.0):
				continue
			if settlements.any(func(s: Dictionary) -> bool: return Vector2(float(s["x"]), float(s["z"])).distance_to(Vector2(x, z)) < float(s["radius"]) + 60.0):
				continue
			places.append({"kind": entry[0], "x": x, "z": z, "radius": 18.0, "id": places.size()})
			placed += 1
	# Cumbre: el punto más alto (fuera de la cordillera del borde) es un santuario.
	var summit := Vector3(0, -INF, 0)
	var inner := size * 0.5 - EDGE_MOUNTAIN - 60.0
	for i in 2500:
		var sx := rng.randf_range(-inner, inner)
		var sz := rng.randf_range(-inner, inner - SEA_BAND)
		var sh := base_height(sx, sz)
		if sh > summit.y:
			summit = Vector3(sx, sh, sz)
	places.append({"kind": "sanctuary", "summit": true, "name": "Santuario de la Cumbre", "x": summit.x, "z": summit.z, "radius": 18.0, "id": places.size()})
	# Los santuarios tienen una explanada plana (cuentan como lugar allanado).
	for place in places:
		if place["kind"] == "sanctuary":
			var flat := {"name": place.get("name", "Santuario"), "kind": "sanctuary", "x": place["x"], "z": place["z"], "radius": 22.0,
					"height": maxf(base_height(float(place["x"]), float(place["z"])), sea_level + 1.5)}
			_index_circle(_flat_buckets, flat, Vector2(float(place["x"]), float(place["z"])), 22.0 + 24.0)
	# Calle Victoria: una cueva a unos cientos de metros de la Liga que sale frente a ella.
	for league: Dictionary in places_of("league"):
		for attempt in 300:
			var angle := rng.randf() * TAU
			var distance := rng.randf_range(160.0, 320.0)
			var x := float(league["x"]) + cos(angle) * distance
			var z := float(league["z"]) + sin(angle) * distance
			if absf(x) > half or absf(z) > half or biome_at(x, z) == Biome.SEA or base_height(x, z) < sea_level + 2.0:
				continue
			places.append({"kind": "victory_road", "x": x, "z": z, "radius": 18.0, "id": places.size()})
			break
	# Comerciantes en los caminos (lejos de los pueblos).
	var merchants := 0
	for attempt in 400:
		if merchants >= 4 or roads.is_empty():
			break
		var road: PackedVector2Array = roads[rng.randi() % roads.size()]
		var p := road[rng.randi() % road.size()]
		if settlements.any(func(s: Dictionary) -> bool: return Vector2(float(s["x"]), float(s["z"])).distance_to(p) < float(s["radius"]) + 120.0):
			continue
		if places.any(func(q: Dictionary) -> bool: return Vector2(float(q["x"]), float(q["z"])).distance_to(p) < 100.0):
			continue
		places.append({"kind": "merchant", "x": p.x + 5.0, "z": p.y + 5.0, "radius": 6.0, "id": places.size()})
		merchants += 1
	# Las cuevas van por pares: cada entrada lleva a otra lejana.
	var caves := places.filter(func(p: Dictionary) -> bool: return p["kind"] == "cave")
	for i in range(0, caves.size() - 1, 2):
		caves[i]["exit"] = caves[i + 1]["id"]
		caves[i + 1]["exit"] = caves[i]["id"]


func _place_ok(kind: String, x: float, z: float) -> bool:
	var biome := biome_at(x, z)
	var h := base_height(x, z)
	match kind:
		"volcano":
			return biome in [Biome.MOUNTAIN, Biome.DESERT, Biome.SAVANNA, Biome.CANYON] and h < 50.0
		"shipwreck":
			return biome == Biome.SEA
		"lighthouse":
			return biome == Biome.BEACH
		"cave", "league":
			return h > 20.0 and h < 120.0 and biome in [Biome.MOUNTAIN, Biome.TUNDRA, Biome.CANYON, Biome.MESA]
		"hot_spring":
			return biome in [Biome.MOUNTAIN, Biome.VOLCANO, Biome.TUNDRA] and h < 60.0
		"giant_tree":
			return biome in [Biome.FOREST, Biome.JUNGLE]
		"mansion":
			return biome in [Biome.DARK_FOREST, Biome.FOREST, Biome.SWAMP]
		"floating_ruins", "portal":
			return biome != Biome.SEA
		"ranch", "berry_farm":
			return biome in [Biome.MEADOW, Biome.SAVANNA, Biome.FLOWERS] and h < 30.0 and _slope(x, z, 20.0) < 4.0
		"mine", "grotto":
			return biome in [Biome.MOUNTAIN, Biome.CANYON, Biome.MESA, Biome.TUNDRA] and h > 15.0 and h < 90.0
		"villain_base":
			return biome in [Biome.DARK_FOREST, Biome.SWAMP, Biome.TOXIC_SWAMP, Biome.VOLCANO, Biome.CANYON, Biome.FOREST] and h > sea_level + 2.0
		_:
			return biome != Biome.SEA and h > sea_level + 1.0 and h < 45.0


## Lugares de un tipo.
func places_of(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for place in places:
		if place["kind"] == kind:
			result.append(place)
	return result


# --- Índices espaciales -------------------------------------------------------------

func _bucket(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / BUCKET), floori(z / BUCKET))


func _segment_buckets(a: Vector2, b: Vector2, margin: float) -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	var lo := Vector2(minf(a.x, b.x) - margin, minf(a.y, b.y) - margin)
	var hi := Vector2(maxf(a.x, b.x) + margin, maxf(a.y, b.y) + margin)
	for bx in range(floori(lo.x / BUCKET), floori(hi.x / BUCKET) + 1):
		for bz in range(floori(lo.y / BUCKET), floori(hi.y / BUCKET) + 1):
			keys.append(Vector2i(bx, bz))
	return keys


func _index_circle(buckets: Dictionary, value: Variant, center: Vector2, radius: float) -> void:
	for key in _segment_buckets(center, center, radius):
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(value)
