class_name PropModels3D
extends RefCounted
## Vegetación y objetos del mundo abierto en 3D estilo B2W2 (regla 1 de
## docs/reglas_calidad.md, 2026-10-10): nada plano salvo Pokémon, personajes y NPC.
##
## Dos familias:
## - Modelos reales de B2W2 sueltos (The Models Resource, `art/models/b2w2_nature/`):
##   árboles muertos, tocones, el árbol grande del bosque blanco, rocas y cerca. Se
##   instancian igual que BuildingModels (misma escala 0.08, mismo arreglo de materiales).
## - "3D propio de pocas caras con textura pixel" para lo que no existe como modelo suelto
##   (los árboles, arbustos, flores y hierba de B2W2 vienen pintados dentro de sus mapas,
##   no como piezas separadas; ver docs/sistemas/arte.md): follaje en cruz de 2 planos con
##   la textura pixel ya usada en el juego, rocas con la misma malla de BreakableRock,
##   troncos/conchas/huesos con primitivas simples.

const ROOT := "res://art/models/b2w2_nature/"
const SCALE := 0.08

## Objetos sueltos reales de B2W2 (una sola malla cada uno, sin problemas de hueso/piel).
const STANDALONE := {
	"dead_tree1": "b2w2obj_dead_tree1", "dead_tree2": "b2w2obj_dead_tree2",
	"stump1": "b2w2obj_stump1", "stump2": "b2w2obj_stump2",
	"white_forest_tree": "b2w2obj_white_forest_tree2",
	"blue_rock": "b2w2obj_blue_rock", "cave_rock": "b2w2obj_cave_rock",
	"nature_shrine": "b2w2obj_shrine",
}

static var _scenes := {}
static var _materials := {}
static var _mesh_cache := {}


# --- Modelos sueltos reales (igual que BuildingModels) ------------------------------------

## Instancia un modelo suelto. Devuelve {"node": Node3D, "size": Vector3 (m)} con la base
## apoyada en y = 0 y la planta centrada en el origen.
static func instance(kind: String) -> Dictionary:
	if not STANDALONE.has(kind):
		return {}
	var scene := _scene(STANDALONE[kind])
	if scene == null:
		return {}
	var node := scene.instantiate() as Node3D
	node.scale = Vector3.ONE * SCALE
	var box := AABB()
	var first := true
	for mesh_node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		if mesh.mesh == null:
			continue
		_fix_materials(mesh)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh.visibility_range_end = 220.0
		var local := _local_transform(mesh, node) * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	var center := box.get_center()
	var holder := Node3D.new()
	holder.name = "Model_" + kind
	holder.add_child(node)
	node.position = Vector3(-center.x, -box.position.y, -center.z) * SCALE
	return {"node": holder, "size": box.size * SCALE}


static func _scene(folder: String) -> PackedScene:
	if _scenes.has(folder):
		return _scenes[folder]
	var scene: PackedScene = null
	var dir := ROOT + folder + "/"
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".dae"):
				scene = load(dir + file) as PackedScene
				break
	_scenes[folder] = scene
	return scene


static func _local_transform(node: Node3D, root: Node3D) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			transform = (current as Node3D).transform * transform
		current = current.get_parent()
	return transform


