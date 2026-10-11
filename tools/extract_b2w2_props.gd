extends SceneTree
## Herramienta de extracción: separa árboles, hierba, flores y rocas sueltas de los
## mapas B2W2 (art/models/b2w2_nature/b2w2map_*) y los guarda como piezas reutilizables
## en art/models/b2w2_props/<bioma>/<pieza>.tscn (ver docs/sistemas/arte.md).
##
## Cada pieza conserva su malla y materiales (filtro de píxel y recorte de alfa como en
## world/region/building_models.gd), con el origen puesto en el pie de la pieza. La
## escala NO se aplica aquí (igual que BuildingModels.SCALE, se aplica al instanciar).
##
## Uso: godot --headless --path . --script tools/extract_b2w2_props.gd

const JOBS := [
	# Bosque (pradera/bosque B2W2): árboles ki02, matas de hierba alta y flor.
	{"map": "res://art/models/b2w2_nature/b2w2map_pinwheel_forest/Pinwheel Forest.dae", "biome": "bosque",
			"props": ["ki02ax", "ki02bx", "ki02c", "ki02dx", "kusa_ec1", "kusa_ec2", "kusa_ec3", "hana01_1", "grass01ax", "rock_01", "rock_02", "mori01s"]},
	# Granja/pradera (Floccesy Ranch): árboles ki03, mismas matas de hierba.
	{"map": "res://art/models/b2w2_nature/b2w2map_floccesy_ranch/Floccesy Ranch.dae", "biome": "campo",
			"props": ["ki03ax", "ki03bx", "ki03dx", "kisetu_hana"]},
	# Costa (Route 1): roca de mar suelta de buena calidad.
	{"map": "res://art/models/b2w2_nature/b2w2map_route01/Route 1.dae", "biome": "costa",
			"props": ["searock_01"]},
	# Bosque perdido (Lostlorn Forest): tocones sueltos (ya existen como objeto aparte,
	# se confirma que coinciden con los de b2w2obj_stump1/2).
	{"map": "res://art/models/b2w2_nature/b2w2map_lostlorn_forest/Lostlorn Forest.dae", "biome": "bosque",
			"props": ["searock_02"]},
]

const SOURCE_FILTER := ["mado", "win"]


func _init() -> void:
	var report: Array[String] = []
	for job: Dictionary in JOBS:
		report.append_array(_extract(job))
	print("\n=== Catálogo de piezas extraídas (tools/extract_b2w2_props.gd) ===")
	for line in report:
		print(line)
	quit()


func _extract(job: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var path: String = job["map"]
	var biome: String = job["biome"]
	if not ResourceLoader.exists(path):
		lines.append("FALTA mapa: %s" % path)
		return lines
	var packed := load(path) as PackedScene
	if packed == null:
		lines.append("NO CARGÓ: %s" % path)
		return lines
	var root := packed.instantiate()
	var dir := "res://art/models/b2w2_props/%s" % biome
	DirAccess.make_dir_recursive_absolute(dir)
	for prop_name: String in job["props"]:
		var anchor := _find_named(root, prop_name)
		if anchor == null:
			lines.append("  [%s] no se encontró '%s' en %s" % [biome, prop_name, path.get_file()])
			continue
		var meshes := _collect_meshes(anchor)
		if meshes.is_empty():
			lines.append("  [%s] '%s' no tiene mallas" % [biome, prop_name])
			continue
		var built := _build_prop(anchor, meshes, prop_name)
		var out_path := "%s/%s.tscn" % [dir, prop_name]
		var err := ResourceSaver.save(built["scene"], out_path)
		if err != OK:
			lines.append("  [%s] ERROR guardando %s (%d)" % [biome, prop_name, err])
			continue
		var size: Vector3 = built["size"]
		lines.append("  [%s] %s <- %s (%d mallas, %.2f x %.2f x %.2f u)" % [biome, prop_name, path.get_file(), meshes.size(), size.x, size.y, size.z])
	root.free()
	return lines


## Primer nodo cuyo nombre es exactamente prop_name (los duplicados de Maya llevan
## sufijo "_1", "_2"... en Collada; se toma el primero, que es representativo).
func _find_named(root: Node, prop_name: String) -> Node3D:
	if root.name == prop_name and root is Node3D:
		return root as Node3D
	for child in root.get_children():
		var found := _find_named(child, prop_name)
		if found != null:
			return found
	return null


func _collect_meshes(anchor: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if anchor is MeshInstance3D:
		result.append(anchor as MeshInstance3D)
	for child in anchor.get_children():
		result.append_array(_collect_meshes(child))
	return result


## Transform local de node relativo a root (igual que BuildingModels._local_transform).
func _local_transform(node: Node3D, root: Node) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			transform = (current as Node3D).transform * transform
		current = current.get_parent()
	return transform


func _build_prop(anchor: Node3D, meshes: Array[MeshInstance3D], prop_name: String) -> Dictionary:
	var holder := Node3D.new()
	holder.name = "Prop_" + prop_name
	var box := AABB()
	var first := true
	var parts: Array[MeshInstance3D] = []
	for source in meshes:
		if source.mesh == null:
			continue
		var local := _local_transform(source, anchor)
		# Reflejo (agua) con escala negativa: no sirve como pieza suelta.
		if local.basis.determinant() < 0.0:
			continue
		var fresh := MeshInstance3D.new()
		fresh.name = source.name
		fresh.mesh = _rebuild_mesh(source.mesh)
		fresh.transform = local
		_fix_materials(fresh)
		fresh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var world_box := local * fresh.mesh.get_aabb()
		box = world_box if first else box.merge(world_box)
		first = false
		parts.append(fresh)
	var center := box.get_center()
	for part in parts:
		part.position -= Vector3(center.x, box.position.y, center.z)
		holder.add_child(part)
	var packed := PackedScene.new()
	packed.pack(holder)
	holder.free()
	return {"scene": packed, "size": box.size}


## Copia la malla quitando huesos/pesos (las piezas quedan estáticas en su pose de
## reposo: los árboles y matas de B2W2 no se animan en el juego).
func _rebuild_mesh(source: Mesh) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		var material := source.surface_get_material(surface)
		if material != null:
			result.surface_set_material(surface, material)
	return result


## Mismo tratamiento que BuildingModels._fix_materials: píxel nítido, recorte de alfa,
## sin reflejos de especular.
func _fix_materials(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
	for surface in mesh.mesh.get_surface_count():
		var material := mesh.mesh.surface_get_material(surface)
		if material == null:
			continue
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
		mesh.mesh.surface_set_material(surface, fixed)
