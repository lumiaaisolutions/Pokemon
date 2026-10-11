class_name WorldBuilder
extends Node3D
## Mundo abierto de 4 × 4 km generado con la semilla de la partida (RegionLayout) y
## construido por zonas de CHUNK m alrededor del jugador: las cercanas con todo detalle
## (terreno con colisión, árboles, rocas, decoración, hierba alta y charcas) y las
## lejanas en baja resolución con árboles de lejos. Los datos de cada zona se calculan
## en hilos (WorkerThreadPool) y los nodos se crean en el hilo principal, pocas zonas
## por cuadro. Agua (mar, lagos y ríos), la cordillera del borde, los muros y las
## estructuras se construyen una vez. Responde las consultas de altura, agua, bioma y
## hábitat que usan los Pokémon, el jugador, la navegación y el mapa. Ejes: +X este, +Z sur.

const TERRAIN_SHADER := preload("res://world/terrain/terrain_region.gdshader")
const WATER_SHADER := preload("res://world/terrain/water_pixel.gdshader")
const TALL_GRASS_SHADER := preload("res://world/terrain/tall_grass_3d.gdshader")
const WORLD_GROUP := &"world"
## Actores que apartan la hierba alta al pasar (el shader admite 16).
const GRASS_PUSHERS_GROUP := &"grass_pushers"
## Árboles cargados (para las emboscadas desde las copas).
const TREES_GROUP := &"world_trees"
const MAX_GRASS_ACTORS := 16
## Capas de colisión: terreno, obstáculos y la cordillera exterior (solo la cámara).
const LAYER_TERRAIN := 1
const LAYER_OBSTACLES := 2
const LAYER_FRONTIER := 16
## Solo para la cámara: los edificios y lugares de fuera la detienen (sus colisionadores
## están en obstáculos + esta capa); los muros de los interiores no, para ver la sala.
const LAYER_CAMERA := 4
## Capa visual de los sprites (para la cámara del mapa y efectos).
const VISUAL_LAYER_SPRITES := 2
## Familia de suelo dominante (compatibilidad: mapa, pruebas y efectos).
enum Biome { MEADOW, FOREST, MOUNTAIN, BEACH }
## Profundidad desde la que el agua deja de ser transitable para la navegación.
const DEEP_WATER := 0.6
const POND_BANK := 3.0
## Zonas: lado (m), celda de la malla cercana y lejana, radios (en zonas).
const CHUNK := 128.0
const NEAR_CELL := 2.0
const FAR_CELL := 8.0
const NEAR_RADIUS := 2
const FAR_RADIUS := 6
## Zonas que se instancian por cuadro (cercanas y lejanas).
const NEAR_PER_FRAME := 1
const FAR_PER_FRAME := 4
## Profundidad de las faldas que tapan rendijas entre zonas de distinto detalle.
const SKIRT := 5.0
## Intentos por zona para árboles, rocas, decoración y parches de hierba alta.
const TREE_TRIES := 64
const ROCK_TRIES := 16
const DECOR_TRIES := 260
## Matas de pasto menudo por zona y qué tipos lleva cada bioma.
const GROUND_TUFTS := 3000
## Manchones de flores agrupadas por zona (pradera y campo de flores).
const FLOWER_PATCHES := 6
const TUFTS := {
	RegionLayout.Biome.MEADOW: ["tuft_green", "tuft_light", "tuft_light"], RegionLayout.Biome.FLOWERS: ["tuft_light", "tuft_green"],
	RegionLayout.Biome.SAVANNA: ["tuft_dry", "tuft_dry", "tuft_light"], RegionLayout.Biome.FOREST: ["tuft_green"],
	RegionLayout.Biome.JUNGLE: ["tuft_green", "tuft_green"], RegionLayout.Biome.SWAMP: ["tuft_green"],
	RegionLayout.Biome.DARK_FOREST: ["tuft_green"],
}
const GRASS_TRIES := 3
## Desde esta x empiezan los interiores (ver Interiors): suelo plano en y = 0, sin agua.
const INTERIOR_X := 10000.0

@export var config: WorldConfig

var layout: RegionLayout
## Parches de hierba alta de las zonas cargadas: (x, z, radio) y su familia (Biome).
var tall_grass_patches := PackedVector3Array()
var tall_grass_biomes := PackedInt32Array()
## Charcas de las zonas de pantano cargadas: (x, z, radio) y su nivel.
var swamp_ponds := PackedVector3Array()
var swamp_pond_levels := PackedFloat32Array()
var structures: Structures
## Hábitat del interior actual (cuevas: montaña; alcantarillas: pantano…).
var interior_habitat: SpeciesData.Habitat = SpeciesData.Habitat.MOUNTAIN

## Una zona cercana terminó de construirse (la navegación la hornea) o se liberó.
signal chunk_built(key: Vector2i, root: Node3D)
signal chunk_freed(key: Vector2i)

## Zonas instanciadas: key -> {"lod", "node", "heights", "patches", "patch_biomes"}.
var _chunks := {}
## Tareas en los hilos: key -> {"lod", "task"}; resultados listos: key -> datos.
var _inflight := {}
var _results := {}
var _mutex := Mutex.new()
var _pond_cache := {}
var _styles := {}
var _terrain_material: ShaderMaterial
var _water_fresh: ShaderMaterial
var _water_swamp: ShaderMaterial
var _water_toxic: ShaderMaterial
var _grass_materials: Array[ShaderMaterial] = []
var _grass_quads := {}
var _shadow_texture: GradientTexture2D
var _focus: Node3D
var _focus_key := Vector2i(1 << 20, 0)
var _last_focus := Vector2(INF, INF)


func _ready() -> void:
	add_to_group(WORLD_GROUP)
	# Regiones de la partida (la primera usa la semilla de la partida).
	Regions.ensure()
	var world_seed: int = GameState.world_seed if GameState.world_seed != 0 else config.seed
	config.seed = world_seed
	layout = RegionLayout.new(world_seed, config.size)
	_sync_config()
	_build_materials()
	_build_styles()
	_build_water()
	_build_frontier()
	_build_walls()
	structures = Structures.new()
	structures.name = "Structures"
	add_child(structures)
	structures.build(self)
	# Alrededor del inicio o de donde se guardó la partida.
	ensure_area(start_position() if SaveSystem.pending_position == Vector3.INF else SaveSystem.pending_position)


func _exit_tree() -> void:
	for key: Vector2i in _inflight:
		WorkerThreadPool.wait_for_task_completion(_inflight[key]["task"])
	_inflight.clear()


## Punto de inicio de la partida: la plaza del pueblo inicial.
func start_position() -> Vector3:
	return Vector3(layout.start.x, height_at(layout.start.x, layout.start.y) + 0.3, layout.start.y)


## Rellena los campos de WorldConfig que aún consulta el resto del juego (lago y río
## cercanos al inicio, costa) con los de la región generada.
func _sync_config() -> void:
	config.sea_level = layout.sea_level
	if not layout.lakes.is_empty():
		var nearest := layout.lakes[0]
		for lake in layout.lakes:
			if Vector2(lake.x, lake.y).distance_to(layout.start) < Vector2(nearest.x, nearest.y).distance_to(layout.start):
				nearest = lake
		config.lake_center = Vector2(nearest.x, nearest.y)
		config.lake_radius = nearest.z
	if not layout.rivers.is_empty():
		config.river_points = layout.rivers[0]["points"]
		config.river_width = float(layout.rivers[0]["width"])
	config.shore_z = config.size * 0.5 - RegionLayout.SEA_BAND
	config.path_width = RegionLayout.ROAD_WIDTH


# --- Consultas -------------------------------------------------------------------------

func region_biome_at(x: float, z: float) -> RegionLayout.Biome:
	if x > INTERIOR_X:
		return RegionLayout.Biome.MOUNTAIN
	return layout.biome_at(x, z)


## Pesos de familia en (x, z): Vector4(pasto, bosque, roca, arena).
func biome_weights(x: float, z: float) -> Vector4:
	match dominant_biome(x, z):
		Biome.FOREST:
			return Vector4(0, 1, 0, 0)
		Biome.MOUNTAIN:
			return Vector4(0, 0, 1, 0)
		Biome.BEACH:
			return Vector4(0, 0, 0, 1)
	return Vector4(1, 0, 0, 0)


func dominant_biome(x: float, z: float) -> Biome:
	var family: int = RegionLayout.FAMILY[region_biome_at(x, z)]
	return [Biome.MEADOW, Biome.FOREST, Biome.MOUNTAIN, Biome.BEACH, Biome.FOREST][family]


## Altura del terreno (con ríos, lagos, charcas, pueblos y caminos).
func height_at(x: float, z: float) -> float:
	if x > INTERIOR_X:
		return 0.0
	return _height_pure(x, z, _ponds_at(x, z))


## Altura sobre la malla real: interpolada en el triángulo de la celda de 2 m, igual que
## la malla cercana aunque la zona no esté cargada.
func surface_height_at(x: float, z: float) -> float:
	if x > INTERIOR_X:
		return 0.0
	var key := _chunk_key(x, z)
	var chunk: Dictionary = _chunks.get(key, {})
	if chunk.get("lod", -1) == 0:
		return _local_height(chunk["heights"], key, x, z)
	var x0 := floorf(x / NEAR_CELL) * NEAR_CELL
	var z0 := floorf(z / NEAR_CELL) * NEAR_CELL
	var fx := (x - x0) / NEAR_CELL
	var fz := (z - z0) / NEAR_CELL
	var h00 := height_at(x0, z0)
	var h11 := height_at(x0 + NEAR_CELL, z0 + NEAR_CELL)
	if fx >= fz:
		var h10 := height_at(x0 + NEAR_CELL, z0)
		return h00 + (h10 - h00) * fx + (h11 - h10) * fz
	var h01 := height_at(x0, z0 + NEAR_CELL)
	return h00 + (h11 - h01) * fx + (h01 - h00) * fz


## La altura más baja bajo un círculo (para apoyar sprites sin que floten).
func ground_base_height(x: float, z: float, radius: float) -> float:
	var lowest := surface_height_at(x, z)
	for i in 8:
		var angle := TAU * i / 8.0
		lowest = minf(lowest, surface_height_at(x + cos(angle) * radius, z + sin(angle) * radius))
	return lowest


