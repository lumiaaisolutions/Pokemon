class_name WorldBuilder
extends Node3D
## Construye el mundo abierto a partir de WorldConfig: terreno de 3 biomas con el
## shader pixel art, río, lago, pantano y mar; árboles y rocas con colisión;
## decoración e hierba alta con MultiMesh por zonas; muros en el borde.
## También responde consultas de altura, agua, bioma y hábitat.

const TERRAIN_SHADER := preload("res://world/terrain/terrain_world.gdshader")
const WATER_SHADER := preload("res://world/terrain/water_pixel.gdshader")
const TALL_GRASS_SHADER := preload("res://world/terrain/tall_grass.gdshader")
const WORLD_GROUP := &"world"
## Grupo de nodos 3D que apartan la hierba alta al pasar (jugador y Pokémon).
const GRASS_PUSHERS_GROUP := &"grass_pushers"
const MAX_GRASS_ACTORS := 16
## Capas de colisión: 1 = terreno (la cámara choca con él), 2 = obstáculos (árboles,
## rocas y muros: bloquean al jugador pero no acortan el brazo de la cámara).
const LAYER_TERRAIN := 1
const LAYER_OBSTACLES := 2
## Capa visual de los sprites: las sombras de contacto (Decal) solo se proyectan
## sobre la capa 1 (terreno), nunca sobre los sprites.
const VISUAL_LAYER_SPRITES := 2
## Biomas (índice en el mapa de biomas).
enum Biome { MEADOW, FOREST, MOUNTAIN, BEACH }
## Lado de cada zona de MultiMesh de decoración (para descartar lo que no se ve).
const DECOR_CHUNK := 80.0
## Profundidad desde la que el agua bloquea el paso.
const DEEP_WATER := 0.6
## Ancho de la ribera de cada cuerpo de agua (m). La superficie del agua llega hasta
## WATER_EDGE de la ribera, donde el terreno ya está por encima del nivel.
const RIVER_BANK := 7.0
const LAKE_BANK := 10.0
const POND_BANK := 3.0
const WATER_EDGE := 0.92

@export var config: WorldConfig

## Parches de hierba alta: (x, z, radio) y su bioma (Biome) en el mismo índice.
var tall_grass_patches := PackedVector3Array()
var tall_grass_biomes := PackedInt32Array()
## Charcas del pantano: (x, z, radio) y su nivel de agua.
var swamp_ponds := PackedVector3Array()
var swamp_pond_levels := PackedFloat32Array()

var _height_noise := FastNoiseLite.new()
var _ridge_noise := FastNoiseLite.new()
var _warp_noise := FastNoiseLite.new()
## Trazado del río suavizado (Catmull-Rom) a partir de config.river_points.
var _river_pts := PackedVector2Array()
var _river_levels := PackedFloat32Array()
var _lake_level: float = 0.0
var _shadow_texture: GradientTexture2D
var _grass_materials: Array[ShaderMaterial] = []
## Alturas de los vértices de la malla, calculadas una vez (consultas rápidas).
var _heights := PackedFloat32Array()
var _verts_per_side: int = 0


func _ready() -> void:
	add_to_group(WORLD_GROUP)
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height_noise.seed = config.seed
	_height_noise.frequency = 0.012
	_height_noise.fractal_octaves = 3
	_ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridge_noise.seed = config.seed + 11
	_ridge_noise.frequency = 0.008
	_ridge_noise.fractal_octaves = 4
	_warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_warp_noise.seed = config.seed + 23
	_warp_noise.frequency = 0.01
	_compute_water_levels()
	_compute_heights()
	_build_terrain()
	_build_water()
	_build_tall_grass()
	for biome in [Biome.MEADOW, Biome.FOREST, Biome.MOUNTAIN]:
		_build_props(biome)
	_build_forest_edge()
	_build_riparian()
	_build_swamp()
	_build_frontier()
	_build_walls()


func _process(_delta: float) -> void:
	if _grass_materials.is_empty():
		return
	# Los actores más cercanos a la cámara apartan la hierba (el shader admite 16).
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


# --- Consultas -----------------------------------------------------------------

## Pesos de bioma en (x, z): Vector4(pradera, bosque, montaña, costa), suman 1.
func biome_weights(x: float, z: float) -> Vector4:
	var warp := _warp_noise.get_noise_2d(x, z) * 25.0
	var warp2 := _warp_noise.get_noise_2d(z + 300.0, x - 300.0) * 25.0
	var mountain := 1.0 - smoothstep(config.mountain_edge_z - 30.0, config.mountain_edge_z + 20.0, z + warp)
	var forest := (1.0 - smoothstep(config.forest_edge_x - 30.0, config.forest_edge_x + 20.0, x + warp2)) * (1.0 - mountain)
	var beach := smoothstep(config.shore_z - 12.0, config.shore_z + 8.0, z + warp * 0.4) * (1.0 - mountain)
	forest *= 1.0 - beach
	var meadow := maxf(0.0, 1.0 - mountain - forest - beach)
	var total := meadow + forest + mountain + beach
	return Vector4(meadow, forest, mountain, beach) / total


func dominant_biome(x: float, z: float) -> Biome:
	var w := biome_weights(x, z)
	var best := Biome.MEADOW
	var best_w := w.x
	if w.y > best_w:
		best = Biome.FOREST
		best_w = w.y
	if w.z > best_w:
		best = Biome.MOUNTAIN
		best_w = w.z
	if w.w > best_w:
		best = Biome.BEACH
	return best


## Altura del terreno en los vértices de la malla (con río, lago, pantano y mar).
## Cada cuerpo de agua tiene un cauce (fondo bajo el nivel) y una ribera que sube por
## encima del nivel: la superficie del agua termina dentro de la ribera, así su borde
## queda siempre bajo el terreno y nunca se ve flotando.
func height_at(x: float, z: float) -> float:
	var h := _base_height(x, z)
	# Río.
	var river := river_info(x, z)
	h = _carve(h, river.x, config.river_width * 0.5, RIVER_BANK, river.y, 2.0, 0.8)
	# Lago.
	var lake_d := Vector2(x, z).distance_to(config.lake_center)
	h = _carve(h, lake_d, config.lake_radius, LAKE_BANK, _lake_level, 3.0, 0.8)
	# Charcas del pantano.
	for i in swamp_ponds.size():
		var pond := swamp_ponds[i]
		var d := Vector2(x - pond.x, z - pond.y).length()
		if d < pond.z + POND_BANK:
			h = _carve(h, d, pond.z, POND_BANK, swamp_pond_levels[i], 0.9, 0.8)
	return h


