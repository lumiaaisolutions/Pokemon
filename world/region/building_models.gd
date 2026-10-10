class_name BuildingModels
extends RefCounted
## Modelos 3D de edificios de Pokémon Negro 2 / Blanco 2 (The Models Resource,
## `art/models/b2w2/`). Se escalan a metros del juego (16 unidades = una casilla de
## B2W2 ≈ 1.28 m), con texturas en píxel nítido y transparencias recortadas. La puerta
## mira a +Z (hacia la cámara en B2W2), igual que los edificios del juego.

const ROOT := "res://art/models/b2w2/"
## Metros por unidad del modelo.
const SCALE := 0.08
const MODELS := {
	"center": ["pokecenter"],
	"mart": ["shop1", "shop2", "shop3"],
	"house": ["house1", "house2", "house3", "house4", "floccesy_house", "house5", "accumula_house", "aspertia_house", "undella_house1",
			"lacunosa_house", "icirrus_house", "humilau_house", "mistralton_house"],
	"cabin": ["house6", "house5", "icirrus_house"],
	"lab": ["lab", "lab2", "shop"],
	"contest": ["aspertia_building2", "shop"],
	"gym": ["gym_aspertia", "gym_mistralton", "gym_humilau", "gym_opelucid"],
	"tower_small": ["aspertia_building1", "driftveil_building1"],
	# Decoración.
	"lamp": ["lamp1", "lamp3"],
	# Lugares especiales.
	"tower": ["celestial_tower"],
	"mansion": ["haunted_house"],
	"lighthouse": ["lighthouse"],
	"ruins": ["ruins1", "ruins3"],
	"sanctuary": ["shrine"],
	"berry_farm": ["greenhouse"],
	"fence": ["fence"],
	"sign": ["sign1", "sign2", "sign3", "sign4"],
	"bench": ["bench"],
	"stump": ["stump"],
}

static var _scenes := {}
static var _materials := {}


## ¿Hay modelo para este tipo de edificio?
static func has_kind(kind: String) -> bool:
	return MODELS.has(kind) and not _available(kind).is_empty()


static func _available(kind: String) -> Array:
	return (MODELS.get(kind, []) as Array).filter(func(name: String) -> bool: return DirAccess.dir_exists_absolute(ROOT + name))


## Instancia un modelo del tipo (variante fija por índice). Devuelve {"node", "size": Vector3 (m), "front": float (z de la fachada)}.
static func instance(kind: String, variant: int) -> Dictionary:
	var names := _available(kind)
	if names.is_empty():
		return {}
	var name: String = names[absi(variant) % names.size()]
	var scene := _scene(name)
	if scene == null:
		return {}
	var node := scene.instantiate() as Node3D
	node.scale = Vector3.ONE * SCALE
	var box := AABB()
	var first := true
	for mesh_node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		_fix_materials(mesh)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh.visibility_range_end = 520.0
		var local := _local_transform(mesh, node) * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	# Centra la planta en el origen y apoya la base en y = 0.
	var center := box.get_center()
	var holder := Node3D.new()
	holder.name = "Model_" + name
	holder.add_child(node)
	node.position = Vector3(-center.x, -box.position.y, -center.z) * SCALE
	var size := box.size * SCALE
	# Núcleo sólido: los modelos de la DS no tienen las caras que nunca se veían (la parte
	# de atrás); por dentro va una caja del color de sus paredes para tapar los huecos.
	if not kind in DECOR_KINDS:
		var core := MeshInstance3D.new()
		core.name = "Core"
		var cube := BoxMesh.new()
		cube.size = Vector3(size.x * 0.86, size.y * 0.72, size.z * 0.86)
		core.mesh = cube
		core.position = Vector3(0, cube.size.y * 0.5, 0)
		var material := StandardMaterial3D.new()
		material.albedo_color = _wall_color(name)
		material.roughness = 1.0
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		core.material_override = material
		core.visibility_range_end = 520.0
		holder.add_child(core)
	return {"node": holder, "size": size, "front": size.z * 0.5}