## Río más cercano: Vector2(distancia, nivel del agua ahí); distancia INF si no hay.
func river_info(x: float, z: float) -> Vector2:
	var info := layout.river_info(x, z)
	return Vector2(info.x, info.y)


func water_level_at(x: float, z: float) -> float:
	if x > INTERIOR_X:
		return -1000.0
	return _water_level_pure(x, z, _ponds_at(x, z))


func water_depth_at(x: float, z: float) -> float:
	return water_level_at(x, z) - surface_height_at(x, z)


## Hábitat del lugar: pantano en sus biomas y charcas, agua dulce junto a ríos y lagos,
## y el del bioma de la región en lo demás.
func habitat_at(x: float, z: float) -> SpeciesData.Habitat:
	if x > INTERIOR_X:
		return interior_habitat
	var biome := layout.biome_at(x, z)
	if biome in [RegionLayout.Biome.SWAMP, RegionLayout.Biome.TOXIC_SWAMP]:
		return SpeciesData.Habitat.SWAMP
	var river := layout.river_info(x, z)
	if river.x < river.z * 0.5 + 6.0:
		return SpeciesData.Habitat.FRESHWATER
	for lake: Vector4 in layout._lakes_near(x, z):
		if Vector2(x - lake.x, z - lake.y).length() < lake.z + 8.0:
			return SpeciesData.Habitat.FRESHWATER
	return RegionLayout.HABITAT[biome]


## Factor de aparición por tipo según el bioma (desierto: Tierra; volcán: Fuego…): el
## mayor de los favorables, o el producto de los desfavorables.
func type_affinity(types: Array, x: float, z: float) -> float:
	if x > INTERIOR_X:
		return 1.0
	var table: Dictionary = RegionLayout.TYPE_AFFINITY.get(layout.biome_at(x, z), {})
	if table.is_empty():
		return 1.0
	var best := 1.0
	var penalty := 1.0
	for t in types:
		var f := float(table.get(t, 1.0))
		if f >= 1.0:
			best = maxf(best, f)
		else:
			penalty *= f
	return best * penalty


## Nombre del lugar: pueblo, lugar especial o bioma.
func location_name(x: float, z: float) -> String:
	var settlement := settlement_at(x, z)
	if not settlement.is_empty():
		return settlement["name"]
	if x > INTERIOR_X:
		return structures.services.interiors.current_title() if structures != null else ""
	var place := structures.place_at(x, z) if structures != null else {}
	if not place.is_empty():
		return Structures.place_title(place)
	return RegionLayout.BIOME_NAMES[layout.biome_at(x, z)]


## Asentamiento que contiene (x, z), o {}.
func settlement_at(x: float, z: float, margin: float = 0.0) -> Dictionary:
	for s: Dictionary in layout._flat_buckets.get(layout._bucket(x, z), []):
		if Vector2(x - float(s["x"]), z - float(s["z"])).length() < float(s["radius"]) + margin:
			return s
	return {}


## Efecto con el que un Pokémon se esconde en (x, z), según el lugar.
func hide_effect_at(x: float, z: float) -> PixelBurst.Kind:
	if water_depth_at(x, z) > 0.3:
		return PixelBurst.Kind.SPLASH
	if is_in_tall_grass(Vector3(x, 0, z)):
		return PixelBurst.Kind.LEAVES
	match region_biome_at(x, z):
		RegionLayout.Biome.FOREST, RegionLayout.Biome.JUNGLE, RegionLayout.Biome.DARK_FOREST, RegionLayout.Biome.MUSHROOM:
			return PixelBurst.Kind.FOREST_LEAVES
		RegionLayout.Biome.MOUNTAIN, RegionLayout.Biome.CANYON, RegionLayout.Biome.MESA, RegionLayout.Biome.VOLCANO, RegionLayout.Biome.TUNDRA:
			return PixelBurst.Kind.ROCK
		RegionLayout.Biome.BEACH, RegionLayout.Biome.DESERT, RegionLayout.Biome.SEA:
			return PixelBurst.Kind.SAND
	return PixelBurst.Kind.LEAVES


## Punto de hierba alta más cercano a point dentro de radius, o Vector3.INF.
func nearest_tall_grass_point(point: Vector3, radius: float) -> Vector3:
	var best := Vector3.INF
	var best_d := radius
	for patch in tall_grass_patches:
		var center := Vector2(patch.x, patch.y)
		var d := center.distance_to(Vector2(point.x, point.z)) - patch.z
		if d < best_d:
			best_d = d
			var dir := Vector2(point.x, point.z) - center
			var inside := center + (dir.normalized() * minf(dir.length(), patch.z * 0.6) if dir.length() > 0.01 else Vector2.ZERO)
			best = Vector3(inside.x, surface_height_at(inside.x, inside.y), inside.y)
	return best


func is_in_tall_grass(point: Vector3) -> bool:
	for patch in tall_grass_patches:
		if Vector2(point.x - patch.x, point.z - patch.y).length() <= patch.z:
			return true
	return false


func random_point_in_tall_grass(rng: RandomNumberGenerator, near: Vector3 = Vector3.INF, max_distance: float = INF) -> Vector3:
	var candidates: Array[int] = []
	for i in tall_grass_patches.size():
		var patch := tall_grass_patches[i]
		if near == Vector3.INF or Vector2(near.x - patch.x, near.z - patch.y).length() - patch.z <= max_distance:
			candidates.append(i)
	if candidates.is_empty():
		return Vector3.INF
	var patch := tall_grass_patches[candidates[rng.randi() % candidates.size()]]
	var angle := rng.randf() * TAU
	var r := sqrt(rng.randf()) * patch.z * 0.9
	var x := patch.x + cos(angle) * r
	var z := patch.y + sin(angle) * r
	return Vector3(x, surface_height_at(x, z), z)


## Punto en agua (in_water) o en la orilla seca junto al agua, cerca de near.
func random_water_point(rng: RandomNumberGenerator, near: Vector3, max_distance: float, in_water: bool) -> Vector3:
	for attempt in 40:
		var angle := rng.randf() * TAU
		var r := rng.randf_range(10.0, max_distance)
		var x := near.x + cos(angle) * r
		var z := near.z + sin(angle) * r
		if not is_inside(x, z, 6.0):
			continue
		var depth := water_depth_at(x, z)
		if in_water and depth > 0.8:
			return Vector3(x, water_level_at(x, z), z)
		if not in_water and depth < -0.2 and depth > -2.5 and _water_within(x, z, 5.0):
			return Vector3(x, surface_height_at(x, z), z)
	return Vector3.INF


## ¿(x, z) está dentro del área jugable, a margin m del borde?
func is_inside(x: float, z: float, margin: float = 0.0) -> bool:
	var half := config.size * 0.5 - margin
	return absf(x) <= half and absf(z) <= half


## Distancia al camino más cercano (entre pueblos).
func distance_to_paths(x: float, z: float) -> float:
	return layout.road_info(x, z).x


func _dry_land(x: float, z: float, radius: float) -> bool:
	if water_depth_at(x, z) > -0.4:
		return false
	for i in 8:
		var angle := TAU * i / 8.0
		if water_depth_at(x + cos(angle) * radius, z + sin(angle) * radius) > -0.4:
			return false
	return true


func _water_within(x: float, z: float, radius: float) -> bool:
	for i in 8:
		var angle := TAU * i / 8.0
		if water_depth_at(x + cos(angle) * radius, z + sin(angle) * radius) > 0.3:
			return true
	return false


## Área aproximada (m²) de una familia de suelo en la región (pruebas).
func _biome_area(biome: Biome) -> float:
	var count := 0
	var step := 64.0
	var cells := int(config.size / step)
	for i in cells:
		for j in cells:
			if dominant_biome((i + 0.5) * step - config.size * 0.5, (j + 0.5) * step - config.size * 0.5) == biome:
				count += 1
	return count * step * step


## Bordes de lagos y ríos cerca del inicio, con su nivel: (x, 0, z, nivel). Pruebas.
func water_edge_samples(max_distance: float = 900.0) -> PackedVector4Array:
	var samples := PackedVector4Array()
	var origin := layout.start
	for river in layout.rivers:
		var pts: PackedVector2Array = river["points"]
		var levels: PackedFloat32Array = river["levels"]
		var half := float(river["width"]) * 0.5 + RegionLayout.RIVER_BANK * RegionLayout.WATER_EDGE
		for i in range(1, pts.size() - 1):
			var dir := (pts[i + 1] - pts[i - 1]).normalized()
			var normal := Vector2(-dir.y, dir.x)
			for side: float in [-1.0, 1.0]:
				var p: Vector2 = pts[i] + normal * half * side
				if p.distance_to(origin) > max_distance or not is_inside(p.x, p.y, 40.0):
					continue
				# Solo bordes que de verdad son de este tramo (no donde el río entra a un lago o al mar).
				if absf(water_level_at(p.x, p.y) - levels[i]) > 0.05 or layout.biome_at(p.x, p.y) in [RegionLayout.Biome.SEA, RegionLayout.Biome.BEACH]:
					continue
				if layout.river_info(p.x, p.y).x < half - 0.5:
					continue
				# Donde el río entra a un lago, el lago cubre la orilla.
				if layout._lakes_near(p.x, p.y).any(func(l: Vector4) -> bool: return Vector2(p.x - l.x, p.y - l.y).length() < l.z + RegionLayout.LAKE_BANK):
					continue
				samples.append(Vector4(p.x, 0.0, p.y, levels[i]))
	for lake in layout.lakes:
		if Vector2(lake.x, lake.y).distance_to(origin) > max_distance:
			continue
		for i in 32:
			var angle := TAU * i / 32.0
			var p := Vector2(lake.x, lake.y) + Vector2(cos(angle), sin(angle)) * (lake.z + RegionLayout.LAKE_BANK * RegionLayout.WATER_EDGE)
			if layout.river_info(p.x, p.y).x < 25.0 or absf(water_level_at(p.x, p.y) - lake.w) > 0.05:
				continue
			samples.append(Vector4(p.x, 0.0, p.y, lake.w))
	return samples