## Perfil de un cauce: fondo (level - depth) hasta radius; de radius a radius + bank sube
## hasta al menos level + rise (ribera), y más allá queda el terreno natural.
func _carve(h: float, d: float, radius: float, bank: float, level: float, depth: float, rise: float) -> float:
	if d >= radius + bank:
		return h
	var t := smoothstep(radius, radius + bank, d)
	var shore := maxf(h, level + rise)
	return lerpf(level - depth, shore, t)


## Altura sobre la malla real (interpolada en el triángulo), para apoyar cosas.
func surface_height_at(x: float, z: float) -> float:
	var half := config.size * 0.5
	var cs := config.cell_size
	var gx := clampf((x + half) / cs, 0.0, config.size / cs - 0.0001)
	var gz := clampf((z + half) / cs, 0.0, config.size / cs - 0.0001)
	var ix := floorf(gx)
	var iz := floorf(gz)
	var fx := gx - ix
	var fz := gz - iz
	var n := _verts_per_side
	var i00 := int(iz) * n + int(ix)
	var h00 := _heights[i00]
	var h10 := _heights[i00 + 1]
	var h01 := _heights[i00 + n]
	var h11 := _heights[i00 + n + 1]
	# Misma diagonal que _build_terrain: triángulos (00,10,11) y (00,11,01).
	if fx >= fz:
		return h00 + (h10 - h00) * fx + (h11 - h10) * fz
	return h00 + (h11 - h01) * fx + (h01 - h00) * fz


## Altura más baja del terreno bajo la base de un objeto de radio dado (centro y 8
## puntos alrededor). Apoyar el objeto ahí evita que su lado de abajo flote.
func ground_base_height(x: float, z: float, radius: float) -> float:
	var lowest := surface_height_at(x, z)
	for i in 8:
		var angle := TAU * i / 8.0
		lowest = minf(lowest, surface_height_at(x + cos(angle) * radius, z + sin(angle) * radius))
	return lowest


## Distancia al río y nivel del agua del río en el punto más cercano: Vector2(dist, nivel).
func river_info(x: float, z: float) -> Vector2:
	var point := Vector2(x, z)
	var best := Vector2(INF, 0.0)
	var pts := _river_pts
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var ab := b - a
		var t := clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := point.distance_to(a + ab * t)
		if d < best.x:
			best = Vector2(d, lerpf(_river_levels[i], _river_levels[i + 1], t))
	return best


## Nivel del agua en (x, z): el del cuerpo de agua más alto que lo cubre, o el del mar.
func water_level_at(x: float, z: float) -> float:
	var level := config.sea_level
	var river := river_info(x, z)
	if river.x < config.river_width * 0.5 + RIVER_BANK * WATER_EDGE:
		level = maxf(level, river.y)
	if Vector2(x, z).distance_to(config.lake_center) < config.lake_radius + LAKE_BANK * WATER_EDGE:
		level = maxf(level, _lake_level)
	for i in swamp_ponds.size():
		var pond := swamp_ponds[i]
		if Vector2(x - pond.x, z - pond.y).length() < pond.z + POND_BANK * WATER_EDGE:
			level = maxf(level, swamp_pond_levels[i])
	return level


## Profundidad del agua sobre el terreno (negativa si es tierra firme).
func water_depth_at(x: float, z: float) -> float:
	return water_level_at(x, z) - surface_height_at(x, z)


## Hábitat del lugar: en agua o en su orilla, el tipo de agua; en tierra, el bioma.
func habitat_at(x: float, z: float) -> SpeciesData.Habitat:
	if _near_pond(x, z, 6.0) or _in_swamp(x, z):
		return SpeciesData.Habitat.SWAMP
	var river := river_info(x, z)
	if river.x < config.river_width * 0.5 + 6.0 or Vector2(x, z).distance_to(config.lake_center) < config.lake_radius + 8.0:
		return SpeciesData.Habitat.FRESHWATER
	match dominant_biome(x, z):
		Biome.FOREST:
			return SpeciesData.Habitat.FOREST
		Biome.MOUNTAIN:
			return SpeciesData.Habitat.MOUNTAIN
		Biome.BEACH:
			return SpeciesData.Habitat.SEA
	return SpeciesData.Habitat.MEADOW


## Efecto con el que un Pokémon se esconde en (x, z), según el lugar.
func hide_effect_at(x: float, z: float) -> PixelBurst.Kind:
	if water_depth_at(x, z) > 0.3:
		return PixelBurst.Kind.SPLASH
	if is_in_tall_grass(Vector3(x, 0, z)):
		return PixelBurst.Kind.LEAVES
	match dominant_biome(x, z):
		Biome.FOREST:
			return PixelBurst.Kind.FOREST_LEAVES
		Biome.MOUNTAIN:
			return PixelBurst.Kind.ROCK
		Biome.BEACH:
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
			var dir := (Vector2(point.x, point.z) - center)
			var inside := center + (dir.normalized() * minf(dir.length(), patch.z * 0.6) if dir.length() > 0.01 else Vector2.ZERO)
			best = Vector3(inside.x, surface_height_at(inside.x, inside.y), inside.y)
	return best


## ¿Está el punto dentro de un parche de hierba alta?
func is_in_tall_grass(point: Vector3) -> bool:
	for patch in tall_grass_patches:
		if Vector2(point.x - patch.x, point.z - patch.y).length() <= patch.z:
			return true
	return false


## Punto al azar dentro de un parche de hierba alta, a ras de suelo. Si se pasa
## near, elige entre los parches a menos de max_distance de ese punto.
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