static func _fix_materials(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
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
				base.cull_mode = BaseMaterial3D.CULL_DISABLED
				var texture := base.albedo_texture
				if texture != null and texture.get_image() != null and texture.get_image().detect_alpha() != Image.ALPHA_NONE:
					base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					base.alpha_scissor_threshold = 0.5
			_materials[key] = fixed
		mesh.set_surface_override_material(surface, _materials[key])


# --- Follaje en cruz (árboles, arbustos, flores, hierba, cactus...) -----------------------

## Malla de 2 planos cruzados con la textura (como el follaje de Minecraft): pocas caras,
## se lee desde cualquier ángulo horizontal y tiene volumen real (no es un sprite plano).
## El pie queda en y = 0. Se cachea por textura (la altura/ancho salen de su tamaño en px).
static func cross_mesh(texture: Texture2D, pixel_size: float) -> ArrayMesh:
	var key := "cross:%d:%.4f" % [texture.get_instance_id(), pixel_size]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var width := texture.get_size().x * pixel_size
	var height := texture.get_size().y * pixel_size
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width * 0.5
	for angle in [0.0, PI * 0.5]:
		var right := Vector3(cos(angle), 0.0, sin(angle)) * hw
		var corners := [Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(-1, 1, 0)]
		var verts: Array[Vector3] = []
		for c: Vector3 in corners:
			verts.append(right * c.x + Vector3(0.0, height * c.y, 0.0))
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for tri in [[0, 1, 2], [0, 2, 3], [0, 2, 1], [0, 3, 2]]:
			for i in tri:
				st.set_uv(uvs[i])
				st.add_vertex(verts[i])
	st.generate_normals()
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


# --- Rocas y objetos del suelo (pocas caras, color sólido) --------------------------------

## Cuántas formas distintas de roca decorativa hay en todo el mundo (igual técnica que
## reusar una textura: variedad visible sin una malla nueva por roca, que crecería sin
## límite en un mundo de 4×4 km con miles de rocas — ver docs/sistemas/arte.md).
const ROCK_VARIANTS := 10

## Roca pequeña decorativa: misma malla que BreakableRock (pocas caras, forma irregular),
## con un color plano (sin textura pixel propia: antes eran sprites genéricos). variant_key
## (p. ej. la posición) elige una de ROCK_VARIANTS formas fijas de ese tamaño.
static func rock_mesh(variant_key: String, size: Vector3) -> ArrayMesh:
	var variant := hash(variant_key) % ROCK_VARIANTS
	var key := "rock:%d:%.2f:%.2f:%.2f" % [variant, size.x, size.y, size.z]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 97 + 11
	var mesh := BreakableRock.rock_mesh(size, rng)
	_mesh_cache[key] = mesh
	return mesh


## Tronco/madera a la deriva: cilindro de pocas caras, tumbado de costado y apoyado en
## y = 0 si lying es true (troncos en el suelo); de pie si es false.
static func log_mesh(length: float, radius: float, lying: bool = true) -> ArrayMesh:
	var key := "log:%.2f:%.2f:%s" % [length, radius, lying]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = length
	cylinder.radial_segments = 7
	cylinder.rings = 0
	var st := SurfaceTool.new()
	st.create_from(cylinder, 0)
	var array_mesh := st.commit()
	if lying:
		var arrays := array_mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var basis := Basis(Vector3.RIGHT, PI * 0.5)
		for i in verts.size():
			verts[i] = basis * verts[i] + Vector3(0, radius, 0)
			normals[i] = basis * normals[i]
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		array_mesh = ArrayMesh.new()
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_cache[key] = array_mesh
	return array_mesh


## Huesos: un par de cajas finas cruzadas (pocas caras).
static func bones_mesh() -> ArrayMesh:
	var key := "bones"
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box_a := BoxMesh.new()
	box_a.size = Vector3(0.45, 0.07, 0.07)
	var box_b := BoxMesh.new()
	box_b.size = Vector3(0.3, 0.07, 0.07)
	_append_box(st, box_a, Transform3D(Basis.IDENTITY, Vector3(0, 0.04, 0)))
	_append_box(st, box_b, Transform3D(Basis(Vector3.UP, 0.9), Vector3(0.05, 0.04, 0.05)))
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


## Nenúfar u hoja flotante: lámina delgada horizontal con la textura arriba y abajo (no es
## un plano: tiene borde y grosor reales, pensada para flotar en el agua).
static func pad_mesh(texture: Texture2D, pixel_size: float, thickness: float = 0.03) -> ArrayMesh:
	var key := "pad:%d:%.4f" % [texture.get_instance_id(), pixel_size]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var width := texture.get_size().x * pixel_size
	var depth := texture.get_size().y * pixel_size
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width * 0.5
	var hd := depth * 0.5
	var top_y := thickness
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
		for data in [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]:
			st.set_uv(data[1])
			st.add_vertex(data[0])
	# Cara de arriba (la que se ve desde la cámara) y de abajo, con la misma textura.
	quad.call(Vector3(-hw, top_y, -hd), Vector3(hw, top_y, -hd), Vector3(hw, top_y, hd), Vector3(-hw, top_y, hd),
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	quad.call(Vector3(-hw, 0.0, hd), Vector3(hw, 0.0, hd), Vector3(hw, 0.0, -hd), Vector3(-hw, 0.0, -hd),
			Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))
	st.generate_normals()
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


## Tablilla/letrero/boca de cueva: lámina delgada DE PIE (plano XY) con la textura al
## frente y atrás, con grosor real (no es un cartel plano). Pivote en el pie (y = 0).
static func plaque_mesh(texture: Texture2D, pixel_size: float, thickness: float = 0.05) -> ArrayMesh:
	var key := "plaque:%d:%.4f" % [texture.get_instance_id(), pixel_size]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var width := texture.get_size().x * pixel_size
	var height := texture.get_size().y * pixel_size
	var hw := width * 0.5
	var hz := thickness * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
		for data in [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]:
			st.set_uv(data[1])
			st.add_vertex(data[0])
	# Frente y atrás, con la textura completa.
	quad.call(Vector3(-hw, 0, hz), Vector3(hw, 0, hz), Vector3(hw, height, hz), Vector3(-hw, height, hz),
			Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))
	quad.call(Vector3(hw, 0, -hz), Vector3(-hw, 0, -hz), Vector3(-hw, height, -hz), Vector3(hw, height, -hz),
			Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))
	st.generate_normals()
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


## Concha: cono bajo achatado (pocas caras).
static func shell_mesh() -> ArrayMesh:
	var key := "shell"
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var cone := CylinderMesh.new()
	cone.top_radius = 0.01
	cone.bottom_radius = 0.16
	cone.height = 0.12
	cone.radial_segments = 6
	var st := SurfaceTool.new()
	st.create_from(cone, 0)
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