## Polígonos de agua profunda de una zona (para la navegación), por franjas de 4 m.
func deep_water_outlines(key: Vector2i) -> Array[PackedVector3Array]:
	var outlines: Array[PackedVector3Array] = []
	var step := 4.0
	var x0 := key.x * CHUNK
	var z0 := key.y * CHUNK
	var cells := int(CHUNK / step)
	for iz in cells:
		var run_start := -1
		for ix in cells + 1:
			var deep := false
			if ix < cells:
				deep = water_depth_at(x0 + (ix + 0.5) * step, z0 + (iz + 0.5) * step) > DEEP_WATER
			if deep and run_start < 0:
				run_start = ix
			elif not deep and run_start >= 0:
				var ax := x0 + run_start * step
				var bx := x0 + ix * step
				var az := z0 + iz * step
				outlines.append(PackedVector3Array([Vector3(ax, 0, az), Vector3(bx, 0, az), Vector3(bx, 0, az + step), Vector3(ax, 0, az + step)]))
				run_start = -1
	return outlines


# --- Funciones puras (seguras en hilos) ------------------------------------------------

func _height_pure(x: float, z: float, ponds: Array) -> float:
	var h := layout.height_at(x, z)
	for pond: Vector4 in ponds:
		var d := Vector2(x - pond.x, z - pond.y).length()
		if d < pond.z + POND_BANK:
			h = RegionLayout._carve(h, d, pond.z, POND_BANK, pond.w, 0.9, 0.6)
	return h


func _water_level_pure(x: float, z: float, ponds: Array) -> float:
	var level := layout.water_level_at(x, z)
	for pond: Vector4 in ponds:
		if Vector2(x - pond.x, z - pond.y).length() < pond.z + POND_BANK * RegionLayout.WATER_EDGE:
			level = maxf(level, pond.w)
	return level


## Altura interpolada dentro de una zona cercana a partir de sus alturas (celdas de 2 m).
func _local_height(heights: PackedFloat32Array, key: Vector2i, x: float, z: float) -> float:
	var n := int(CHUNK / NEAR_CELL) + 1
	var gx := (x - key.x * CHUNK) / NEAR_CELL
	var gz := (z - key.y * CHUNK) / NEAR_CELL
	var ix := clampi(floori(gx), 0, n - 2)
	var iz := clampi(floori(gz), 0, n - 2)
	var fx := clampf(gx - ix, 0.0, 1.0)
	var fz := clampf(gz - iz, 0.0, 1.0)
	var h00 := heights[iz * n + ix]
	var h11 := heights[(iz + 1) * n + ix + 1]
	if fx >= fz:
		var h10 := heights[iz * n + ix + 1]
		return h00 + (h10 - h00) * fx + (h11 - h10) * fz
	var h01 := heights[(iz + 1) * n + ix]
	return h00 + (h11 - h01) * fx + (h01 - h00) * fz


func _local_base(heights: PackedFloat32Array, key: Vector2i, x: float, z: float, radius: float) -> float:
	var lowest := _local_height(heights, key, x, z)
	for i in 8:
		var angle := TAU * i / 8.0
		lowest = minf(lowest, _local_height(heights, key, x + cos(angle) * radius, z + sin(angle) * radius))
	return lowest


func _local_dry(heights: PackedFloat32Array, key: Vector2i, ponds: Array, x: float, z: float, radius: float) -> bool:
	if _water_level_pure(x, z, ponds) - _local_height(heights, key, x, z) > -0.4:
		return false
	for i in 8:
		var angle := TAU * i / 8.0
		var px := x + cos(angle) * radius
		var pz := z + sin(angle) * radius
		if _water_level_pure(px, pz, ponds) - _local_height(heights, key, px, pz) > -0.4:
			return false
	return true


func _in_settlement(x: float, z: float, margin: float) -> bool:
	for s: Dictionary in layout._flat_buckets.get(layout._bucket(x, z), []):
		if Vector2(x - float(s["x"]), z - float(s["z"])).length() < float(s["radius"]) + margin:
			return true
	return false


func _near_place(x: float, z: float, margin: float) -> bool:
	for place: Dictionary in layout.places:
		if Vector2(x - float(place["x"]), z - float(place["z"])).length() < float(place["radius"]) + margin:
			return true
	return false


## ¿Se puede poner un árbol o roca de este radio aquí?
func _spot_ok(heights: PackedFloat32Array, key: Vector2i, ponds: Array, x: float, z: float, radius: float) -> bool:
	if Vector2(x, z).distance_to(layout.start) < config.spawn_flat_radius + radius:
		return false
	if layout.road_info(x, z).x < RegionLayout.ROAD_WIDTH + radius + 1.0:
		return false
	if _in_settlement(x, z, radius + 4.0) or _near_place(x, z, radius + 8.0):
		return false
	return _local_dry(heights, key, ponds, x, z, radius)