## Tipos que son decoración (sin núcleo).
const DECOR_KINDS := ["lamp", "fence", "sign", "bench", "stump"]
static var _wall_colors := {}


## Color promedio de la textura más grande del modelo (sus paredes), algo oscurecido.
static func _wall_color(name: String) -> Color:
	if _wall_colors.has(name):
		return _wall_colors[name]
	var best: Image = null
	for file in DirAccess.get_files_at(ROOT + name):
		if not file.ends_with(".png") or file.contains("kage") or file.contains("mado") or file.contains("win"):
			continue
		var texture := load(ROOT + name + "/" + file) as Texture2D
		var image := texture.get_image() if texture != null else null
		if image != null and (best == null or image.get_width() * image.get_height() > best.get_width() * best.get_height()):
			best = image
	var color := Color(0.6, 0.58, 0.55)
	if best != null:
		var small := best.duplicate() as Image
		if small.is_compressed():
			small.decompress()
		small.resize(1, 1, Image.INTERPOLATE_BILINEAR)
		color = small.get_pixel(0, 0)
		color.a = 1.0
	color = color.darkened(0.15)
	_wall_colors[name] = color
	return color


static func _scene(name: String) -> PackedScene:
	if _scenes.has(name):
		return _scenes[name]
	var scene: PackedScene = null
	for file in DirAccess.get_files_at(ROOT + name):
		if file.ends_with(".dae"):
			scene = load(ROOT + name + "/" + file) as PackedScene
			break
	_scenes[name] = scene
	return scene


static func _local_transform(node: Node3D, root: Node3D) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			transform = (current as Node3D).transform * transform
		current = current.get_parent()
	return transform


## Materiales de ventanas (compartidos): DayNight les sube la emisión de noche.
static var window_materials: Array[BaseMaterial3D] = []


## Píxel nítido y recorte de transparencias (ventanas y sombras del modelo).
static func _fix_materials(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
	# Sombras pintadas ("kage") y alfombras van en el mismo plano que el piso y
	# parpadeaban (z-fighting): se suben un poco y se dibujan después.
	for surface in mesh.mesh.get_surface_count():
		var source := mesh.get_active_material(surface) as BaseMaterial3D
		var texture := source.albedo_texture if source != null else null
		var shadow := source != null and (source.resource_name.contains("kage") or (texture != null and texture.resource_path.get_file().contains("kage")))
		if shadow and not mesh.has_meta("lifted"):
			mesh.set_meta("lifted", true)
			mesh.position.y += 0.4
	for surface in mesh.mesh.get_surface_count():
		var material := mesh.get_active_material(surface)
		if material == null:
			continue
		var key := material.get_instance_id()
		if not _materials.has(key):
			var fixed := material.duplicate() as Material
			if fixed is BaseMaterial3D:
				var base := fixed as BaseMaterial3D
				base.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				base.roughness = 1.0
				base.metallic = 0.0
				base.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				var texture := base.albedo_texture
				var path := texture.resource_path if texture != null else ""
				# Ventanas ("mado", "win"): brillan cálidas de noche (DayNight las enciende).
				if path.get_file().contains("mado") or path.get_file().contains("win"):
					base.emission_enabled = true
					base.emission = Color(1.0, 0.72, 0.38)
					base.emission_texture = texture
					var hour := GameState.clock_hour()
					base.emission_energy_multiplier = 0.35 if hour < 6.5 or hour >= 18.5 else 0.0
					window_materials.append(base)
				if path.contains("kage") or base.resource_name.contains("kage"):
					# Sombra pintada del modelo: semitransparente, sin escribir profundidad.
					base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					base.render_priority = 1
				elif texture != null and texture.get_image() != null and texture.get_image().detect_alpha() != Image.ALPHA_NONE:
					base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					base.alpha_scissor_threshold = 0.5
				base.cull_mode = BaseMaterial3D.CULL_DISABLED
			_materials[key] = fixed
		mesh.set_surface_override_material(surface, _materials[key])