## Punto al azar en agua (para nadadores) o en la orilla (para los demás de tipo
## Agua) cerca de near. Devuelve Vector3.INF si no encontró.
func random_water_point(rng: RandomNumberGenerator, near: Vector3, max_distance: float, in_water: bool) -> Vector3:
	for attempt in 40:
		var angle := rng.randf() * TAU
		var r := rng.randf_range(10.0, max_distance)
		var x := near.x + cos(angle) * r
		var z := near.z + sin(angle) * r
		if absf(x) > config.size * 0.5 - 6.0 or absf(z) > config.size * 0.5 - 6.0:
			continue
		var depth := water_depth_at(x, z)
		if in_water and depth > 0.8:
			return Vector3(x, water_level_at(x, z), z)
		if not in_water and depth < -0.2 and depth > -2.5 and _water_within(x, z, 5.0):
			return Vector3(x, surface_height_at(x, z), z)
	return Vector3.INF


# --- Construcción ----------------------------------------------------------------

func _base_height(x: float, z: float) -> float:
	var w := biome_weights(x, z)
	var n := _height_noise.get_noise_2d(x, z)
	var meadow_h := n * 4.0
	var forest_h := n * 6.0 + 1.0
	var into_mountain := maxf(0.0, config.mountain_edge_z - z)
	var ridge := 1.0 - absf(_ridge_noise.get_noise_2d(x, z))
	var mountain_h := 3.0 + into_mountain * 0.16 + ridge * ridge * 22.0 * clampf(into_mountain / 60.0, 0.0, 1.0)
	var beach_h := lerpf(1.0, config.sea_level - 6.0, smoothstep(config.shore_z, config.shore_z + 45.0, z))
	var h := w.x * meadow_h + w.y * forest_h + w.z * mountain_h + w.w * beach_h
	# Tierra adentro (antes de la playa) nunca baja del nivel del mar: el mar no se
	# cuela en hondonadas lejos de la costa.
	var inland := 1.0 - smoothstep(config.shore_z, config.shore_z + 15.0, z)
	h = lerpf(h, maxf(h, config.sea_level + 0.6), inland)
	# Aplana suavemente el inicio.
	var d := Vector2(x, z).length()
	return h * smoothstep(config.spawn_flat_radius, config.spawn_flat_radius * 2.0, d)


func _smooth_river() -> void:
	var src := config.river_points
	const STEPS := 6
	for i in src.size() - 1:
		var p0 := src[maxi(i - 1, 0)]
		var p1 := src[i]
		var p2 := src[i + 1]
		var p3 := src[mini(i + 2, src.size() - 1)]
		for step in STEPS:
			var t := float(step) / STEPS
			var t2 := t * t
			var t3 := t2 * t
			_river_pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	_river_pts.append(src[src.size() - 1])


func _compute_water_levels() -> void:
	_smooth_river()
	# El nivel del río baja siempre de la montaña al mar.
	_river_levels.resize(_river_pts.size())
	var previous := INF
	# El nivel de cada tramo sale del terreno más bajo a lo ancho del cauce y su
	# ribera: así el río siempre queda encajado y nunca colgado sobre el terreno.
	var reach := config.river_width * 0.5 + RIVER_BANK
	for i in _river_pts.size():
		var p := _river_pts[i]
		var dir := (_river_pts[mini(i + 1, _river_pts.size() - 1)] - _river_pts[maxi(i - 1, 0)]).normalized()
		var normal := Vector2(-dir.y, dir.x)
		var lowest := INF
		var offset := -reach
		while offset <= reach:
			for along in [-3.0, 0.0, 3.0]:
				var q: Vector2 = p + normal * offset + dir * along
				lowest = minf(lowest, _base_height(q.x, q.y))
			offset += 1.5
		var level := minf(lowest - 1.0, previous - 0.02)
		previous = maxf(level, config.sea_level)
		_river_levels[i] = previous
	_lake_level = river_info(config.lake_center.x, config.lake_center.y).y
	# Charcas del pantano.
	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed + 31
	var attempts := 0
	while swamp_ponds.size() < config.swamp_pond_count and attempts < 500:
		attempts += 1
		var angle := rng.randf() * TAU
		var r := sqrt(rng.randf()) * config.swamp_radius * 0.85
		var c := config.swamp_center + Vector2(cos(angle), sin(angle)) * r
		var radius := rng.randf_range(4.0, 9.0)
		# Sin encimarse con otras charcas ni con el río (cada una tiene su propio nivel).
		var clear := river_info(c.x, c.y).x > radius + POND_BANK + config.river_width * 0.5 + RIVER_BANK
		for other in swamp_ponds:
			if c.distance_to(Vector2(other.x, other.y)) < radius + other.z + POND_BANK * 2.0 + 1.0:
				clear = false
		if not clear:
			continue
		swamp_ponds.append(Vector3(c.x, c.y, radius))
		# Nivel bajo el terreno más bajo de la charca y su ribera (encajada, no colgada).
		var lowest := _base_height(c.x, c.y)
		for ring in [radius * 0.5, radius, radius + POND_BANK]:
			for k in 16:
				var a := TAU * k / 16.0
				lowest = minf(lowest, _base_height(c.x + cos(a) * ring, c.y + sin(a) * ring))
		swamp_pond_levels.append(lowest - 0.3)


func _in_swamp(x: float, z: float) -> bool:
	return Vector2(x, z).distance_to(config.swamp_center) < config.swamp_radius


func _near_pond(x: float, z: float, margin: float) -> bool:
	for pond in swamp_ponds:
		if Vector2(x - pond.x, z - pond.y).length() < pond.z + margin:
			return true
	return false


func _water_within(x: float, z: float, radius: float) -> bool:
	for i in 8:
		var angle := TAU * i / 8.0
		if water_depth_at(x + cos(angle) * radius, z + sin(angle) * radius) > 0.3:
			return true
	return false


func _compute_heights() -> void:
	var cells := int(config.size / config.cell_size)
	var half := config.size * 0.5
	_verts_per_side = cells + 1
	_heights.resize(_verts_per_side * _verts_per_side)
	for iz in _verts_per_side:
		for ix in _verts_per_side:
			_heights[iz * _verts_per_side + ix] = height_at(ix * config.cell_size - half, iz * config.cell_size - half)


