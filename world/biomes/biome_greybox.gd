class_name BiomeGreybox
extends Node3D
## Construye un bioma greybox a partir de su BiomeConfig: terreno low-poly
## con sombreado plano y colisión exacta, rocas, árboles y muros invisibles.

@export var config: BiomeConfig

var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = config.noise_seed
	_noise.frequency = config.noise_frequency
	_noise.fractal_octaves = 3
	_build_terrain()
	_build_props()
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
	st.set_smooth_group(-1) # Sombreado plano: cada cara con su normal (look low-poly).
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
			_add_triangle(st, p00, p10, p11)
			_add_triangle(st, p00, p11, p01)
	st.generate_normals()
	var mesh := st.commit()

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 1.0

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


func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Color por cara según su altura media, con un poco de ruido para romper la uniformidad.
	var mid := (a + b + c) / 3.0
	var t := clampf(inverse_lerp(-config.height_amplitude, config.height_amplitude, mid.y), 0.0, 1.0)
	var jitter := _noise.get_noise_2d(mid.x * 7.0, mid.z * 7.0) * 0.08
	var color := config.ground_color_low.lerp(config.ground_color_high, clampf(t + jitter, 0.0, 1.0))
	for v: Vector3 in [a, b, c]:
		st.set_color(color)
		st.add_vertex(v)


func _build_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = config.props_seed
	var props := Node3D.new()
	props.name = "Props"
	add_child(props)

	var rock_material := _flat_material(config.rock_color)
	var trunk_material := _flat_material(config.trunk_color)
	var leaves_material := _flat_material(config.leaves_color)

	for i in config.rock_count:
		var pos := _random_ground_point(rng)
		var radius := rng.randf_range(0.5, 1.6)
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * rng.randf_range(1.0, 1.6)
		mesh.radial_segments = 6
		mesh.rings = 3
		mesh.material = rock_material
		var shape := SphereShape3D.new()
		shape.radius = radius * 0.9
		var rock := _static_prop("Rock%d" % i, mesh, shape, Vector3.ZERO)
		rock.position = pos
		rock.rotation.y = rng.randf() * TAU
		props.add_child(rock)

	for i in config.tree_count:
		var pos := _random_ground_point(rng)
		var tree_height := rng.randf_range(3.5, 6.0)
		var tree := StaticBody3D.new()
		tree.name = "Tree%d" % i
		tree.position = pos

		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.2
		trunk_mesh.bottom_radius = 0.3
		trunk_mesh.height = tree_height * 0.45
		trunk_mesh.radial_segments = 6
		trunk_mesh.material = trunk_material
		var trunk := MeshInstance3D.new()
		trunk.mesh = trunk_mesh
		trunk.position.y = trunk_mesh.height * 0.5
		tree.add_child(trunk)

		var crown_mesh := CylinderMesh.new()
		crown_mesh.top_radius = 0.0
		crown_mesh.bottom_radius = tree_height * 0.32
		crown_mesh.height = tree_height * 0.7
		crown_mesh.radial_segments = 7
		crown_mesh.material = leaves_material
		var crown := MeshInstance3D.new()
		crown.mesh = crown_mesh
		crown.position.y = trunk_mesh.height + crown_mesh.height * 0.4
		tree.add_child(crown)

		var trunk_shape := CylinderShape3D.new()
		trunk_shape.radius = 0.35
		trunk_shape.height = tree_height
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position.y = tree_height * 0.5
		tree.add_child(collision)
		props.add_child(tree)


func _random_ground_point(rng: RandomNumberGenerator) -> Vector3:
	var margin := config.cell_size * 2.0
	var half := config.size * 0.5 - margin
	for attempt in 30:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if Vector2(x, z).length() >= config.props_clear_radius:
			return Vector3(x, surface_height_at(x, z), z)
	return Vector3(half, surface_height_at(half, half), half)


func _static_prop(prop_name: String, mesh: Mesh, shape: Shape3D, offset: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = prop_name
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = offset
	body.add_child(instance)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = offset
	body.add_child(collision)
	return body


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material


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
		body.position = side + Vector3.UP * (config.wall_height * 0.5 - config.height_amplitude)
		var collision := CollisionShape3D.new()
		collision.shape = box
		body.add_child(collision)
		walls.add_child(body)