## Atributos del suelo de un vértice: [familias, (pantano, camino, nieve, pavimento), tinte].
func _vertex_attributes(x: float, z: float) -> Array:
	var biome := layout.biome_at(x, z)
	var family: int = RegionLayout.FAMILY[biome]
	var families := Color(0, 0, 0, 0)
	match family:
		0:
			families.r = 1.0
		1, 4:
			families.g = 1.0
		2:
			families.b = 1.0
		_:
			families.a = 1.0
	var swamp := 1.0 if family == 4 else 0.0
	var snow := 0.0
	match biome:
		RegionLayout.Biome.TUNDRA:
			snow = 1.0
		RegionLayout.Biome.VOLCANO, RegionLayout.Biome.DESERT, RegionLayout.Biome.MESA, RegionLayout.Biome.CANYON, RegionLayout.Biome.SAVANNA, RegionLayout.Biome.JUNGLE:
			snow = -1.0
	var path := 1.0 if layout.road_info(x, z).x < RegionLayout.ROAD_WIDTH * 0.5 else 0.0
	var paving := 0.0
	for s: Dictionary in layout._flat_buckets.get(layout._bucket(x, z), []):
		var d := Vector2(x - float(s["x"]), z - float(s["z"])).length()
		var radius := float(s["radius"])
		if s["kind"] == "city" and d < radius * 0.8:
			path = 1.0
			paving = 1.0
		elif s["kind"] in ["town", "village"] and d < radius * 0.22:
			path = 1.0
		# Caminito de cada puerta a la plaza.
		if path < 1.0 and d < radius and s.has("buildings"):
			var plaza := Vector2(float(s["x"]), float(s["z"]))
			for b: Dictionary in s["buildings"]:
				if b["kind"] == "manhole":
					continue
				var pos := Vector2(float(b["x"]), float(b["z"]))
				var door := pos + (plaza - pos).normalized() * float(b["d"]) * 0.45
				var ab := plaza - door
				var t := clampf((Vector2(x, z) - door).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
				if Vector2(x, z).distance_to(door + ab * t) < 1.1:
					path = 1.0
					break
	# Arena en las orillas de ríos y lagos.
	if family != 4:
		var river := layout.river_info(x, z)
		if river.x < river.z * 0.5 + RegionLayout.RIVER_BANK * 0.6:
			families = Color(0, 0, 0, 1)
		for lake: Vector4 in layout._lakes_near(x, z):
			if Vector2(x - lake.x, z - lake.y).length() < lake.z + RegionLayout.LAKE_BANK * 0.7:
				families = Color(0, 0, 0, 1)
	return [families, Color(swamp, path, snow, paving), RegionLayout.TINT[biome]]


## Calcula todo lo de una zona (en un hilo): malla, colisión y props.
func _generate(key: Vector2i, lod: int, ponds: Array) -> Dictionary:
	var cell := NEAR_CELL if lod == 0 else FAR_CELL
	var n := int(CHUNK / cell) + 1
	var m := n + 2
	var x0 := key.x * CHUNK
	var z0 := key.y * CHUNK
	# Alturas con un borde de una celda para las normales.
	var grid := PackedFloat32Array()
	grid.resize(m * m)
	for iz in m:
		for ix in m:
			grid[iz * m + ix] = _height_pure(x0 + (ix - 1) * cell, z0 + (iz - 1) * cell, ponds)
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var custom0 := PackedFloat32Array()
	var custom1 := PackedFloat32Array()
	for iz in n:
		for ix in n:
			var h := grid[(iz + 1) * m + ix + 1]
			heights[iz * n + ix] = h
			var x := x0 + ix * cell
			var z := z0 + iz * cell
			verts.append(Vector3(x, h, z))
			var dx := grid[(iz + 1) * m + ix + 2] - grid[(iz + 1) * m + ix]
			var dz := grid[(iz + 2) * m + ix + 1] - grid[iz * m + ix + 1]
			normals.append(Vector3(-dx, 2.0 * cell, -dz).normalized())
			var attr := _vertex_attributes(x, z)
			var fam: Color = attr[0]
			var extra: Color = attr[1]
			custom0.append_array([fam.r, fam.g, fam.b, fam.a])
			custom1.append_array([extra.r, extra.g, extra.b, extra.a])
			colors.append(attr[2])
	var indices := PackedInt32Array()
	var faces := PackedVector3Array()
	for iz in n - 1:
		for ix in n - 1:
			var a := iz * n + ix
			var b := a + 1
			var c := a + n + 1
			var d := a + n
			indices.append_array([a, b, c, a, c, d])
			if lod == 0:
				faces.append_array([verts[a], verts[b], verts[c], verts[a], verts[c], verts[d]])
	# Faldas: una tira hacia abajo en el contorno (por las dos caras).
	var ring: Array[int] = []
	for ix in n:
		ring.append(ix)
	for iz in range(1, n):
		ring.append(iz * n + n - 1)
	for ix in range(n - 2, -1, -1):
		ring.append((n - 1) * n + ix)
	for iz in range(n - 2, 0, -1):
		ring.append(iz * n)
	var skirt_start := verts.size()
	for id in ring:
		verts.append(verts[id] - Vector3(0, SKIRT, 0))
		normals.append(normals[id])
		colors.append(colors[id])
		custom0.append_array(custom0.slice(id * 4, id * 4 + 4))
		custom1.append_array(custom1.slice(id * 4, id * 4 + 4))
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		var sa := skirt_start + i
		var sb := skirt_start + (i + 1) % ring.size()
		indices.append_array([a, b, sb, a, sb, sa, a, sb, b, a, sa, sb])
	var data := {"lod": lod, "heights": heights, "verts": verts, "normals": normals, "colors": colors,
			"custom0": custom0, "custom1": custom1, "indices": indices}
	if lod == 0:
		data["faces"] = faces
		data["props"] = _plan_props(key, heights, ponds)
	else:
		data["far_trees"] = _plan_far_trees(key, grid, m, cell)
	return data


func _plan_props(key: Vector2i, heights: PackedFloat32Array, ponds: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ (layout.seed * 31 + config.props_seed)
	var x0 := key.x * CHUNK
	var z0 := key.y * CHUNK
	var obstacles: Array = []
	for i in TREE_TRIES + ROCK_TRIES:
		var is_tree := i < TREE_TRIES
		var x := x0 + rng.randf_range(1.5, CHUNK - 1.5)
		var z := z0 + rng.randf_range(1.5, CHUNK - 1.5)
		var roll := rng.randf()
		var pick := rng.randi()
		var big := rng.randf()
		var style: Dictionary = _styles[layout.biome_at(x, z)]
		var textures: Array = style["trees" if is_tree else "rocks"]
		var chance := float(style["tree_density" if is_tree else "rock_density"]) / (TREE_TRIES if is_tree else ROCK_TRIES)
		if textures.is_empty() or roll >= chance:
			continue
		var radius := 0.45 if is_tree else 0.7
		if not _spot_ok(heights, key, ponds, x, z, radius * 2.0 + 0.6):
			continue
		var texture: Texture2D = textures[pick % textures.size()]
		var scale_factor := 2.0 if big < float(style["big"]) else 1.0
		var width := texture.get_size().x * config.pixel_size * scale_factor
		var y := _local_base(heights, key, x, z, width * 0.5) - config.obstacle_sink
		var shape := _tree_shape(layout.biome_at(x, z), texture) if is_tree else ""
		obstacles.append([texture, scale_factor, radius, Vector3(x, y, z), style["tint"], is_tree, shape])
	var decor := {}
	for i in DECOR_TRIES:
		var x := x0 + rng.randf() * CHUNK
		var z := z0 + rng.randf() * CHUNK
		var roll := rng.randf()
		var pick := rng.randi()
		var biome_here := layout.biome_at(x, z)
		var style: Dictionary = _styles[biome_here]
		var textures: Array = style["decor"]
		if textures.is_empty() or roll >= float(style["decor_density"]) / DECOR_TRIES:
			continue
		# En los pantanos el suelo está casi al nivel del agua: ahí la decoración (juncos,
		# troncos, hongos) puede ir en la orilla y en agua muy baja.
		var swampy := biome_here in [RegionLayout.Biome.SWAMP, RegionLayout.Biome.TOXIC_SWAMP]
		if _water_level_pure(x, z, ponds) - _local_height(heights, key, x, z) > (0.25 if swampy else -0.2):
			continue
		if layout.road_info(x, z).x < RegionLayout.ROAD_WIDTH or _in_settlement(x, z, -8.0):
			continue
		var texture: Texture2D = textures[pick % textures.size()]
		var group := [texture, style["tint"]]
		if not decor.has(group):
			decor[group] = PackedVector3Array()
		var width := texture.get_size().x * config.pixel_size
		# PackedVector3Array se copia por valor: hay que volver a guardarlo.
		var points: PackedVector3Array = decor[group]
		points.append(Vector3(x, _local_base(heights, key, x, z, width * 0.5) - config.decor_sink, z))
		decor[group] = points
	# Pasto menudo: muchas matas pequeñas en los biomas con pasto, para que el campo
	# abierto no se vea vacío (pedido de Fernando, 2026-10-10).
	for i in GROUND_TUFTS:
		var x := x0 + rng.randf() * CHUNK
		var z := z0 + rng.randf() * CHUNK
		var pick := rng.randi()
		var tuft_kinds: Array = TUFTS.get(layout.biome_at(x, z), [])
		if tuft_kinds.is_empty():
			continue
		if _water_level_pure(x, z, ponds) - _local_height(heights, key, x, z) > -0.2:
			continue
		if layout.road_info(x, z).x < RegionLayout.ROAD_WIDTH or _in_settlement(x, z, -4.0):
			continue
		var texture := PropArt.texture(tuft_kinds[pick % tuft_kinds.size()])
		var group := [texture, Color.WHITE]
		if not decor.has(group):
			decor[group] = PackedVector3Array()
		var points: PackedVector3Array = decor[group]
		points.append(Vector3(x, _local_height(heights, key, x, z) - 0.04, z))
		decor[group] = points
	# Manchones de flores: grupos de 8 a 18 matas del mismo color.
	for i in FLOWER_PATCHES:
		var cx := x0 + rng.randf() * CHUNK
		var cz := z0 + rng.randf() * CHUNK
		var biome_patch := layout.biome_at(cx, cz)
		var kind_pick := rng.randi()
		if not biome_patch in [RegionLayout.Biome.MEADOW, RegionLayout.Biome.FLOWERS, RegionLayout.Biome.JUNGLE]:
			continue
		var flower_kind: String = ["flowers_pink", "flowers_blue", "flowers_white"][kind_pick % 3]
		var texture := PropArt.texture(flower_kind)
		var group := [texture, Color.WHITE]
		if not decor.has(group):
			decor[group] = PackedVector3Array()
		var points: PackedVector3Array = decor[group]
		for j in rng.randi_range(8, 18):
			var x := cx + rng.randf_range(-5.0, 5.0)
			var z := cz + rng.randf_range(-5.0, 5.0)
			if layout.road_info(x, z).x < RegionLayout.ROAD_WIDTH or _in_settlement(x, z, -4.0):
				continue
			if _water_level_pure(x, z, ponds) - _local_height(heights, key, x, z) > -0.2:
				continue
			points.append(Vector3(x, _local_height(heights, key, x, z) - 0.04, z))
		decor[group] = points
	# Arrecife: corales en el fondo del mar.
	for i in 40:
		var x := x0 + rng.randf() * CHUNK
		var z := z0 + rng.randf() * CHUNK
		var pick := rng.randi()
		if layout.biome_at(x, z) != RegionLayout.Biome.SEA:
			continue
		var depth := layout.sea_level - _local_height(heights, key, x, z)
		if depth < 2.0 or depth > 14.0:
			continue
		var texture := PropArt.texture("coral") if pick % 2 == 0 else PropArt.texture("coral_blue")
		var group := [texture, Color.WHITE]
		if not decor.has(group):
			decor[group] = PackedVector3Array()
		# PackedVector3Array se copia por valor: hay que volver a guardarlo.
		var points: PackedVector3Array = decor[group]
		points.append(Vector3(x, _local_height(heights, key, x, z) - 0.05, z))
		decor[group] = points
	var patches: Array = []
	for i in GRASS_TRIES:
		var roll := rng.randf()
		var cx := x0 + rng.randf_range(14.0, CHUNK - 14.0)
		var cz := z0 + rng.randf_range(14.0, CHUNK - 14.0)
		var style: Dictionary = _styles[layout.biome_at(cx, cz)]
		var grass: BiomeConfig = style["grass"]
		if grass == null or grass.tall_grass_texture == null or roll >= float(style["grass_chance"]):
			continue
		var radius := rng.randf_range(grass.tall_grass_radius_min, grass.tall_grass_radius_max)
		if layout.road_info(cx, cz).x < radius + 2.0 or _in_settlement(cx, cz, radius + 2.0) or _near_place(cx, cz, radius + 4.0):
			continue
		if Vector2(cx, cz).distance_to(layout.start) < radius + config.spawn_flat_radius or not _local_dry(heights, key, ponds, cx, cz, radius):
			continue
		var positions := PackedVector3Array()
		var count := int(PI * radius * radius * grass.tall_grass_density)
		for j in count:
			var angle := rng.randf() * TAU
			var r := sqrt(rng.randf()) * radius
			var x := cx + cos(angle) * r
			var z := cz + sin(angle) * r
			var h := _local_height(heights, key, x, z)
			if _water_level_pure(x, z, ponds) - h > -0.1:
				continue
			positions.append(Vector3(x, h - config.decor_sink, z))
		patches.append([Vector3(cx, cz, radius), grass, positions, Biome.FOREST if grass == config.forest else Biome.MEADOW])
	return {"obstacles": obstacles, "decor": decor, "patches": patches}


## Árboles de lejos (sin colisión) para que los bosques se vean desde la distancia.
func _plan_far_trees(key: Vector2i, grid: PackedFloat32Array, m: int, cell: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ (layout.seed * 31 + config.props_seed + 1)
	var by_texture := {}
	var x0 := key.x * CHUNK
	var z0 := key.y * CHUNK
	for i in TREE_TRIES / 2:
		var x := x0 + rng.randf() * CHUNK
		var z := z0 + rng.randf() * CHUNK
		var roll := rng.randf()
		var pick := rng.randi()
		var style: Dictionary = _styles[layout.biome_at(x, z)]
		var trees: Array = style["trees"]
		if trees.is_empty() or roll >= float(style["tree_density"]) / (TREE_TRIES / 2.0) * 0.5:
			continue
		var h := grid[(clampi(int((z - z0) / cell), 0, m - 3) + 1) * m + clampi(int((x - x0) / cell), 0, m - 3) + 1]
		if layout.water_level_at(x, z) - h > -0.4 or _in_settlement(x, z, 4.0) or layout.road_info(x, z).x < 4.0:
			continue
		var far_texture: Texture2D = trees[pick % trees.size()]
		var group := [far_texture, style["tint"], _tree_shape(layout.biome_at(x, z), far_texture)]
		if not by_texture.has(group):
			by_texture[group] = PackedVector3Array()
		# PackedVector3Array se copia por valor: hay que volver a guardarlo.
		var points: PackedVector3Array = by_texture[group]
		points.append(Vector3(x, h - 0.3, z))
		by_texture[group] = points
	return by_texture


# --- Charcas de pantano (por zona, deterministas) --------------------------------------

func _ponds_at(x: float, z: float) -> Array:
	return _ponds_of(_chunk_key(x, z))


## Charcas de una zona de pantano: Vector4(x, z, radio, nivel). Quedan dentro de su zona
## (con margen), así ninguna consulta necesita mirar las vecinas.
func _ponds_of(key: Vector2i) -> Array:
	if _pond_cache.has(key):
		return _pond_cache[key]
	var ponds: Array = []
	var cx := (key.x + 0.5) * CHUNK
	var cz := (key.y + 0.5) * CHUNK
	if layout.biome_at(cx, cz) in [RegionLayout.Biome.SWAMP, RegionLayout.Biome.TOXIC_SWAMP]:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key) ^ (layout.seed + 101)
		for i in rng.randi_range(2, 4):
			var radius := rng.randf_range(4.0, 8.0)
			var margin := radius + POND_BANK + 3.0
			var px := key.x * CHUNK + rng.randf_range(margin, CHUNK - margin)
			var pz := key.y * CHUNK + rng.randf_range(margin, CHUNK - margin)
			# Nivel = el punto más bajo de la orilla (antes, el centro: en pendiente el agua
			# quedaba flotando del lado de abajo). En pendientes fuertes no hay charca.
			var rim_low := INF
			var rim_high := -INF
			for j in 12:
				var angle := TAU * j / 12.0
				var rim := layout.height_at(px + cos(angle) * (radius + POND_BANK), pz + sin(angle) * (radius + POND_BANK))
				rim_low = minf(rim_low, rim)
				rim_high = maxf(rim_high, rim)
			if rim_high - rim_low > 2.5:
				continue
			var level := minf(layout.height_at(px, pz), rim_low) - 0.3
			if level < layout.sea_level + 0.5 or _in_settlement(px, pz, margin) or layout.road_info(px, pz).x < margin:
				continue
			if ponds.any(func(p: Vector4) -> bool: return Vector2(p.x, p.y).distance_to(Vector2(px, pz)) < p.z + radius + POND_BANK * 2.0):
				continue
			ponds.append(Vector4(px, pz, radius, level))
	_pond_cache[key] = ponds
	return ponds


# --- Zonas -------------------------------------------------------------------------------

func _chunk_key(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CHUNK), floori(z / CHUNK))


func _chunk_in_world(key: Vector2i) -> bool:
	var half := config.size * 0.5
	return key.x * CHUNK < half and (key.x + 1) * CHUNK > -half and key.y * CHUNK < half and (key.y + 1) * CHUNK > -half


## Construye ya (esperando a los hilos) las zonas cercanas alrededor de point: al
## iniciar, al cargar partida o tras un teletransporte.
func ensure_area(point: Vector3) -> void:
	var center := _chunk_key(point.x, point.z)
	var tasks := {}
	for dz in range(-NEAR_RADIUS, NEAR_RADIUS + 1):
		for dx in range(-NEAR_RADIUS, NEAR_RADIUS + 1):
			var key := center + Vector2i(dx, dz)
			if not _chunk_in_world(key) or _chunks.get(key, {}).get("lod", -1) == 0:
				continue
			if _inflight.has(key):
				WorkerThreadPool.wait_for_task_completion(_inflight[key]["task"])
				_inflight.erase(key)
			var ponds := _ponds_of(key)
			tasks[key] = WorkerThreadPool.add_task(_run_task.bind(key, 0, ponds), true, "Zona")
	for key: Vector2i in tasks:
		WorkerThreadPool.wait_for_task_completion(tasks[key])
	for key: Vector2i in tasks:
		_mutex.lock()
		var data: Dictionary = _results.get(key, {})
		_results.erase(key)
		_mutex.unlock()
		if not data.is_empty() and data["lod"] == 0:
			_instantiate(key, data)
	_last_focus = Vector2(point.x, point.z)
	_focus_key = Vector2i(1 << 20, 0)


## A quién sigue la construcción por zonas (por defecto, el jugador): la cinemática del
## inicio lo redirige mientras la cámara visita lugares lejanos (ver IntroCinematic), para
## que esas zonas se construyan en vez de las del jugador. null vuelve al jugador.
func set_focus(node: Node3D) -> void:
	_focus = node


func _run_task(key: Vector2i, lod: int, ponds: Array) -> void:
	var data := _generate(key, lod, ponds)
	_mutex.lock()
	_results[key] = data
	_mutex.unlock()


func _process(_delta: float) -> void:
	_update_grass_pushers()
	if _focus == null or not is_instance_valid(_focus):
		_focus = get_node_or_null("../Player") as Node3D
		if _focus == null:
			return
	var focus := Vector2(_focus.global_position.x, _focus.global_position.z)
	# En un interior el exterior queda como estaba (se vuelve a la misma puerta).
	if focus.x > INTERIOR_X:
		_collect(_focus_key)
		return
	if focus.distance_to(_last_focus) > CHUNK:
		ensure_area(_focus.global_position)
	_last_focus = focus
	var center := _chunk_key(focus.x, focus.y)
	if center != _focus_key:
		_focus_key = center
		_schedule(center)
	_collect(center)


## Lanza en hilos las zonas que faltan alrededor de center y libera las que sobran.
func _schedule(center: Vector2i) -> void:
	var wanted := _wanted(center)
	for key: Vector2i in _chunks.keys():
		if not wanted.has(key):
			_free_chunk(key)
	var missing: Array[Vector2i] = []
	for key: Vector2i in wanted:
		if _chunks.get(key, {}).get("lod", -1) != wanted[key] and not (_inflight.has(key) and _inflight[key]["lod"] == wanted[key]):
			missing.append(key)
	missing.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(center) < b.distance_squared_to(center))
	for key in missing:
		if _inflight.has(key):
			continue # Se reprograma cuando termine la tarea vieja.
		_inflight[key] = {"lod": wanted[key], "task": WorkerThreadPool.add_task(_run_task.bind(key, wanted[key], _ponds_of(key)), false, "Zona")}