func _build_terrain() -> void:
	var cells := int(config.size / config.cell_size)
	var half := config.size * 0.5
	var verts := _verts_per_side
	var heights := _heights
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in cells:
		for ix in cells:
			var x0 := ix * config.cell_size - half
			var z0 := iz * config.cell_size - half
			var x1 := x0 + config.cell_size
			var z1 := z0 + config.cell_size
			var p00 := Vector3(x0, heights[iz * verts + ix], z0)
			var p10 := Vector3(x1, heights[iz * verts + ix + 1], z0)
			var p01 := Vector3(x0, heights[(iz + 1) * verts + ix], z1)
			var p11 := Vector3(x1, heights[(iz + 1) * verts + ix + 1], z1)
			# Orden horario visto desde arriba (cara frontal en Godot).
			for v: Vector3 in [p00, p10, p11, p00, p11, p01]:
				st.add_vertex(v)
	st.index()
	st.generate_normals()
	var mesh := st.commit()

	# Mapas de bioma y de pantano/orilla, un texel por celda.
	var biome_image := Image.create_empty(cells, cells, false, Image.FORMAT_RGBA8)
	var extra_image := Image.create_empty(cells, cells, false, Image.FORMAT_RGBA8)
	for iz in cells:
		for ix in cells:
			var x := (ix + 0.5) * config.cell_size - half
			var z := (iz + 0.5) * config.cell_size - half
			var w := biome_weights(x, z)
			biome_image.set_pixel(ix, iz, Color(w.x, w.y, w.z, w.w))
			var swamp := 1.0 if _in_swamp(x, z) and not _near_pond(x, z, -1.0) else 0.0
			var river := river_info(x, z)
			var shore := 1.0 - smoothstep(config.river_width * 0.5 + 1.0, config.river_width * 0.5 + 4.0, river.x)
			var lake_d := Vector2(x, z).distance_to(config.lake_center)
			shore = maxf(shore, 1.0 - smoothstep(config.lake_radius + 2.0, config.lake_radius + 6.0, lake_d))
			extra_image.set_pixel(ix, iz, Color(swamp, shore, 0.0, 1.0))

	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	for biome_key in ["meadow", "forest", "mountain"]:
		var style: BiomeConfig = config.get(biome_key)
		material.set_shader_parameter(biome_key + "_grass", style.grass_texture)
		material.set_shader_parameter(biome_key + "_grass_light", style.grass_light_texture)
		material.set_shader_parameter(biome_key + "_path", style.path_texture)
		material.set_shader_parameter(biome_key + "_slope", style.slope_texture)
		material.set_shader_parameter(biome_key + "_tint", Vector3(style.ground_tint.r, style.ground_tint.g, style.ground_tint.b))
	material.set_shader_parameter("beach_sand", config.beach_texture)
	material.set_shader_parameter("swamp_ground", config.swamp_ground_texture)
	material.set_shader_parameter("biome_map", ImageTexture.create_from_image(biome_image))
	material.set_shader_parameter("extra_map", ImageTexture.create_from_image(extra_image))
	material.set_shader_parameter("world_size", config.size)
	material.set_shader_parameter("patch_noise", _noise_texture(config.seed + 5, 0.02))
	material.set_shader_parameter("path_map", ImageTexture.create_from_image(_path_image()))
	material.set_shader_parameter("rock_height", config.rock_height)
	material.set_shader_parameter("snow_height", config.snow_height)
	material.set_shader_parameter("px_per_meter", 1.0 / config.pixel_size)

	var body := StaticBody3D.new()
	body.name = "Terrain"
	body.collision_layer = LAYER_TERRAIN
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	_terrain_material = material
	body.add_child(instance)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)