static func _append_box(st: SurfaceTool, box: BoxMesh, transform: Transform3D) -> void:
	var temp := SurfaceTool.new()
	temp.create_from(box, 0)
	var arrays := temp.commit().surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in indices.size():
		var idx := indices[i]
		st.set_normal(transform.basis * normals[idx])
		st.add_vertex(transform * verts[idx])


## Malla y material de un objeto de decoración (follaje en cruz, roca, tronco, hueso,
## concha o cerca real) según PropArt.kind_of(texture); por defecto (texturas que no vienen
## de PropArt, como los arbustos y plantas .tres de BiomeConfig) es follaje en cruz. Lo usan
## world_builder.gd (decoración del campo abierto) y structures.gd (junto a los edificios y
## las plazas con identidad de pueblo). El material se aplica con material_override (la
## malla base queda compartida y sin tocar, para no gastar memoria con miles de instancias).
static func decor_visual(texture: Texture2D, tint: Color, pixel_size: float) -> Dictionary:
	var kind := PropArt.kind_of(texture)
	if kind == "old_fence":
		return {"mesh": fence_mesh(), "material": null}
	if kind in PropArt.ROCK_KINDS:
		var size := texture.get_size() * pixel_size
		var mesh := rock_mesh(kind, Vector3(size.x, size.y, size.x))
		return {"mesh": mesh, "material": solid_material(tint * _kit_color(kind))}
	if kind in PropArt.LOG_KINDS:
		var size := texture.get_size() * pixel_size
		var mesh := log_mesh(size.x, size.y * 0.5, true)
		return {"mesh": mesh, "material": solid_material(tint * _kit_color(kind))}
	if kind in PropArt.BONES_KINDS:
		return {"mesh": bones_mesh(), "material": solid_material(Color(0.92, 0.9, 0.82))}
	if kind in PropArt.SHELL_KINDS:
		return {"mesh": shell_mesh(), "material": solid_material(_kit_color(kind))}
	var seasonal := not kind.begins_with("tuft") and kind != "" and not kind.begins_with("coral")
	var glow := kind == "glow_mushroom"
	var cross := cross_mesh(texture, pixel_size)
	return {"mesh": cross, "material": FoliageMaterials.for_texture(texture, tint, seasonal, glow)}


## Color aproximado de cada pieza del kit de bioma que ya no usa su textura pixel (rocas,
## troncos y conchas pasaron a malla + color plano; ver PropArt y decor_visual).
static func _kit_color(kind: String) -> Color:
	match kind:
		"boulder":
			return Color(0.58, 0.55, 0.5)
		"mossy_rock":
			return Color(0.5, 0.56, 0.46)
		"lava_rock":
			return Color(0.3, 0.22, 0.2)
		"snow_pile":
			return Color(0.95, 0.97, 1.0)
		"log":
			return Color(0.5, 0.35, 0.22)
		"mossy_log":
			return Color(0.42, 0.4, 0.22)
		"driftwood":
			return Color(0.72, 0.65, 0.56)
		"shell":
			return Color(1.0, 0.82, 0.78)
		"shell_blue":
			return Color(0.72, 0.85, 1.0)
	return Color.WHITE


## Cerca vieja de los campos: el modelo real de B2W2 (BuildingModels "fence"), fundido en
## una sola malla con sus materiales para poder repetirla en MultiMesh (decoración del
## campo abierto, sin colisión individual).
static func fence_mesh() -> ArrayMesh:
	var key := "fence_decor"
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var model: Dictionary = BuildingModels.instance("fence", 0)
	var mesh: ArrayMesh
	if model.is_empty():
		mesh = ArrayMesh.new()
	else:
		var node := model["node"] as Node3D
		mesh = _merge(node)
		node.free()
	_mesh_cache[key] = mesh
	return mesh


## Funde todas las MeshInstance3D de una escena (con su transform local) en una sola
## ArrayMesh de varias superficies, cada una con su material (para usarla en MultiMesh).
static func _merge(root: Node3D) -> ArrayMesh:
	var result := ArrayMesh.new()
	for mesh_node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var local := _local_transform(mesh_instance, root)
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var transformed_verts := PackedVector3Array()
			var transformed_normals := PackedVector3Array()
			for v in verts:
				transformed_verts.append(local * v)
			for n in normals:
				transformed_normals.append(local.basis * n)
			arrays[Mesh.ARRAY_VERTEX] = transformed_verts
			arrays[Mesh.ARRAY_NORMAL] = transformed_normals
			var surface_index := result.get_surface_count()
			result.add_surface_from_arrays(mesh_instance.mesh.surface_get_primitive_type(surface), arrays)
			var material := mesh_instance.get_active_material(surface)
			if material != null:
				result.surface_set_material(surface_index, material)
	return result


# --- Materiales -----------------------------------------------------------------------

## Material sólido con luz normal (sigue el día/noche como todo el mundo); se usa para
## rocas, troncos, huesos y conchas.
static var _solid_materials := {}
static func solid_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _solid_materials.has(key):
		return _solid_materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_solid_materials[key] = material
	return material