func _wanted(center: Vector2i) -> Dictionary:
	var wanted := {}
	var far := mini(GameOptions.far_radius(), FAR_RADIUS)
	for dz in range(-far, far + 1):
		for dx in range(-far, far + 1):
			var key := center + Vector2i(dx, dz)
			if _chunk_in_world(key):
				wanted[key] = 0 if maxi(absi(dx), absi(dz)) <= NEAR_RADIUS else 1
	return wanted


## Recoge las tareas terminadas e instancia unas pocas zonas por cuadro.
func _collect(center: Vector2i) -> void:
	for key: Vector2i in _inflight.keys():
		if WorkerThreadPool.is_task_completed(_inflight[key]["task"]):
			WorkerThreadPool.wait_for_task_completion(_inflight[key]["task"])
			_inflight.erase(key)
	_mutex.lock()
	var ready_keys: Array = _results.keys()
	_mutex.unlock()
	if ready_keys.is_empty():
		return
	var wanted := _wanted(center)
	ready_keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(center) < b.distance_squared_to(center))
	var near_done := 0
	var far_done := 0
	var reschedule := false
	for key: Vector2i in ready_keys:
		_mutex.lock()
		var data: Dictionary = _results[key]
		_mutex.unlock()
		var lod: int = data["lod"]
		if not wanted.has(key) or wanted[key] != lod:
			_mutex.lock()
			_results.erase(key)
			_mutex.unlock()
			reschedule = true
			continue
		if (lod == 0 and near_done >= NEAR_PER_FRAME) or (lod == 1 and far_done >= FAR_PER_FRAME):
			continue
		_mutex.lock()
		_results.erase(key)
		_mutex.unlock()
		_instantiate(key, data)
		if lod == 0:
			near_done += 1
		else:
			far_done += 1
	if reschedule:
		_schedule(center)


func _free_chunk(key: Vector2i) -> void:
	var chunk: Dictionary = _chunks.get(key, {})
	if chunk.is_empty():
		return
	(chunk["node"] as Node).queue_free()
	_chunks.erase(key)
	_rebuild_patch_lists()
	if chunk["lod"] == 0:
		chunk_freed.emit(key)


## ¿La zona del punto está construida con todo detalle (con colisión)?
func is_near_loaded(point: Vector3) -> bool:
	return _chunks.get(_chunk_key(point.x, point.z), {}).get("lod", -1) == 0


## Raíces de las zonas cercanas cargadas (para la navegación).
func near_chunks() -> Dictionary:
	var result := {}
	for key: Vector2i in _chunks:
		if _chunks[key]["lod"] == 0:
			result[key] = _chunks[key]["node"]
	return result


func _instantiate(key: Vector2i, data: Dictionary) -> void:
	var lod: int = data["lod"]
	var was_near: bool = _chunks.get(key, {}).get("lod", -1) == 0
	if _chunks.has(key):
		(_chunks[key]["node"] as Node).queue_free()
		_chunks.erase(key)
	var root := Node3D.new()
	root.name = "Chunk_%d_%d%s" % [key.x, key.y, "" if lod == 0 else "_far"]
	add_child(root)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["verts"]
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_COLOR] = data["colors"]
	arrays[Mesh.ARRAY_CUSTOM0] = data["custom0"]
	arrays[Mesh.ARRAY_CUSTOM1] = data["custom1"]
	arrays[Mesh.ARRAY_INDEX] = data["indices"]
	var mesh := ArrayMesh.new()
	var flags := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	instance.material_override = _terrain_material
	var chunk := {"lod": lod, "node": root, "patches": [], "patch_biomes": []}
	if lod == 0:
		chunk["heights"] = data["heights"]
		var body := StaticBody3D.new()
		body.name = "Terrain"
		body.collision_layer = LAYER_TERRAIN
		body.add_child(instance)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(data["faces"])
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		root.add_child(body)
		_build_ponds(root, key)
		_build_props(root, data["props"], chunk)
	else:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)
		var far: Dictionary = data["far_trees"]
		for group: Array in far:
			var texture: Texture2D = group[0]
			var far_mesh := PropModels3D.foliage_mesh(texture, config.pixel_size * 1.6, group[2], true)
			var far_instance := _multimesh("FarTrees", far_mesh, far[group], 0.0)
			far_instance.material_override = FoliageMaterials.for_texture(texture, group[1], true, texture == PropArt.texture("glow_mushroom"))
			root.add_child(far_instance)
	_chunks[key] = chunk
	_rebuild_patch_lists()
	if lod == 0:
		chunk_built.emit(key, root)
	elif was_near:
		chunk_freed.emit(key)


