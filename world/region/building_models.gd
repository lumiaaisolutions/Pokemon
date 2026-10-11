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
	# "shop" son puestos de mercado (no sirve para laboratorio ni concursos).
	"lab": ["lab", "lab2"],
	"contest": ["aspertia_building2"],
	# Comida (campamento, comida y hambre): villa con terraza de Undella y puestos con toldo.
	"restaurant": ["undella_house2"],
	"food_stall": ["shop"],
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
	"windmill": ["windmill"],
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
		# Reflejo de la DS: copia del modelo con escala negativa (para el agua). Se oculta.
		if _local_transform(mesh, node).basis.determinant() < 0.0:
			mesh.visible = false
			continue
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
	# Algunos modelos de la DS traen su reflejo (para el agua) bajo el nivel 0: el suelo
	# real es y = 0 y el reflejo queda enterrado bajo el terreno.
	var base_y := box.position.y
	if box.position.y < -box.size.y * 0.25 and box.end.y > box.size.y * 0.25:
		base_y = 0.0
		box = AABB(Vector3(box.position.x, 0.0, box.position.z), Vector3(box.size.x, box.end.y, box.size.z))
	node.position = Vector3(-center.x, -base_y, -center.z) * SCALE
	var size := box.size * SCALE
	# Núcleo sólido: los modelos de la DS no tienen las caras que nunca se veían (la parte
	# de atrás); por dentro va una caja del color de sus paredes para tapar los huecos.
	if not kind in DECOR_KINDS:
		var core := MeshInstance3D.new()
		core.name = "Core"
		var cube := BoxMesh.new()
		# Por defecto solo tapa la mitad trasera (el frente, con la puerta y las ventanas,
		# suele quedar bajo un alero que mide más que la pared: un núcleo centrado llegaba
		# hasta la fachada y la tapaba, como si no tuviera puerta; reportado por Fernando
		# el 2026-10-10). CORE_SHAPES tiene ajustes a la medida para modelos puntuales.
		var shape: Array = CORE_SHAPES.get(name, [0.0, 0.9, 0.5, 0.78, -0.25, ""])
		cube.size = Vector3(size.x * float(shape[1]), size.y * float(shape[3]), size.z * float(shape[2]))
		core.mesh = cube
		core.position = Vector3(size.x * float(shape[0]), cube.size.y * 0.5, size.z * float(shape[4]))
		# Parte trasera con diseño (Fernando, 2026-10-11): la caja usa la textura real de las
		# paredes del modelo (no un color liso), con su techo y ventanas.
		var textures := _dominant_textures(node)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color.html(String(CORE_SHAPES[name][5])) if CORE_SHAPES.has(name) else Color.WHITE
		var wall_texture: Texture2D = textures.get("wall")
		if wall_texture != null and not CORE_SHAPES.has(name):
			material.albedo_texture = wall_texture
			material.uv1_triplanar = true
			material.uv1_scale = Vector3.ONE * BACK_TILE
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		elif not CORE_SHAPES.has(name):
			# Sin textura que sirva: el color de sus paredes con un patrón pixel de tablones.
			material.albedo_texture = _plank_texture(_wall_color(name))
			material.uv1_triplanar = true
			material.uv1_scale = Vector3.ONE * BACK_TILE
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		material.roughness = 1.0
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		core.material_override = material
		core.visibility_range_end = 520.0
		holder.add_child(core)
		_back_details(holder, core, cube.size, textures)
	return {"node": holder, "size": size, "front": size.z * 0.5}


## Tipos que son decoración (sin núcleo).
const DECOR_KINDS := ["lamp", "fence", "sign", "bench", "stump", "windmill", "food_stall"]
## Núcleo a la medida para modelos con partes abiertas (terrazas): [centro x, ancho, fondo,
## alto, centro z] como fracción del tamaño y el color de sus paredes. La villa de Undella
## tiene la terraza a la izquierda y la fachada adelantada.
const CORE_SHAPES := {"undella_house2": [0.2, 0.46, 0.5, 0.62, -0.18, "e8ecf0"]}
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
		# La textura con transparencia (rejas, marcos) no es pared: en su promedio pesa el
		# hueco y el color salía casi negro (tienda shop3, invernadero).
		if image != null and image.detect_alpha() != Image.ALPHA_NONE:
			continue
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
	# Nunca una pared casi negra: si salió muy oscuro, se aclara.
	if color.get_luminance() < 0.18:
		color = color.lightened(0.45)
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
				# Ojo: "c7wind*" es el molino, no ventanas (antes brillaba entero de noche).
				if is_window_texture(path):
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


## ¿La textura es de ventanas? ("mado" en japonés, o "win" seguido de número: pc_win1).
static func is_window_texture(path: String) -> bool:
	var file := path.get_file().to_lower()
	if file.contains("mado"):
		return true
	var regex := RegEx.new()
	regex.compile("(^|_)win[0-9]")
	return regex.search(file) != null


## Repeticiones de la textura de pared por metro en la parte trasera.
const BACK_TILE := 0.32


