class_name WorldMapData
extends RefCounted
## Imagen del mapa del mundo (pixel art, 2 m por píxel) y niebla de exploración
## (4 m por píxel). La comparten el minimapa y el mapa completo.

const METERS_PER_PIXEL := 2.0
const FOG_METERS_PER_PIXEL := 4.0
## Radio que se descubre alrededor del jugador al explorar.
const REVEAL_RADIUS := 40.0

const MEADOW := Color(0.47, 0.75, 0.38)
const FOREST := Color(0.2, 0.47, 0.27)
const MOUNTAIN := Color(0.62, 0.52, 0.38)
const ROCK := Color(0.66, 0.62, 0.56)
const SNOW := Color(0.92, 0.95, 1.0)
const BEACH := Color(0.93, 0.86, 0.62)
const WATER := Color(0.27, 0.53, 0.88)
const SWAMP_WATER := Color(0.25, 0.5, 0.5)
const SWAMP := Color(0.36, 0.5, 0.33)
const PATH := Color(0.85, 0.75, 0.52)

var map_texture: ImageTexture
var fog_texture: ImageTexture
var size_m: float = 480.0
var _fog: Image


## Construye la imagen a partir del mundo ya generado.
func build(world: WorldBuilder) -> void:
	size_m = world.config.size
	var side := int(size_m / METERS_PER_PIXEL)
	var half := size_m * 0.5
	var image := Image.create_empty(side, side, false, Image.FORMAT_RGB8)
	var paths := world.config.paths
	for pz in side:
		for px in side:
			var x := (px + 0.5) * METERS_PER_PIXEL - half
			var z := (pz + 0.5) * METERS_PER_PIXEL - half
			var height := world.surface_height_at(x, z)
			var color: Color
			if world.water_depth_at(x, z) > 0.2:
				color = SWAMP_WATER if Vector2(x, z).distance_to(world.config.swamp_center) < world.config.swamp_radius else WATER
			elif world.distance_to_paths(x, z) < world.config.path_width * 0.6:
				color = PATH
			else:
				match world.dominant_biome(x, z):
					WorldBuilder.Biome.FOREST:
						color = SWAMP if Vector2(x, z).distance_to(world.config.swamp_center) < world.config.swamp_radius else FOREST
					WorldBuilder.Biome.MOUNTAIN:
						color = SNOW if height > world.config.snow_height else (ROCK if height > world.config.rock_height else MOUNTAIN)
					WorldBuilder.Biome.BEACH:
						color = BEACH
					_:
						color = MEADOW
				# Relieve: luz del noroeste (sombreado por pendiente).
				var slope := world.surface_height_at(x - METERS_PER_PIXEL, z - METERS_PER_PIXEL) - height
				color = color.lightened(clampf(slope * 0.08, 0.0, 0.25)) if slope > 0.0 else color.darkened(clampf(-slope * 0.08, 0.0, 0.3))
			image.set_pixel(px, pz, color)
	map_texture = ImageTexture.create_from_image(image)
	var fog_side := int(size_m / FOG_METERS_PER_PIXEL)
	_fog = Image.create_empty(fog_side, fog_side, false, Image.FORMAT_L8)
	_fog.fill(Color.BLACK)
	fog_texture = ImageTexture.create_from_image(_fog)


## Descubre la zona alrededor de point. Devuelve true si cambió algo.
func reveal(point: Vector3) -> bool:
	if _fog == null:
		return false
	var half := size_m * 0.5
	var side := _fog.get_width()
	var cx := int((point.x + half) / FOG_METERS_PER_PIXEL)
	var cz := int((point.z + half) / FOG_METERS_PER_PIXEL)
	var r := int(REVEAL_RADIUS / FOG_METERS_PER_PIXEL)
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


## Fracción del mundo descubierta (0–1).
func explored_ratio() -> float:
	var total := _fog.get_width() * _fog.get_height()
	var seen := 0
	for pz in _fog.get_height():
		for px in _fog.get_width():
			if _fog.get_pixel(px, pz).r > 0.5:
				seen += 1
	return float(seen) / total


## Coordenadas UV del mapa (0–1) de un punto del mundo.
func world_to_uv(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z) / size_m + Vector2(0.5, 0.5)