func _build_props(root: Node3D, props: Dictionary, chunk: Dictionary) -> void:
	var count := 0
	for entry: Array in props["obstacles"]:
		count += 1
		var is_tree: bool = entry[5]
		var body := _obstacle(("Tree%d" if is_tree else "Rock%d") % count, entry[0], entry[1], entry[2], entry[3], entry[4], is_tree, entry[6])
		if is_tree:
			body.add_to_group(TREES_GROUP)
		root.add_child(body)
	var decor: Dictionary = props["decor"]
	for group: Array in decor:
		var texture: Texture2D = group[0]
		var visual := _decor_mesh(texture, group[1])
		var instance := _multimesh("Decor", visual["mesh"], decor[group], 0.0)
		instance.visibility_range_end = config.prop_view_distance
		if visual["material"] != null:
			instance.material_override = visual["material"]
		root.add_child(instance)
	for entry: Array in props["patches"]:
		var grass := _grass_quad(entry[1])
		var instance := _multimesh("TallGrass", grass["mesh"], entry[2], 1.0)
		instance.material_override = grass["material"]
		root.add_child(instance)
		(chunk["patches"] as Array).append(entry[0])
		(chunk["patch_biomes"] as Array).append(entry[3])


## Malla y material de una mata de hierba alta (mechón de hojas en V con grosor real, 3D de
## verdad en vez del plano billboard/la cruz de antes) con viento y empuje
## (world/terrain/tall_grass_3d.gdshader).
func _grass_quad(style: BiomeConfig) -> Dictionary:
	if _grass_quads.has(style):
		return _grass_quads[style]
	var size := style.tall_grass_texture.get_size() * config.pixel_size
	var material := ShaderMaterial.new()
	material.shader = TALL_GRASS_SHADER
	material.set_shader_parameter("blade_tex", style.tall_grass_texture)
	material.set_shader_parameter("tint_bottom", Vector3(style.tall_grass_tint_bottom.r, style.tall_grass_tint_bottom.g, style.tall_grass_tint_bottom.b))
	material.set_shader_parameter("tint_top", Vector3(style.tall_grass_tint_top.r, style.tall_grass_tint_top.g, style.tall_grass_tint_top.b))
	material.set_shader_parameter("blade_height", size.y)
	_grass_materials.append(material)
	var mesh := PropModels3D.foliage_mesh(style.tall_grass_texture, config.pixel_size, "tuft")
	var result := {"mesh": mesh, "material": material}
	_grass_quads[style] = result
	return result


## Malla y material de un objeto de decoración del campo abierto: ver
## PropModels3D.decor_visual (lo comparte con la decoración junto a los edificios del
## pueblo, structures.gd _decor_sprite).
func _decor_mesh(texture: Texture2D, tint: Color) -> Dictionary:
	return PropModels3D.decor_visual(texture, tint, config.pixel_size)


func _rebuild_patch_lists() -> void:
	tall_grass_patches = PackedVector3Array()
	tall_grass_biomes = PackedInt32Array()
	swamp_ponds = PackedVector3Array()
	swamp_pond_levels = PackedFloat32Array()
	for key: Vector2i in _chunks:
		var chunk: Dictionary = _chunks[key]
		for i in (chunk["patches"] as Array).size():
			tall_grass_patches.append(chunk["patches"][i])
			tall_grass_biomes.append(chunk["patch_biomes"][i])
		if chunk["lod"] == 0:
			for pond: Vector4 in _ponds_of(key):
				swamp_ponds.append(Vector3(pond.x, pond.y, pond.z))
				swamp_pond_levels.append(pond.w)


## Forma de copa para un árbol de ese bioma/textura (PropModels3D.foliage_mesh): "pradera
## redondo, bosque, pino/nevado, palmera, árbol seco... hongo gigante" (pedido de Fernando,
## 2026-10-11). Primero deduce por la textura (cactus/palmera/acacia/hongo, que siempre son
## la misma forma venga del bioma que venga) y por si es el tronco muerto fijo; si no, por
## bioma (las texturas de meadow/forest/mountain.tree_textures se repiten entre biomas —
## p. ej. tree_round.png la usan pradera y bosque — así que la forma la decide el bioma
## donde se está plantando, no solo la imagen).
func _tree_shape(biome: int, texture: Texture2D) -> String:
	var auto := PropModels3D.auto_shape(texture)
	if auto != "":
		return auto
	if texture == config.dead_tree_texture:
		return "dead"
	match biome:
		RegionLayout.Biome.FOREST, RegionLayout.Biome.JUNGLE, RegionLayout.Biome.DARK_FOREST, RegionLayout.Biome.MUSHROOM, RegionLayout.Biome.SWAMP:
			return "forest"
		RegionLayout.Biome.MOUNTAIN, RegionLayout.Biome.TUNDRA:
			return "pine"
		_:
			return "round"


## Densidad (por zona de 128 m) y arte de cada bioma de la región.
func _build_styles() -> void:
	var meadow := config.meadow
	var forest := config.forest
	var mountain := config.mountain
	var dead: Array = [config.dead_tree_texture] if config.dead_tree_texture != null else []
	var cactus := PropArt.texture("cactus")
	var palm := PropArt.texture("palm")
	var acacia := PropArt.texture("acacia")
	var mushrooms: Array = [PropArt.texture("mushroom"), PropArt.texture("glow_mushroom")]
	for biome in RegionLayout.Biome.values():
		var style := {"trees": [], "tree_density": 0.0, "big": 0.3, "rocks": [], "rock_density": 0.0, "decor": [],
				"decor_density": 0.0, "grass": null, "grass_chance": 0.0, "tint": Color.WHITE}
		match biome:
			RegionLayout.Biome.MEADOW:
				style.merge({"trees": meadow.tree_textures, "tree_density": 5.0, "rocks": meadow.rock_textures, "rock_density": 3.0,
						"decor": meadow.decor_textures, "decor_density": 80.0, "grass": meadow, "grass_chance": 0.7}, true)
			RegionLayout.Biome.FLOWERS:
				style.merge({"trees": meadow.tree_textures, "tree_density": 2.0, "decor": meadow.decor_textures, "decor_density": 240.0,
						"grass": meadow, "grass_chance": 0.4, "tint": Color(1.05, 1.0, 1.05)}, true)
			RegionLayout.Biome.SAVANNA:
				style.merge({"trees": [acacia], "tree_density": 5.0, "big": 0.0, "rocks": meadow.rock_textures, "rock_density": 3.0,
						"decor": meadow.decor_textures, "decor_density": 40.0, "grass": meadow, "grass_chance": 0.8, "tint": Color(1.12, 1.0, 0.62)}, true)
			RegionLayout.Biome.FOREST:
				style.merge({"trees": forest.tree_textures, "tree_density": 38.0, "rocks": forest.rock_textures, "rock_density": 3.0,
						"decor": forest.decor_textures, "decor_density": 70.0, "grass": forest, "grass_chance": 0.6}, true)
			RegionLayout.Biome.JUNGLE:
				style.merge({"trees": forest.tree_textures + [palm], "tree_density": 46.0, "decor": forest.decor_textures, "decor_density": 110.0,
						"grass": forest, "grass_chance": 0.8, "tint": Color(0.78, 1.0, 0.75)}, true)
			RegionLayout.Biome.DARK_FOREST:
				style.merge({"trees": forest.tree_textures + dead, "tree_density": 52.0, "rocks": forest.rock_textures, "rock_density": 4.0,
						"decor": forest.decor_textures, "decor_density": 40.0, "grass": forest, "grass_chance": 0.4, "tint": Color(0.62, 0.7, 0.72)}, true)
			RegionLayout.Biome.MUSHROOM:
				style.merge({"trees": mushrooms + forest.tree_textures, "tree_density": 26.0, "big": 0.5, "decor": forest.decor_textures,
						"decor_density": 60.0, "grass": forest, "grass_chance": 0.5, "tint": Color(0.95, 0.85, 1.05)}, true)
			RegionLayout.Biome.MOUNTAIN:
				style.merge({"trees": mountain.tree_textures, "tree_density": 5.0, "rocks": mountain.rock_textures, "rock_density": 12.0,
						"decor": mountain.decor_textures, "decor_density": 25.0}, true)
			RegionLayout.Biome.MESA, RegionLayout.Biome.CANYON:
				style.merge({"rocks": mountain.rock_textures, "rock_density": 12.0, "trees": [cactus], "tree_density": 2.0, "tint": Color(1.15, 0.78, 0.6)}, true)
			RegionLayout.Biome.TUNDRA:
				style.merge({"trees": mountain.tree_textures, "tree_density": 8.0, "rocks": mountain.rock_textures, "rock_density": 6.0,
						"tint": Color(0.88, 0.95, 1.1)}, true)
			RegionLayout.Biome.VOLCANO:
				style.merge({"trees": dead, "tree_density": 3.0, "rocks": mountain.rock_textures, "rock_density": 14.0, "tint": Color(0.5, 0.45, 0.45)}, true)
			RegionLayout.Biome.DESERT:
				style.merge({"trees": [cactus], "tree_density": 8.0, "big": 0.2, "rocks": mountain.rock_textures, "rock_density": 4.0, "tint": Color(1.1, 0.95, 0.75)}, true)
			RegionLayout.Biome.SWAMP:
				style.merge({"trees": dead + forest.tree_textures, "tree_density": 12.0, "decor": forest.decor_textures, "decor_density": 40.0,
						"grass": forest, "grass_chance": 0.5}, true)
			RegionLayout.Biome.TOXIC_SWAMP:
				style.merge({"trees": dead, "tree_density": 10.0, "decor": forest.decor_textures, "decor_density": 30.0, "tint": Color(0.85, 0.7, 1.0)}, true)
			RegionLayout.Biome.BEACH:
				style.merge({"trees": [palm], "tree_density": 4.0, "big": 0.0, "rocks": mountain.rock_textures, "rock_density": 2.0}, true)
		# Kit del bioma (acordado con Fernando el 2026-10-10): objetos propios de cada zona
		# que se suman a la decoración, para que nada se vea vacío.
		var kit: Array = BIOME_KITS.get(biome, []).map(func(kind: String) -> Texture2D: return PropArt.texture(kind))
		if not kit.is_empty():
			style["decor"] = (style["decor"] as Array) + kit + kit
			style["decor_density"] = float(style["decor_density"]) + float(KIT_DENSITY.get(biome, 40.0))
		_styles[biome] = style