## Texturas que más área ocupan en el modelo: "wall" (caras verticales), "roof" (caras que
## miran hacia arriba en lo alto) y "window" (ventanas), sin contar las sombras pintadas.
static func _dominant_textures(node: Node3D) -> Dictionary:
	var wall_area := {}
	var roof_area := {}
	var window: Texture2D = null
	for mesh_node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var top := mesh_instance.mesh.get_aabb().end.y
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface) as BaseMaterial3D
			if material == null or material.albedo_texture == null:
				continue
			var texture := material.albedo_texture
			var path := texture.resource_path.to_lower()
			if path.contains("kage") or path.contains("shadow"):
				continue
			if is_window_texture(path):
				window = texture
				continue
			# Las texturas con transparencia (rejas, marcos) no sirven de pared ni techo:
			# en la caja se verían sus huecos (magenta) repetidos.
			var image := texture.get_image()
			if image != null and image.detect_alpha() != Image.ALPHA_NONE:
				continue
			# Solo texturas que se repiten bien (bordes que empatan): las que son una pieza
			# grande (puertas, letreros, techos con dibujo) se ven como parches al repetirse.
			if image != null and not _tiles_well(image):
				continue
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for t in range(0, count - 2, 3):
				var a := vertices[indices[t] if not indices.is_empty() else t]
				var b := vertices[indices[t + 1] if not indices.is_empty() else t + 1]
				var c := vertices[indices[t + 2] if not indices.is_empty() else t + 2]
				var cross := (b - a).cross(c - a)
				var area := cross.length() * 0.5
				if area <= 0.0:
					continue
				var normal := cross / (area * 2.0)
				if absf(normal.y) < 0.3:
					wall_area[texture] = float(wall_area.get(texture, 0.0)) + area
				elif absf(normal.y) > 0.5 and (a.y + b.y + c.y) / 3.0 > top * 0.55:
					roof_area[texture] = float(roof_area.get(texture, 0.0)) + area
	return {"wall": _largest(wall_area), "roof": _largest(roof_area), "window": window}


static func _largest(areas: Dictionary) -> Texture2D:
	var best: Texture2D = null
	var best_area := 0.0
	for texture: Texture2D in areas:
		if float(areas[texture]) > best_area:
			best_area = float(areas[texture])
			best = texture
	return best


## Techo con su textura encima de la caja trasera y ventanas en la pared de atrás.
static func _back_details(holder: Node3D, core: MeshInstance3D, size: Vector3, textures: Dictionary) -> void:
	var roof_texture: Texture2D = textures.get("roof")
	if roof_texture != null:
		var roof := MeshInstance3D.new()
		roof.name = "BackRoof"
		var slab := BoxMesh.new()
		slab.size = Vector3(size.x * 1.04, maxf(size.y * 0.06, 0.12), size.z * 1.04)
		roof.mesh = slab
		var material := StandardMaterial3D.new()
		material.albedo_texture = roof_texture
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * BACK_TILE
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		material.roughness = 1.0
		roof.material_override = material
		roof.position = core.position + Vector3(0, size.y * 0.5 + slab.size.y * 0.5, 0)
		roof.visibility_range_end = 520.0
		holder.add_child(roof)
	var window_texture: Texture2D = textures.get("window")
	if window_texture == null or size.x < 2.0 or size.y < 1.6:
		return
	var count := clampi(int(size.x / 2.2), 1, 4)
	for i in count:
		var pane := MeshInstance3D.new()
		pane.name = "BackWindow%d" % i
		var quad := QuadMesh.new()
		quad.size = Vector2(minf(1.1, size.x / (count + 1)), minf(0.9, size.y * 0.3))
		pane.mesh = quad
		var material := StandardMaterial3D.new()
		material.albedo_texture = window_texture
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.roughness = 1.0
		pane.material_override = material
		pane.position = core.position + Vector3(-size.x * 0.5 + size.x * (i + 1) / (count + 1), size.y * 0.15, -size.z * 0.5 - 0.02)
		pane.rotation.y = PI
		holder.add_child(pane)


## ¿El borde izquierdo empata con el derecho y el de arriba con el de abajo? (textura que
## se repite sin que se note el corte).
static func _tiles_well(image: Image) -> bool:
	var w := image.get_width()
	var h := image.get_height()
	if w < 8 or h < 8:
		return false
	var diff := 0.0
	var samples := 0
	for y in range(0, h, maxi(h / 16, 1)):
		var a := image.get_pixel(0, y)
		var b := image.get_pixel(w - 1, y)
		diff += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
		samples += 1
	for x in range(0, w, maxi(w / 16, 1)):
		var a := image.get_pixel(x, 0)
		var b := image.get_pixel(x, h - 1)
		diff += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
		samples += 1
	if diff / maxf(samples, 1) >= 0.35:
		return false
	# Muchas zonas negras (marcos de ventanas con hueco): no sirve de pared.
	var dark := 0
	var total := 0
	for y in range(0, h, maxi(h / 12, 1)):
		for x in range(0, w, maxi(w / 12, 1)):
			total += 1
			if image.get_pixel(x, y).get_luminance() < 0.08:
				dark += 1
	return float(dark) / maxf(total, 1) < 0.12


static var _planks := {}


## Tablones pixel de 16×16 en el color dado (pared trasera sin textura propia).
static func _plank_texture(color: Color) -> ImageTexture:
	var key := color.to_html()
	if _planks.has(key):
		return _planks[key]
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var c := color
			if y % 4 == 3:
				c = color.darkened(0.25)
			elif (x + (y / 4) * 5) % 8 == 0:
				c = color.darkened(0.15)
			elif (x * 7 + y * 3) % 11 == 0:
				c = color.lightened(0.06)
			image.set_pixel(x, y, c)
	var texture := ImageTexture.create_from_image(image)
	_planks[key] = texture
	return texture
