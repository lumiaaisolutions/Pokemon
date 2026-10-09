class_name BiomeBuilder
extends Node3D
## Construye un bioma HD-2D a partir de su BiomeConfig: terreno con el shader pixel
## art (texturas de B2W2) y colisión exacta, árboles como sprites billboard con
## colisión, decoración con MultiMesh y muros invisibles en el borde.

const TERRAIN_SHADER := preload("res://world/terrain/terrain_pixel.gdshader")
## Capas de colisión: 1 = terreno (la cámara choca con él), 2 = obstáculos (árboles y
## muros: bloquean al jugador pero no acortan el brazo de la cámara).
const LAYER_TERRAIN := 1
const LAYER_OBSTACLES := 2

@export var config: BiomeConfig

var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = config.noise_seed
	_noise.frequency = config.noise_frequency
	_noise.fractal_octaves = 3
	_build_terrain()
	_build_trees()
	_build_rocks()
	_build_decor()
	_build_walls()


## Altura del terreno en (x, z), igual a la que usa la malla en sus vértices.
func height_at(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * config.height_amplitude
	# Aplana suavemente el centro para el punto de inicio.
	var d := Vector2(x, z).length()
	var flat := smoothstep(config.flat_radius, config.flat_radius * 2.0, d)
	return h * flat


## Altura sobre la malla real (interpolada en el triángulo), para colocar cosas a ras de suelo.
func surface_height_at(x: float, z: float) -> float:
	var half := config.size * 0.5
	var cs := config.cell_size
	var gx := clampf((x + half) / cs, 0.0, config.size / cs - 0.0001)
	var gz := clampf((z + half) / cs, 0.0, config.size / cs - 0.0001)
	var ix := floorf(gx)
	var iz := floorf(gz)
	var fx := gx - ix
	var fz := gz - iz
	var x0 := ix * cs - half
	var z0 := iz * cs - half
	var h00 := height_at(x0, z0)
	var h10 := height_at(x0 + cs, z0)
	var h01 := height_at(x0, z0 + cs)
	var h11 := height_at(x0 + cs, z0 + cs)
	# Misma diagonal que _build_terrain: triángulos (00,10,11) y (00,11,01).
	if fx >= fz:
		return h00 + (h10 - h00) * fx + (h11 - h10) * fz
	return h00 + (h11 - h01) * fx + (h01 - h00) * fz


func _build_terrain() -> void:
	var cells := int(config.size / config.cell_size)
	var half := config.size * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in cells:
		for ix in cells:
			var x0 := ix * config.cell_size - half
			var z0 := iz * config.cell_size - half
			var x1 := x0 + config.cell_size
			var z1 := z0 + config.cell_size
			var p00 := Vector3(x0, height_at(x0, z0), z0)
			var p10 := Vector3(x1, height_at(x1, z0), z0)
			var p01 := Vector3(x0, height_at(x0, z1), z1)
			var p11 := Vector3(x1, height_at(x1, z1), z1)
			# Orden horario visto desde arriba (cara frontal en Godot).
			for v: Vector3 in [p00, p10, p11, p00, p11, p01]:
				st.add_vertex(v)
	st.index()
	st.generate_normals()
	var mesh := st.commit()

	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	material.set_shader_parameter("grass_tex", config.grass_texture)
	material.set_shader_parameter("grass_light_tex", config.grass_light_texture)
	material.set_shader_parameter("path_tex", config.path_texture)
	material.set_shader_parameter("dirt_tex", config.dirt_texture)
	material.set_shader_parameter("patch_noise", _noise_texture(config.patch_seed, 0.02))
	material.set_shader_parameter("path_noise", _noise_texture(config.path_seed, 0.012))
	material.set_shader_parameter("px_per_meter", 1.0 / config.pixel_size)

	var body := StaticBody3D.new()
	body.name = "Terrain"
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
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


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = config.props_seed
	var trees := Node3D.new()
	trees.name = "Trees"
	add_child(trees)
	for i in config.tree_count:
		var texture: Texture2D = config.tree_textures[rng.randi() % config.tree_textures.size()]
		var scale_factor := 2.0 if rng.randf() < config.big_tree_ratio else 1.0
		var tree := _obstacle("Tree%d" % i, texture, scale_factor, config.tree_collision_radius, _random_ground_point(rng))
		trees.add_child(tree)


func _build_rocks() -> void:
	if config.rock_textures.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = config.props_seed + 500
	var rocks := Node3D.new()
	rocks.name = "Rocks"
	add_child(rocks)
	for i in config.rock_count:
		var texture: Texture2D = config.rock_textures[rng.randi() % config.rock_textures.size()]
		var scale_factor := 2.0 if rng.randf() < 0.2 else 1.0
		var rock := _obstacle("Rock%d" % i, texture, scale_factor, config.rock_collision_radius, _random_ground_point(rng))
		rocks.add_child(rock)


## Sprite billboard con los pies en el suelo y un cilindro de colisión en la capa de obstáculos.
func _obstacle(obstacle_name: String, texture: Texture2D, scale_factor: float, radius: float, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = obstacle_name
	body.position = pos
	body.collision_layer = LAYER_OBSTACLES
	var height := texture.get_size().y * config.pixel_size * scale_factor
	var sprite := _billboard(texture, config.pixel_size * scale_factor)
	sprite.position.y = height * 0.5
	body.add_child(sprite)
	var shape := CylinderShape3D.new()
	shape.radius = radius * scale_factor
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = height * 0.5
	body.add_child(collision)
	return body


func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = config.props_seed + 1000
	var decor := Node3D.new()
	decor.name = "Decor"
	add_child(decor)
	for texture: Texture2D in config.decor_textures:
		var size := texture.get_size() * config.pixel_size
		var quad := QuadMesh.new()
		quad.size = size
		quad.center_offset = Vector3(0, size.y * 0.5, 0)
		quad.material = _sprite_material(texture)

		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = quad
		multimesh.instance_count = config.decor_count_each
		for i in config.decor_count_each:
			var pos := _random_ground_point(rng, 4.0)
			multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
		var instance := MultiMeshInstance3D.new()
		instance.name = texture.resource_path.get_file().get_basename()
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		decor.add_child(instance)


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
	return sprite


func _sprite_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _random_ground_point(rng: RandomNumberGenerator, clear_radius: float = -1.0) -> Vector3:
	var radius := config.props_clear_radius if clear_radius < 0.0 else clear_radius
	var margin := config.cell_size * 2.0
	var half := config.size * 0.5 - margin
	for attempt in 30:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if Vector2(x, z).length() >= radius:
			return Vector3(x, surface_height_at(x, z), z)
	return Vector3(half, surface_height_at(half, half), half)


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
		body.position = side + Vector3.UP * (config.wall_height * 0.5 - config.height_amplitude)
		var collision := CollisionShape3D.new()
		collision.shape = box
		body.add_child(collision)
		walls.add_child(body)