## Objetos de cada bioma (PropArt) y cuántos más por zona.
const BIOME_KITS := {
	RegionLayout.Biome.MEADOW: ["flowers_pink", "flowers_white", "boulder", "old_fence", "log"],
	RegionLayout.Biome.FLOWERS: ["flowers_pink", "flowers_blue", "flowers_white"],
	RegionLayout.Biome.SAVANNA: ["dry_bush", "boulder", "bones"],
	RegionLayout.Biome.FOREST: ["mossy_log", "mossy_rock", "brown_mushroom", "log"],
	RegionLayout.Biome.JUNGLE: ["mossy_log", "flowers_pink", "brown_mushroom"],
	RegionLayout.Biome.DARK_FOREST: ["mossy_log", "toxic_mushroom", "mossy_rock"],
	RegionLayout.Biome.MUSHROOM: ["brown_mushroom", "toxic_mushroom", "mossy_log"],
	RegionLayout.Biome.MOUNTAIN: ["boulder", "mossy_rock", "dry_bush"],
	RegionLayout.Biome.MESA: ["boulder", "bones", "dry_bush"],
	RegionLayout.Biome.CANYON: ["boulder", "bones", "dry_bush"],
	RegionLayout.Biome.DESERT: ["bones", "dry_bush", "boulder"],
	RegionLayout.Biome.TUNDRA: ["snow_pile", "ice_crystal", "boulder"],
	RegionLayout.Biome.VOLCANO: ["lava_rock", "bones", "dry_bush"],
	RegionLayout.Biome.SWAMP: ["reeds", "cattails", "mossy_log", "brown_mushroom"],
	RegionLayout.Biome.TOXIC_SWAMP: ["toxic_mushroom", "cattails", "bones", "mossy_log"],
	RegionLayout.Biome.BEACH: ["shell", "shell_blue", "driftwood"],
}
const KIT_DENSITY := {RegionLayout.Biome.SWAMP: 140.0, RegionLayout.Biome.TOXIC_SWAMP: 140.0, RegionLayout.Biome.MEADOW: 110.0, RegionLayout.Biome.SAVANNA: 70.0, RegionLayout.Biome.FOREST: 60.0,
		RegionLayout.Biome.BEACH: 60.0, RegionLayout.Biome.DESERT: 30.0, RegionLayout.Biome.TUNDRA: 50.0, RegionLayout.Biome.VOLCANO: 40.0}


# --- Agua ----------------------------------------------------------------------------------

func _water_material(texture: Texture2D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("water_tex", texture)
	material.set_shader_parameter("px_per_meter", 1.0 / config.pixel_size)
	return material


## Mar (un plano grande bajo todo), lagos (discos) y ríos (cintas a su nivel).
func _build_water() -> void:
	var water := Node3D.new()
	water.name = "Water"
	add_child(water)
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(config.size + FRONTIER_WIDTH * 2.0 + 200.0, config.size + FRONTIER_WIDTH * 2.0 + 200.0)
	sea.mesh = plane
	sea.position = Vector3(0.0, layout.sea_level, 0.0)
	sea.material_override = _water_fresh
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.add_child(sea)
	for lake in layout.lakes:
		water.add_child(_water_disc("Lake", Vector2(lake.x, lake.y), lake.z + RegionLayout.LAKE_BANK * RegionLayout.WATER_EDGE, lake.w, _water_fresh, 48))
	for river in layout.rivers:
		water.add_child(_river_ribbon(river))
		_build_waterfalls(water, river)


func _water_disc(disc_name: String, center: Vector2, radius: float, level: float, material: Material, segments: int) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	disc.name = disc_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.01
	mesh.radial_segments = segments
	mesh.rings = 1
	disc.mesh = mesh
	disc.position = Vector3(center.x, level, center.y)
	disc.material_override = material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return disc


func _river_ribbon(river: Dictionary) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: PackedVector2Array = river["points"]
	var levels: PackedFloat32Array = river["levels"]
	var half := float(river["width"]) * 0.5 + RegionLayout.RIVER_BANK * RegionLayout.WATER_EDGE
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for i in pts.size():
		var dir := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var normal := Vector2(-dir.y, dir.x)
		left.append(Vector3(pts[i].x + normal.x * half, levels[i], pts[i].y + normal.y * half))
		right.append(Vector3(pts[i].x - normal.x * half, levels[i], pts[i].y - normal.y * half))
	for i in pts.size() - 1:
		for v: Vector3 in [left[i], left[i + 1], right[i + 1], left[i], right[i + 1], right[i]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
		# Por las dos caras (la dirección del río decide el sentido de los triángulos).
		for v: Vector3 in [left[i], right[i + 1], left[i + 1], left[i], right[i], right[i + 1]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var instance := MeshInstance3D.new()
	instance.name = "River"
	instance.mesh = st.commit()
	instance.material_override = _water_fresh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## Cascadas: donde el río baja más de 1.2 m entre dos puntos, una cortina de agua con espuma.
func _build_waterfalls(parent: Node3D, river: Dictionary) -> void:
	var pts: PackedVector2Array = river["points"]
	var levels: PackedFloat32Array = river["levels"]
	var width := float(river["width"])
	for i in pts.size() - 1:
		var drop := levels[i] - levels[i + 1]
		if drop < 1.2:
			continue
		var mid := (pts[i] + pts[i + 1]) * 0.5
		var dir := (pts[i + 1] - pts[i]).normalized()
		var fall := MeshInstance3D.new()
		fall.name = "Waterfall"
		var quad := QuadMesh.new()
		quad.size = Vector2(width + 2.0, drop + 0.6)
		fall.mesh = quad
		fall.material_override = _water_fresh
		fall.position = Vector3(mid.x, (levels[i] + levels[i + 1]) * 0.5, mid.y)
		fall.rotation.y = atan2(dir.x, dir.y)
		fall.rotation.x = -0.25
		fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(fall)
		var foam := CPUParticles3D.new()
		foam.amount = 24
		foam.lifetime = 1.0
		foam.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		foam.emission_box_extents = Vector3(width * 0.5, 0.2, 0.5)
		foam.direction = Vector3.UP
		foam.initial_velocity_min = 1.0
		foam.initial_velocity_max = 2.5
		foam.gravity = Vector3(0, -4, 0)
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.25, 0.25)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.albedo_color = Color(1, 1, 1, 0.8)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = material
		foam.mesh = mesh
		foam.position = Vector3(pts[i + 1].x, levels[i + 1] + 0.1, pts[i + 1].y)
		foam.visibility_range_end = 150.0
		parent.add_child(foam)


func _build_ponds(root: Node3D, key: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ (layout.seed + 77)
	for pond: Vector4 in _ponds_of(key):
		var toxic := layout.biome_at(pond.x, pond.y) == RegionLayout.Biome.TOXIC_SWAMP
		var radius := pond.z + POND_BANK * RegionLayout.WATER_EDGE
		root.add_child(_water_disc("Pond", Vector2(pond.x, pond.y), radius, pond.w, _water_toxic if toxic else _water_swamp, 20))
		if toxic:
			# Pantano tóxico: charca morada que burbujea.
			root.add_child(_bubbles(Vector3(pond.x, pond.w + 0.05, pond.y), pond.z))
		else:
			# Pantano: nenúfares flotando (algunos con flor).
			for i in rng.randi_range(3, 7):
				var angle := rng.randf() * TAU
				var r := sqrt(rng.randf()) * pond.z * 0.85
				var texture := PropArt.texture("lily_flower" if rng.randf() < 0.3 else "lily_pad")
				var pad := MeshInstance3D.new()
				pad.name = "LilyPad"
				pad.mesh = PropModels3D.pad_mesh(texture, config.pixel_size * 1.4)
				pad.material_override = FoliageMaterials.for_texture(texture, Color.WHITE, true, false)
				pad.rotation_degrees.y = rng.randf() * 360.0
				pad.position = Vector3(pond.x + cos(angle) * r, pond.w, pond.y + sin(angle) * r)
				pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(pad)
		# Neblina baja sobre las charcas de los pantanos.
		root.add_child(_mist(Vector3(pond.x, pond.w + 0.4, pond.y), pond.z + 3.0, Color(0.75, 0.6, 0.9, 0.25) if toxic else Color(0.85, 0.92, 0.85, 0.2)))


## Burbujas moradas que suben y revientan (pantano tóxico).
func _bubbles(at: Vector3, radius: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.position = at
	particles.amount = 10
	particles.lifetime = 1.6
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius * 0.7
	particles.direction = Vector3.UP
	particles.initial_velocity_min = 0.2
	particles.initial_velocity_max = 0.5
	particles.gravity = Vector3.ZERO
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	var quad := QuadMesh.new()
	quad.size = Vector2(0.25, 0.25)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.75, 0.4, 0.95, 0.8)
	quad.material = material
	particles.mesh = quad
	particles.visibility_range_end = 90.0
	return particles


static var _blob: Texture2D


## Mancha suave (degradado radial) para la neblina.
static func _soft_blob() -> Texture2D:
	if _blob == null:
		var image := Image.create_empty(64, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 64:
				var d := Vector2((x - 31.5) / 32.0, (y - 15.5) / 16.0).length()
				image.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) * 0.8))
		_blob = ImageTexture.create_from_image(image)
	return _blob


## Neblina baja (manchas translúcidas que flotan despacio).
func _mist(at: Vector3, radius: float, color: Color) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.position = at
	particles.amount = 6
	particles.lifetime = 6.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(radius, 0.2, radius)
	particles.direction = Vector3(1, 0, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = 0.1
	particles.initial_velocity_max = 0.3
	particles.gravity = Vector3.ZERO
	var quad := QuadMesh.new()
	quad.size = Vector2(4.0, 1.4)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.albedo_texture = _soft_blob()
	quad.material = material
	particles.mesh = quad
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	fade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	particles.color_ramp = fade
	particles.visibility_range_end = 80.0
	return particles


# --- Materiales y utilidades ------------------------------------------------------------

func _build_materials() -> void:
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = TERRAIN_SHADER
	var meadow := config.meadow
	var forest := config.forest
	var mountain := config.mountain
	_terrain_material.set_shader_parameter("meadow_grass", meadow.grass_texture)
	_terrain_material.set_shader_parameter("meadow_grass_light", meadow.grass_light_texture)
	_terrain_material.set_shader_parameter("meadow_path", meadow.path_texture)
	_terrain_material.set_shader_parameter("meadow_slope", meadow.slope_texture)
	_terrain_material.set_shader_parameter("forest_grass", forest.grass_texture)
	_terrain_material.set_shader_parameter("forest_grass_light", forest.grass_light_texture)
	_terrain_material.set_shader_parameter("forest_slope", forest.slope_texture)
	_terrain_material.set_shader_parameter("mountain_grass", mountain.grass_texture)
	_terrain_material.set_shader_parameter("mountain_grass_light", mountain.grass_light_texture)
	_terrain_material.set_shader_parameter("mountain_slope", mountain.slope_texture)
	_terrain_material.set_shader_parameter("beach_sand", config.beach_texture)
	_terrain_material.set_shader_parameter("swamp_ground", config.swamp_ground_texture)
	_terrain_material.set_shader_parameter("patch_noise", _noise_texture(layout.seed + 5, 0.02))
	_terrain_material.set_shader_parameter("rock_height", config.rock_height)
	_terrain_material.set_shader_parameter("snow_height", config.snow_height)
	_terrain_material.set_shader_parameter("px_per_meter", 1.0 / config.pixel_size)
	_water_fresh = _water_material(config.water_texture)
	_water_swamp = _water_material(config.swamp_water_texture)
	# Pantano tóxico: la misma agua teñida de morado.
	_water_toxic = _water_material(config.swamp_water_texture)
	_water_toxic.set_shader_parameter("tint", Color(0.75, 0.45, 0.95))


func _noise_texture(noise_seed: int, frequency: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	return texture


## Los actores más cercanos a la cámara apartan la hierba alta.
func _update_grass_pushers() -> void:
	if _grass_materials.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	var pushers := get_tree().get_nodes_in_group(GRASS_PUSHERS_GROUP)
	if camera != null and pushers.size() > MAX_GRASS_ACTORS:
		var cam_pos := camera.global_position
		pushers.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return a.global_position.distance_squared_to(cam_pos) < b.global_position.distance_squared_to(cam_pos))
	var actors := PackedVector4Array()
	actors.resize(MAX_GRASS_ACTORS)
	for i in mini(pushers.size(), MAX_GRASS_ACTORS):
		var p := (pushers[i] as Node3D).global_position
		actors[i] = Vector4(p.x, p.y, p.z, 1.1)
	for material in _grass_materials:
		material.set_shader_parameter("actors", actors)


func _multimesh(instance_name: String, mesh: Mesh, positions: PackedVector3Array, cull_margin: float) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = positions.size()
	for i in positions.size():
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, positions[i]))
	var instance := MultiMeshInstance3D.new()
	instance.name = instance_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.layers = VISUAL_LAYER_SPRITES
	instance.extra_cull_margin = cull_margin
	return instance