func _noise_texture(noise_seed: int, frequency: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = noise_seed
	noise.frequency = frequency
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	return texture


func _water_material(texture: Texture2D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("water_tex", texture)
	material.set_shader_parameter("px_per_meter", 1.0 / config.pixel_size)
	return material


func _build_water() -> void:
	var water := Node3D.new()
	water.name = "Water"
	add_child(water)
	var fresh := _water_material(config.water_texture)

	# Mar: plano al nivel del mar en la franja sur (el terreno más alto lo tapa).
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var sea_mesh := PlaneMesh.new()
	var sea_depth := config.size * 0.5 - (config.shore_z - 30.0)
	sea_mesh.size = Vector2(config.size, sea_depth)
	sea.mesh = sea_mesh
	sea.position = Vector3(0, config.sea_level, config.shore_z - 30.0 + sea_depth * 0.5)
	sea.material_override = fresh
	water.add_child(sea)

	# Río: cinta que sigue el trazado, al nivel de cada tramo.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_width := config.river_width * 0.5 + RIVER_BANK * WATER_EDGE
	var pts := _river_pts
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for i in pts.size():
		var dir := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var normal := Vector2(-dir.y, dir.x)
		# Cada borde va al nivel con el que se excavó ese punto (en curvas cerradas puede
		# ser el de otro tramo), para que nunca quede por encima de su ribera.
		var l := pts[i] + normal * half_width
		var r := pts[i] - normal * half_width
		left.append(Vector3(l.x, minf(_river_levels[i], river_info(l.x, l.y).y), l.y))
		right.append(Vector3(r.x, minf(_river_levels[i], river_info(r.x, r.y).y), r.y))
	var lake_reach := config.lake_radius + LAKE_BANK * WATER_EDGE - config.river_width
	for i in pts.size() - 1:
		# Dentro del lago y del mar ya hay agua: no se encima otra capa transparente.
		var mid := (pts[i] + pts[i + 1]) * 0.5
		if mid.distance_to(config.lake_center) < lake_reach or mid.y > config.shore_z + 25.0:
			continue
		for v: Vector3 in [left[i], left[i + 1], right[i + 1], left[i], right[i + 1], right[i]]:
			st.add_vertex(v)
	st.generate_normals()
	var river := MeshInstance3D.new()
	river.name = "River"
	river.mesh = st.commit()
	river.material_override = fresh
	water.add_child(river)

	# Lago y charcas del pantano.
	water.add_child(_water_disc("Lake", config.lake_center, config.lake_radius + LAKE_BANK * WATER_EDGE, _lake_level + 0.01, fresh))
	var swamp_material := _water_material(config.swamp_water_texture)
	for i in swamp_ponds.size():
		var pond := swamp_ponds[i]
		water.add_child(_water_disc("Pond%d" % i, Vector2(pond.x, pond.y), pond.z + POND_BANK * WATER_EDGE, swamp_pond_levels[i], swamp_material))


func _water_disc(disc_name: String, center: Vector2, radius: float, level: float, material: Material) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	disc.name = disc_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.01
	mesh.radial_segments = 32
	mesh.rings = 1
	disc.mesh = mesh
	disc.position = Vector3(center.x, level, center.y)
	disc.material_override = material
	return disc


## Bordes de cada superficie de agua con su nivel: Vector4(x, y_terreno_ignorado, z, nivel).
## Los usan las pruebas para comprobar que el borde queda bajo el terreno.
func water_edge_samples() -> PackedVector4Array:
	var samples := PackedVector4Array()
	var half_width := config.river_width * 0.5 + RIVER_BANK * WATER_EDGE
	for i in range(1, _river_pts.size() - 1):
		var dir := (_river_pts[i + 1] - _river_pts[i - 1]).normalized()
		var normal := Vector2(-dir.y, dir.x)
		for side in [-1.0, 1.0]:
			var p: Vector2 = _river_pts[i] + normal * half_width * side
			# Dentro del lago o del mar el borde del río queda cubierto por esa agua.
			if p.distance_to(config.lake_center) < config.lake_radius + LAKE_BANK * WATER_EDGE or p.y > config.shore_z:
				continue
			samples.append(Vector4(p.x, 0.0, p.y, minf(_river_levels[i], river_info(p.x, p.y).y)))
	for i in 32:
		var angle := TAU * i / 32.0
		var p := config.lake_center + Vector2(cos(angle), sin(angle)) * (config.lake_radius + LAKE_BANK * WATER_EDGE)
		# Donde el río entra o sale del lago, el borde queda cubierto por el río.
		if river_info(p.x, p.y).x < config.river_width * 0.5 + RIVER_BANK * WATER_EDGE:
			continue
		samples.append(Vector4(p.x, 0.0, p.y, _lake_level))
	for j in swamp_ponds.size():
		var pond := swamp_ponds[j]
		for i in 16:
			var angle := TAU * i / 16.0
			var r := pond.z + POND_BANK * WATER_EDGE
			samples.append(Vector4(pond.x + cos(angle) * r, 0.0, pond.y + sin(angle) * r, swamp_pond_levels[j]))
	return samples


## Polígonos de agua profunda para que la navegación los evite (obstrucciones proyectadas).
func water_obstruction_outlines() -> Array[PackedVector3Array]:
	var outlines: Array[PackedVector3Array] = []
	var pts := _river_pts
	var half_width := config.river_width * 0.5 + 0.5
	for i in pts.size() - 1:
		var dir := (pts[i + 1] - pts[i]).normalized()
		var normal := Vector2(-dir.y, dir.x) * half_width
		var a := pts[i] - dir * 1.0
		var b := pts[i + 1] + dir * 1.0
		outlines.append(PackedVector3Array([
			Vector3(a.x + normal.x, 0, a.y + normal.y), Vector3(b.x + normal.x, 0, b.y + normal.y),
			Vector3(b.x - normal.x, 0, b.y - normal.y), Vector3(a.x - normal.x, 0, a.y - normal.y)]))
	outlines.append(_circle_outline(config.lake_center, config.lake_radius + 1.0))
	for pond in swamp_ponds:
		outlines.append(_circle_outline(Vector2(pond.x, pond.y), pond.z))
	var half := config.size * 0.5
	var sea_z := config.shore_z + 22.0
	outlines.append(PackedVector3Array([Vector3(-half, 0, sea_z), Vector3(half, 0, sea_z), Vector3(half, 0, half), Vector3(-half, 0, half)]))
	return outlines


func _circle_outline(center: Vector2, radius: float) -> PackedVector3Array:
	var outline := PackedVector3Array()
	for i in 16:
		var angle := TAU * i / 16.0
		outline.append(Vector3(center.x + cos(angle) * radius, 0, center.y + sin(angle) * radius))
	return outline


func _build_tall_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = config.props_seed + 2000
	var grass := Node3D.new()
	grass.name = "TallGrass"
	add_child(grass)
	for biome in [Biome.MEADOW, Biome.FOREST, Biome.MOUNTAIN]:
		var style := _style(biome)
		if style.tall_grass_texture == null:
			continue
		var material := ShaderMaterial.new()
		material.shader = TALL_GRASS_SHADER
		material.set_shader_parameter("blade_tex", style.tall_grass_texture)
		material.set_shader_parameter("tint_bottom", Vector3(style.tall_grass_tint_bottom.r, style.tall_grass_tint_bottom.g, style.tall_grass_tint_bottom.b))
		material.set_shader_parameter("tint_top", Vector3(style.tall_grass_tint_top.r, style.tall_grass_tint_top.g, style.tall_grass_tint_top.b))
		_grass_materials.append(material)
		var size := style.tall_grass_texture.get_size() * config.pixel_size
		var quad := QuadMesh.new()
		quad.size = size
		quad.center_offset = Vector3(0, size.y * 0.5, 0)
		quad.material = material
		var placed := 0
		var attempts := 0
		# El primer parche de la Pradera queda cerca del inicio para encontrar Pokémon pronto.
		if biome == Biome.MEADOW:
			placed += _add_grass_patch(grass, quad, Vector3(0, -26, style.tall_grass_radius_max), biome, rng, style)
		while placed < style.tall_grass_patch_count and attempts < 400:
			attempts += 1
			var radius := rng.randf_range(style.tall_grass_radius_min, style.tall_grass_radius_max)
			var xz := _random_xz(rng, config.spawn_flat_radius + radius + 4.0)
			if dominant_biome(xz.x, xz.z) != biome or not _dry_land(xz.x, xz.z, radius):
				continue
			placed += _add_grass_patch(grass, quad, Vector3(xz.x, xz.z, radius), biome, rng, style)


func _add_grass_patch(parent: Node3D, quad: QuadMesh, patch: Vector3, biome: Biome, rng: RandomNumberGenerator, style: BiomeConfig) -> int:
	tall_grass_patches.append(patch)
	tall_grass_biomes.append(biome)
	var positions := PackedVector3Array()
	var count := int(PI * patch.z * patch.z * style.tall_grass_density)
	for i in count:
		var angle := rng.randf() * TAU
		var r := sqrt(rng.randf()) * patch.z
		var x := patch.x + cos(angle) * r
		var z := patch.y + sin(angle) * r
		if water_depth_at(x, z) > -0.1:
			continue
		positions.append(Vector3(x, ground_base_height(x, z, quad.size.x * 0.5) - config.decor_sink, z))
	parent.add_child(_multimesh("Patch%d" % tall_grass_patches.size(), quad, positions, 1.0))
	return 1


## Distancia al camino trazado más cercano.
func distance_to_paths(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var best := INF
	for path in config.paths:
		for i in path.size() - 1:
			var a := path[i]
			var ab := path[i + 1] - a
			var t := clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			best = minf(best, point.distance_to(a + ab * t))
	return best


## Mapa de caminos (1 texel por metro): se estampan discos a lo largo de cada camino.
func _path_image() -> Image:
	var side := int(config.size)
	var image := Image.create_empty(side, side, false, Image.FORMAT_L8)
	var half := config.size * 0.5
	var radius := config.path_width * 0.5
	for path in config.paths:
		for i in path.size() - 1:
			var a := path[i]
			var b := path[i + 1]
			var steps := int(a.distance_to(b) / 0.5) + 1
			for k in steps + 1:
				var p := a.lerp(b, float(k) / steps)
				for dz in range(-int(radius) - 1, int(radius) + 2):
					for dx in range(-int(radius) - 1, int(radius) + 2):
						var px := int(p.x + half) + dx
						var pz := int(p.y + half) + dz
						if px < 0 or pz < 0 or px >= side or pz >= side:
							continue
						var center := Vector2(px - half + 0.5, pz - half + 0.5)
						if center.distance_to(p) <= radius:
							image.set_pixel(px, pz, Color.WHITE)
	return image


## ¿Es tierra firme en todo un círculo (sin agua cerca)?
func _dry_land(x: float, z: float, radius: float) -> bool:
	if water_depth_at(x, z) > -0.4:
		return false
	for i in 8:
		var angle := TAU * i / 8.0
		if water_depth_at(x + cos(angle) * radius, z + sin(angle) * radius) > -0.4:
			return false
	return true


func _style(biome: Biome) -> BiomeConfig:
	match biome:
		Biome.FOREST:
			return config.forest
		Biome.MOUNTAIN:
			return config.mountain
	return config.meadow


## Área aproximada (m²) donde domina el bioma.
func _biome_area(biome: Biome) -> float:
	var step := 8.0
	var half := config.size * 0.5
	var count := 0
	var x := -half + step * 0.5
	while x < half:
		var z := -half + step * 0.5
		while z < half:
			if dominant_biome(x, z) == biome:
				count += 1
			z += step
		x += step
	return count * step * step


func _build_props(biome: Biome) -> void:
	var style := _style(biome)
	var rng := RandomNumberGenerator.new()
	rng.seed = config.props_seed + int(biome) * 7919
	var area := _biome_area(biome)
	var group := Node3D.new()
	group.name = "Props_%s" % style.biome_name
	add_child(group)

	var trees := int(area / 1000.0 * style.trees_per_1000m2)
	var rocks := int(area / 1000.0 * style.rocks_per_1000m2)
	for i in trees:
		var xz := _random_point_in(biome, rng, 1.5)
		if xz == Vector3.INF or style.tree_textures.is_empty():
			continue
		# Pisos de altura: arriba de la línea de roca ya no crecen árboles.
		if surface_height_at(xz.x, xz.z) > config.rock_height:
			continue
		var texture: Texture2D = style.tree_textures[rng.randi() % style.tree_textures.size()]
		var scale_factor := 2.0 if rng.randf() < style.big_tree_ratio else 1.0
		group.add_child(_obstacle("Tree%d" % i, texture, scale_factor, style.tree_collision_radius, xz, style.prop_tint))
	for i in rocks:
		var xz := _random_point_in(biome, rng, 1.0)
		if xz == Vector3.INF or style.rock_textures.is_empty():
			continue
		var texture: Texture2D = style.rock_textures[rng.randi() % style.rock_textures.size()]
		var scale_factor := 2.0 if rng.randf() < 0.2 else 1.0
		group.add_child(_obstacle("Rock%d" % i, texture, scale_factor, style.rock_collision_radius, xz, style.prop_tint))

	# Decoración por zonas de DECOR_CHUNK m para que el motor descarte lo que no se ve.
	var per_texture := int(area / 1000.0 * style.decor_per_1000m2)
	for texture: Texture2D in style.decor_textures:
		var size := texture.get_size() * config.pixel_size
		var quad := QuadMesh.new()
		quad.size = size
		quad.center_offset = Vector3(0, size.y * 0.5, 0)
		quad.material = _sprite_material(texture, style.prop_tint)
		var chunks := {}
		for i in per_texture:
			var xz := _random_point_in(biome, rng, 0.3)
			if xz == Vector3.INF:
				continue
			var key := Vector2i(floori(xz.x / DECOR_CHUNK), floori(xz.z / DECOR_CHUNK))
			if not chunks.has(key):
				chunks[key] = PackedVector3Array()
			var base := ground_base_height(xz.x, xz.z, size.x * 0.5) - config.decor_sink
			chunks[key].append(Vector3(xz.x, base, xz.z))
		for key: Vector2i in chunks:
			var instance := _multimesh("%s_%d_%d" % [texture.resource_path.get_file().get_basename(), key.x, key.y], quad, chunks[key], 0.0)
			instance.visibility_range_end = config.prop_view_distance
			group.add_child(instance)


## Borde del bosque: árboles sueltos y arbustos en la pradera cercana al bosque, para
## que el cambio de bioma no sea brusco.
func _build_forest_edge() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = config.props_seed + 4001
	var group := Node3D.new()
	group.name = "Props_BordeBosque"
	add_child(group)
	var forest := config.forest
	var attempts := int(config.size * config.size / 1000.0 * config.forest_edge_trees_per_1000m2)
	var placed := 0
	for i in attempts:
		var xz := _random_xz(rng, config.spawn_flat_radius + 6.0)
		var w := biome_weights(xz.x, xz.z)
		# Franja de transición: pradera con algo de bosque cerca.
		if w.y < 0.08 or w.y > 0.5 or not _dry_land(xz.x, xz.z, 2.0):
			continue
		if distance_to_paths(xz.x, xz.z) < config.path_width + 1.5 or rng.randf() > (w.y / 0.5):
			continue
		var texture: Texture2D = forest.tree_textures[rng.randi() % forest.tree_textures.size()]
		group.add_child(_obstacle("EdgeTree%d" % placed, texture, 1.0, forest.tree_collision_radius, xz, forest.prop_tint.lerp(Color.WHITE, 0.5)))
		placed += 1


## Ribera viva: árboles, juncos y flores a lo largo del río y alrededor del lago.
func _build_riparian() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = config.props_seed + 5003
	var group := Node3D.new()
	group.name = "Props_Ribera"
	add_child(group)
	var meadow := config.meadow
	var shore_points: Array[Vector2] = []
	var reach := config.river_width * 0.5 + RIVER_BANK + 1.0
	for i in _river_pts.size() - 1:
		var a := _river_pts[i]
		var b := _river_pts[i + 1]
		var normal := Vector2(-(b - a).normalized().y, (b - a).normalized().x)
		var length := a.distance_to(b)
		var count := int(length / 10.0 * (config.riparian_trees_per_10m + config.riparian_decor_per_10m) * 2.0)
		for k in count:
			var t := rng.randf()
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			shore_points.append(a.lerp(b, t) + normal * side * rng.randf_range(reach, reach + 6.0))
	var lake_reach := config.lake_radius + LAKE_BANK + 1.0
	var lake_count := int(TAU * lake_reach / 10.0 * (config.riparian_trees_per_10m + config.riparian_decor_per_10m))
	for k in lake_count:
		var angle := rng.randf() * TAU
		shore_points.append(config.lake_center + Vector2(cos(angle), sin(angle)) * rng.randf_range(lake_reach, lake_reach + 6.0))
	var tree_share := config.riparian_trees_per_10m / (config.riparian_trees_per_10m + config.riparian_decor_per_10m)
	var decor := {}
	for point in shore_points:
		if not _dry_land(point.x, point.y, 1.0) or distance_to_paths(point.x, point.y) < config.path_width + 1.0:
			continue
		if surface_height_at(point.x, point.y) > config.rock_height:
			continue
		var xz := Vector3(point.x, 0.0, point.y)
		if rng.randf() < tree_share:
			var texture: Texture2D = meadow.tree_textures[rng.randi() % meadow.tree_textures.size()]
			group.add_child(_obstacle("ShoreTree%d" % group.get_child_count(), texture, 1.0, meadow.tree_collision_radius, xz, Color.WHITE))
		else:
			# Juncos (mechones altos), lavanda y flores.
			var texture: Texture2D = meadow.decor_textures[[3, 6, 1, 3][rng.randi() % 4]]
			if not decor.has(texture):
				decor[texture] = PackedVector3Array()
			var size := texture.get_size() * config.pixel_size
			(decor[texture] as PackedVector3Array).append(Vector3(point.x, ground_base_height(point.x, point.y, size.x * 0.5) - config.decor_sink, point.y))
	for texture: Texture2D in decor:
		var size := texture.get_size() * config.pixel_size
		var quad := QuadMesh.new()
		quad.size = size
		quad.center_offset = Vector3(0, size.y * 0.5, 0)
		quad.material = _sprite_material(texture, Color.WHITE)
		var instance := _multimesh("Ribera_%s" % texture.resource_path.get_file().get_basename(), quad, decor[texture], 0.0)
		instance.visibility_range_end = config.prop_view_distance
		group.add_child(instance)


## Pantano: árboles muertos y bruma baja entre las charcas.
func _build_swamp() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = config.props_seed + 6007
	var group := Node3D.new()
	group.name = "Props_Pantano"
	add_child(group)
	var area := PI * config.swamp_radius * config.swamp_radius
	if config.dead_tree_texture != null:
		for i in int(area / 1000.0 * 5.0):
			var angle := rng.randf() * TAU
			var c := config.swamp_center + Vector2(cos(angle), sin(angle)) * sqrt(rng.randf()) * config.swamp_radius
			if not _dry_land(c.x, c.y, 1.0):
				continue
			var scale_factor := 2.0 if rng.randf() < 0.3 else 1.0
			group.add_child(_obstacle("DeadTree%d" % i, config.dead_tree_texture, scale_factor, 0.4, Vector3(c.x, 0, c.y), Color.WHITE))
	# Bruma: manchas blancas suaves, horizontales y bajas.
	var mist_texture := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.9, 0.95, 0.92, 0.35), Color(0.9, 0.95, 0.92, 0.0)])
	mist_texture.gradient = gradient
	mist_texture.fill = GradientTexture2D.FILL_RADIAL
	mist_texture.fill_from = Vector2(0.5, 0.5)
	mist_texture.fill_to = Vector2(1.0, 0.5)
	var material := StandardMaterial3D.new()
	material.albedo_texture = mist_texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(9.0, 9.0)
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = material
	var mist := PackedVector3Array()
	for i in int(area / 1000.0 * config.swamp_mist_per_1000m2):
		var angle := rng.randf() * TAU
		var c := config.swamp_center + Vector2(cos(angle), sin(angle)) * sqrt(rng.randf()) * config.swamp_radius
		mist.append(Vector3(c.x, maxf(surface_height_at(c.x, c.y), water_level_at(c.x, c.y)) + rng.randf_range(0.4, 1.2), c.y))
	var instance := _multimesh("Bruma", quad, mist, 0.0)
	instance.layers = VISUAL_LAYER_SPRITES
	group.add_child(instance)


