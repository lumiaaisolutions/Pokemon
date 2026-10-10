class_name WorldMapData
extends RefCounted
## Imagen del mapa de la región (pixel art, 8 m por píxel) y niebla de exploración
## (8 m por píxel). La comparten el minimapa, el mapa completo y la Pokédex. La imagen
## se calcula en un hilo con las funciones puras de RegionLayout y se guarda en
## user://map_<semilla>.png para que la siguiente vez cargue al instante.

signal ready

const METERS_PER_PIXEL := 8.0
const FOG_METERS_PER_PIXEL := 8.0
## Radio que se descubre alrededor del jugador al explorar.
const REVEAL_RADIUS := 60.0

const MEADOW := Color(0.47, 0.75, 0.38)
const FOREST := Color(0.2, 0.47, 0.27)
const MOUNTAIN := Color(0.62, 0.52, 0.38)
const ROCK := Color(0.66, 0.62, 0.56)
const SNOW := Color(0.92, 0.95, 1.0)
const BEACH := Color(0.93, 0.86, 0.62)
const WATER := Color(0.27, 0.53, 0.88)
const SEA := Color(0.2, 0.42, 0.8)
const SWAMP_WATER := Color(0.25, 0.5, 0.5)
const SWAMP := Color(0.36, 0.5, 0.33)
const PATH := Color(0.85, 0.75, 0.52)
const TOWN := Color(0.85, 0.82, 0.78)
## Color de cada bioma de la región (RegionLayout.Biome).
const BIOME_COLORS := [MEADOW, FOREST, MOUNTAIN, BEACH, Color(0.9, 0.8, 0.55), Color(0.78, 0.5, 0.36), Color(0.75, 0.75, 0.42),
	Color(0.15, 0.55, 0.25), Color(0.85, 0.9, 0.95), Color(0.4, 0.33, 0.32), Color(0.62, 0.8, 0.45), Color(0.55, 0.45, 0.6),
	Color(0.15, 0.3, 0.25), SWAMP, Color(0.45, 0.35, 0.55), Color(0.8, 0.55, 0.4), SEA]

var map_texture: ImageTexture
var fog_texture: ImageTexture
var size_m: float = 4096.0
var is_ready := false
var _fog: Image
var _image: Image
var _task := -1
var _layout: RegionLayout
var _snow_height := 62.0
var _rock_height := 45.0


## Prepara la niebla y lanza el cálculo de la imagen (o la carga del caché).
func build(world: WorldBuilder) -> void:
	size_m = world.config.size
	_layout = world.layout
	_snow_height = world.config.snow_height
	_rock_height = world.config.rock_height
	var fog_side := int(size_m / FOG_METERS_PER_PIXEL)
	_fog = Image.create_empty(fog_side, fog_side, false, Image.FORMAT_L8)
	_fog.fill(Color.BLACK)
	var saved := str(GameState.world_flags.get("map_fog", ""))
	if saved != "":
		var bytes := Marshalls.base64_to_raw(saved).decompress(fog_side * fog_side, FileAccess.COMPRESSION_GZIP)
		if bytes.size() == fog_side * fog_side:
			_fog = Image.create_from_data(fog_side, fog_side, false, Image.FORMAT_L8, bytes)
	fog_texture = ImageTexture.create_from_image(_fog)
	var side := int(size_m / METERS_PER_PIXEL)
	map_texture = ImageTexture.create_from_image(Image.create_empty(side, side, false, Image.FORMAT_RGB8))
	var cache := _cache_path()
	if FileAccess.file_exists(cache):
		var image := Image.load_from_file(cache)
		if image != null and image.get_width() == side:
			_finish(image)
			return
	_task = WorkerThreadPool.add_task(_compute, false, "Mapa")


func _cache_path() -> String:
	return "user://map_%d_v2.png" % _layout.seed


## Espera el hilo si ya terminó (lo llama el mapa cada cuadro).
func poll() -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_image.save_png(_cache_path())
		_finish(_image)


## Espera a que la imagen esté lista (pruebas y Pokédex).
func wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_image.save_png(_cache_path())
		_finish(_image)


func _finish(image: Image) -> void:
	_image = image
	map_texture.set_image(image)
	is_ready = true
	ready.emit()