## Árbol o roca en 3D (de pocas caras, estilo B2W2) apoyado en el suelo (posición ya con
## la altura), con sombra de contacto y colisión en la capa de obstáculos. Los árboles son
## tronco + copa de volúmenes reales con su textura pixel (siguen la luz y, si son follaje,
## el tinte de estación: PropModels3D.foliage_mesh + FoliageMaterials, forma por bioma de
## _tree_shape); las rocas reusan la malla de BreakableRock con color plano. Algunos
## troncos muertos usan el modelo real de B2W2 (regla 1 de docs/reglas_calidad.md,
## 2026-10-10: nada plano salvo Pokémon/personajes/NPC).
func _obstacle(obstacle_name: String, texture: Texture2D, scale_factor: float, radius: float, position_3d: Vector3, tint: Color, foliage: bool = false, shape: String = "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = obstacle_name
	body.collision_layer = LAYER_OBSTACLES
	var width := texture.get_size().x * config.pixel_size * scale_factor
	var height := texture.get_size().y * config.pixel_size * scale_factor
	body.position = position_3d
	body.add_child(_contact_shadow(width * 1.1))
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.scale = Vector3.ONE * scale_factor
	body.add_child(visual)
	if foliage:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = PropModels3D.foliage_mesh(texture, config.pixel_size, shape)
		var glow := texture == PropArt.texture("glow_mushroom")
		var seasonal := not glow and texture != PropArt.texture("cactus") and texture != PropArt.texture("palm")
		mesh_instance.material_override = FoliageMaterials.for_texture(texture, tint, seasonal, glow)
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_instance.visibility_range_end = config.prop_view_distance * (1.5 if scale_factor > 1.0 else 1.0)
		visual.add_child(mesh_instance)
		# El tronco muerto (pantano, pantano tóxico, bosque oscuro y volcán) usa el modelo
		# real de B2W2 cuando existe: más variedad que la cruz genérica.
		if texture == config.dead_tree_texture:
			var model: Dictionary = PropModels3D.instance("dead_tree1" if hash(obstacle_name) % 2 == 0 else "dead_tree2")
			if not model.is_empty():
				mesh_instance.visible = false
				var real := model["node"] as Node3D
				var target_height: float = height
				var model_size: Vector3 = model["size"]
				if model_size.y > 0.01:
					real.scale = Vector3.ONE * (target_height / model_size.y)
				visual.add_child(real)
	else:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = PropModels3D.rock_mesh("%s:%.1f:%.1f" % [obstacle_name, position_3d.x, position_3d.z], Vector3(width, height, width))
		mesh_instance.material_override = PropModels3D.solid_material(tint * Color(0.62, 0.6, 0.58))
		mesh_instance.position.y = height * 0.5
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_instance.visibility_range_end = config.prop_view_distance * (1.5 if scale_factor > 1.0 else 1.0)
		visual.add_child(mesh_instance)
	body.set_meta("obstacle_height", height)
	var collision_shape := CylinderShape3D.new()
	collision_shape.radius = radius * scale_factor
	collision_shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = collision_shape
	collision.position.y = height * 0.5
	body.add_child(collision)
	return body


func _contact_shadow(diameter: float) -> Decal:
	if _shadow_texture == null:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(0, 0, 0, config.contact_shadow_alpha), Color(0, 0, 0, 0)])
		_shadow_texture = GradientTexture2D.new()
		_shadow_texture.gradient = gradient
		_shadow_texture.width = 64
		_shadow_texture.height = 64
		_shadow_texture.fill = GradientTexture2D.FILL_RADIAL
		_shadow_texture.fill_from = Vector2(0.5, 0.5)
		_shadow_texture.fill_to = Vector2(1.0, 0.5)
	var decal := Decal.new()
	decal.name = "ContactShadow"
	decal.texture_albedo = _shadow_texture
	decal.size = Vector3(diameter, 3.0, diameter * 0.8)
	decal.position.y = config.obstacle_sink
	decal.upper_fade = 0.2
	decal.lower_fade = 0.6
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = config.prop_view_distance * 0.5
	decal.distance_fade_length = 20.0
	decal.cull_mask = 1
	return decal


# --- Borde del mundo ----------------------------------------------------------------------

const FRONTIER_WIDTH := 700.0
const FRONTIER_CELL := 24.0


## Cordillera afuera del área jugable (norte, este y oeste) y fondo marino al sur, con
## colisión propia para que la cámara no la atraviese (no está en la capa del terreno,
## así la navegación no la incluye).
func _build_frontier() -> void:
	var half := config.size * 0.5
	var outer := half + FRONTIER_WIDTH
	var cells := int(ceil(outer * 2.0 / FRONTIER_CELL))
	var verts := cells + 1
	var inner := half - FRONTIER_CELL
	var heights := PackedFloat32Array()
	heights.resize(verts * verts)
	for iz in verts:
		for ix in verts:
			var x := ix * FRONTIER_CELL - outer
			var z := iz * FRONTIER_CELL - outer
			if absf(x) < inner - FRONTIER_CELL and absf(z) < inner - FRONTIER_CELL:
				continue
			heights[iz * verts + ix] = frontier_height_at(x, z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
	for iz in cells:
		for ix in cells:
			var x0 := ix * FRONTIER_CELL - outer
			var z0 := iz * FRONTIER_CELL - outer
			if x0 >= -inner and x0 + FRONTIER_CELL <= inner and z0 >= -inner and z0 + FRONTIER_CELL <= inner:
				continue
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var x := (ix + corner.x) * FRONTIER_CELL - outer
				var z := (iz + corner.y) * FRONTIER_CELL - outer
				var sea := z > half - RegionLayout.SEA_BAND
				st.set_color(Color(1, 1, 1))
				st.set_custom(0, Color(0, 0, 0, 1) if sea else Color(0, 0, 1, 0))
				st.set_custom(1, Color(0, 0, 0, 0))
				st.add_vertex(Vector3(x, heights[(iz + corner.y) * verts + ix + corner.x], z))
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	var body := StaticBody3D.new()
	body.name = "Frontier"
	body.collision_layer = LAYER_FRONTIER
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _terrain_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(instance)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)


## Altura de la franja exterior: bajo el terreno dentro del área (para no dejar
## rendijas), cordillera afuera y fondo marino al sur de la costa.
func frontier_height_at(x: float, z: float) -> float:
	var half := config.size * 0.5
	var inside_x := clampf(x, -half, half)
	var inside_z := clampf(z, -half, half)
	var d := Vector2(x - inside_x, z - inside_z).length()
	var edge := layout.base_height(inside_x, inside_z)
	if d <= 0.0:
		return edge - 3.0
	var ridge := 1.0 - absf(layout._ridge.get_noise_2d(x * 0.5, z * 0.5))
	var peaks := 60.0 + ridge * ridge * 90.0 + layout._detail.get_noise_2d(x * 0.2, z * 0.2) * 15.0
	var mountain := edge + peaks * (1.0 - exp(-d / 60.0))
	var seabed := layout.sea_level - 8.0 - d * 0.05
	var sea_factor := smoothstep(half - RegionLayout.SEA_BAND - 60.0, half - RegionLayout.SEA_BAND + 60.0, z)
	return lerpf(mountain, seabed, sea_factor)


func _build_walls() -> void:
	var half := config.size * 0.5
	var walls := Node3D.new()
	walls.name = "Walls"
	add_child(walls)
	var sides: Array[Vector3] = [Vector3(half, 0, 0), Vector3(-half, 0, 0), Vector3(0, 0, half), Vector3(0, 0, -half)]
	for i in sides.size():
		var side := sides[i]
		var box := BoxShape3D.new()
		var along_x := absf(side.z) > 0.0
		box.size = Vector3(config.size if along_x else 1.0, 800.0, 1.0 if along_x else config.size)
		var body := StaticBody3D.new()
		body.name = "Wall%d" % i
		body.collision_layer = LAYER_OBSTACLES
		body.position = side + Vector3.UP * 300.0
		var collision := CollisionShape3D.new()
		collision.shape = box
		body.add_child(collision)
		walls.add_child(body)