## Punto al azar donde domina el bioma, en tierra firme y fuera del inicio y del río.
func _random_point_in(biome: Biome, rng: RandomNumberGenerator, radius: float) -> Vector3:
	for attempt in 40:
		var xz := _random_xz(rng, config.spawn_flat_radius + 4.0)
		if dominant_biome(xz.x, xz.z) != biome:
			continue
		if not _dry_land(xz.x, xz.z, radius + 0.5):
			continue
		# Los caminos quedan despejados.
		if distance_to_paths(xz.x, xz.z) < config.path_width + radius:
			continue
		return xz
	return Vector3.INF


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
	# El shader de la hierba desplaza vértices: margen para que no se recorte.
	instance.extra_cull_margin = cull_margin
	return instance


## Sprite billboard apoyado en el suelo, con sombra de contacto y un cilindro de
## colisión en la capa de obstáculos. xz es la posición horizontal (y se ignora).
func _obstacle(obstacle_name: String, texture: Texture2D, scale_factor: float, radius: float, xz: Vector3, tint: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = obstacle_name
	body.collision_layer = LAYER_OBSTACLES
	var width := texture.get_size().x * config.pixel_size * scale_factor
	var height := texture.get_size().y * config.pixel_size * scale_factor
	body.position = Vector3(xz.x, ground_base_height(xz.x, xz.z, width * 0.5) - config.obstacle_sink, xz.z)
	body.add_child(_contact_shadow(width * 1.1))
	var sprite := _billboard(texture, config.pixel_size * scale_factor)
	sprite.name = "Sprite"
	sprite.modulate = tint
	SpriteMaterials.apply(sprite)
	sprite.material_override = SpriteMaterials.for_texture(texture, tint)
	sprite.modulate = Color.WHITE
	sprite.visibility_range_end = config.prop_view_distance * (1.5 if scale_factor > 1.0 else 1.0)
	body.add_child(sprite)
	var shape := CylinderShape3D.new()
	shape.radius = radius * scale_factor
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = height * 0.5
	body.add_child(collision)
	return body


## Sombra suave proyectada sobre el terreno (Decal), se adapta a la pendiente.
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
	# Solo sobre el terreno (capa visual 1), nunca sobre los sprites.
	decal.cull_mask = 1
	return decal


func _billboard(texture: Texture2D, pixel_size: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = pixel_size
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# Sin sombreado: los sprites conservan los colores exactos de B2W2, como el jugador.
	sprite.shaded = false
	sprite.double_sided = true
	sprite.layers = VISUAL_LAYER_SPRITES
	return sprite


func _sprite_material(texture: Texture2D, tint: Color) -> ShaderMaterial:
	# De pie e inclinado al mirar desde arriba, igual que los árboles y los actores.
	return SpriteMaterials.for_texture(texture, tint)


## Punto horizontal al azar dentro del mundo, fuera del radio libre del inicio (y = 0).
func _random_xz(rng: RandomNumberGenerator, clear_radius: float) -> Vector3:
	var half := config.size * 0.5 - config.cell_size * 3.0
	for attempt in 30:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if Vector2(x, z).length() >= clear_radius:
			return Vector3(x, 0.0, z)
	return Vector3(half, 0.0, half)


## Ancho de la franja exterior (cordillera y mar abierto) y tamaño de su celda (m).
const FRONTIER_WIDTH := 420.0
const FRONTIER_CELL := 8.0
var _terrain_material: ShaderMaterial


## Límite del mundo sin bordes visibles: fuera del área jugable, una cordillera
## infranqueable al norte, este y oeste (sube empinada desde el borde; roca y nieve por
## altura con el mismo shader del terreno) y mar abierto hasta el horizonte al sur.
## Solo es visual: los muros invisibles del borde siguen deteniendo al jugador.
func _build_frontier() -> void:
	var half := config.size * 0.5
	var outer := half + FRONTIER_WIDTH
	var cells := int(ceil(outer * 2.0 / FRONTIER_CELL))
	var verts := cells + 1
	var heights := PackedFloat32Array()
	heights.resize(verts * verts)
	for iz in verts:
		for ix in verts:
			heights[iz * verts + ix] = frontier_height_at(ix * FRONTIER_CELL - outer, iz * FRONTIER_CELL - outer)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := half - FRONTIER_CELL
	for iz in cells:
		for ix in cells:
			var x0 := ix * FRONTIER_CELL - outer
			var z0 := iz * FRONTIER_CELL - outer
			var x1 := x0 + FRONTIER_CELL
			var z1 := z0 + FRONTIER_CELL
			# Sin celdas dentro del área jugable (las cubre el terreno).
			if x0 >= -inner and x1 <= inner and z0 >= -inner and z1 <= inner:
				continue
			var p00 := Vector3(x0, heights[iz * verts + ix], z0)
			var p10 := Vector3(x1, heights[iz * verts + ix + 1], z0)
			var p01 := Vector3(x0, heights[(iz + 1) * verts + ix], z1)
			var p11 := Vector3(x1, heights[(iz + 1) * verts + ix + 1], z1)
			for v: Vector3 in [p00, p10, p11, p00, p11, p01]:
				st.add_vertex(v)
	st.index()
	st.generate_normals()
	var frontier := MeshInstance3D.new()
	frontier.name = "Frontier"
	frontier.mesh = st.commit()
	frontier.material_override = _terrain_material
	frontier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(frontier)
	# Mar abierto: un plano grande al sur, más allá de la costa.
	var sea := MeshInstance3D.new()
	sea.name = "OpenSea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(outer * 2.0, FRONTIER_WIDTH + 40.0)
	sea.mesh = plane
	sea.position = Vector3(0.0, config.sea_level, half + FRONTIER_WIDTH * 0.5 - 20.0)
	sea.material_override = _water_material(config.water_texture)
	add_child(sea)


## Altura de la franja exterior: bajo el terreno dentro del área (para no dejar
## rendijas), cordillera afuera y fondo marino al sur de la costa.
func frontier_height_at(x: float, z: float) -> float:
	var half := config.size * 0.5
	var inside_x := clampf(x, -half, half)
	var inside_z := clampf(z, -half, half)
	var d := Vector2(x - inside_x, z - inside_z).length()
	var edge := height_at(inside_x, inside_z)
	if d <= 0.0:
		return edge - 1.5
	var ridge := 1.0 - absf(_ridge_noise.get_noise_2d(x * 0.6, z * 0.6))
	var peaks := 55.0 + ridge * ridge * 70.0 + _height_noise.get_noise_2d(x * 0.5, z * 0.5) * 12.0
	var mountain := edge + peaks * (1.0 - exp(-d / 28.0))
	var seabed := config.sea_level - 6.0 - d * 0.05
	# Al sur de la costa todo es mar; la cordillera baja hasta la playa.
	var sea_factor := smoothstep(config.shore_z, config.shore_z + 60.0, z)
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
		box.size = Vector3(config.size if along_x else 1.0, config.wall_height, 1.0 if along_x else config.size)
		var body := StaticBody3D.new()
		body.name = "Wall%d" % i
		body.collision_layer = LAYER_OBSTACLES
		body.position = side + Vector3.UP * (config.wall_height * 0.5 - 10.0)
		var collision := CollisionShape3D.new()
		collision.shape = box
		body.add_child(collision)
		walls.add_child(body)