## Calcula la imagen (en un hilo): agua, caminos, pueblos y biomas con relieve.
func _compute() -> void:
	var side := int(size_m / METERS_PER_PIXEL)
	var half := size_m * 0.5
	var image := Image.create_empty(side, side, false, Image.FORMAT_RGB8)
	for pz in side:
		for px in side:
			var x := (px + 0.5) * METERS_PER_PIXEL - half
			var z := (pz + 0.5) * METERS_PER_PIXEL - half
			var height := _layout.height_at(x, z)
			var biome := _layout.biome_at(x, z)
			var color: Color
			var depth := _layout.water_level_at(x, z) - height
			if depth > 0.2:
				color = SEA if biome in [RegionLayout.Biome.SEA, RegionLayout.Biome.BEACH] else (SWAMP_WATER if RegionLayout.FAMILY[biome] == 4 else WATER)
				color = color.darkened(clampf(depth * 0.04, 0.0, 0.35))
			elif _layout.road_info(x, z).x < METERS_PER_PIXEL * 0.6:
				color = PATH
			elif _in_town(x, z):
				color = TOWN
			else:
				color = BIOME_COLORS[biome]
				if RegionLayout.FAMILY[biome] == 2 and biome != RegionLayout.Biome.TUNDRA:
					color = SNOW if height > _snow_height and biome == RegionLayout.Biome.MOUNTAIN else (ROCK if height > _rock_height else color)
				# Relieve: luz del noroeste.
				var slope := _layout.height_at(x - METERS_PER_PIXEL, z - METERS_PER_PIXEL) - height
				color = color.lightened(clampf(slope * 0.05, 0.0, 0.25)) if slope > 0.0 else color.darkened(clampf(-slope * 0.05, 0.0, 0.3))
			image.set_pixel(px, pz, color)
	_image = image


func _in_town(x: float, z: float) -> bool:
	for s: Dictionary in _layout._flat_buckets.get(_layout._bucket(x, z), []):
		if s["kind"] != "sanctuary" and Vector2(x - float(s["x"]), z - float(s["z"])).length() < float(s["radius"]) * 0.85:
			return true
	return false


## Descubre la zona alrededor de point. Devuelve true si cambió algo.
func reveal(point: Vector3, radius: float = REVEAL_RADIUS) -> bool:
	if _fog == null or point.x > WorldBuilder.INTERIOR_X:
		return false
	var half := size_m * 0.5
	var side := _fog.get_width()
	var cx := int((point.x + half) / FOG_METERS_PER_PIXEL)
	var cz := int((point.z + half) / FOG_METERS_PER_PIXEL)
	var r := int(radius / FOG_METERS_PER_PIXEL)
	var changed := false
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz > r * r:
				continue
			var px := cx + dx
			var pz := cz + dz
			if px < 0 or pz < 0 or px >= side or pz >= side:
				continue
			if _fog.get_pixel(px, pz).r < 0.5:
				_fog.set_pixel(px, pz, Color.WHITE)
				changed = true
	if changed:
		fog_texture.update(_fog)
	return changed


## Guarda la niebla (comprimida) en las banderas del mundo antes de guardar partida.
func store_fog() -> void:
	if _fog != null:
		GameState.world_flags["map_fog"] = Marshalls.raw_to_base64(_fog.get_data().compress(FileAccess.COMPRESSION_GZIP))


func is_revealed(point: Vector3) -> bool:
	if _fog == null:
		return false
	var half := size_m * 0.5
	var px := int((point.x + half) / FOG_METERS_PER_PIXEL)
	var pz := int((point.z + half) / FOG_METERS_PER_PIXEL)
	if px < 0 or pz < 0 or px >= _fog.get_width() or pz >= _fog.get_height():
		return false
	return _fog.get_pixel(px, pz).r > 0.5


## Fracción del mundo descubierta (0–1).
func explored_ratio() -> float:
	var data := _fog.get_data()
	var seen := 0
	for value in data:
		if value > 127:
			seen += 1
	return float(seen) / data.size()


## Coordenadas UV del mapa (0–1) de un punto del mundo.
func world_to_uv(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z) / size_m + Vector2(0.5, 0.5)
