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
##   no como piezas separadas; ver docs/sistemas/arte.md): follaje 3D de verdad
##   (`foliage_mesh`: tronco + copa de volúmenes reales, pocas caras, perfil distinto por
##   bioma, reemplaza la antigua cruz de 2 planos — 2026-10-11), rocas con la misma malla
##   de BreakableRock, troncos/conchas/huesos con primitivas simples.

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


# --- Follaje 3D de verdad (árboles, arbustos, flores, hierba, cactus...) ------------------
## Reemplaza la antigua "cruz de 2 planos" (2026-10-11, pedido de Fernando: "nada plano
## desde ningún ángulo", ni siquiera desde arriba). Tronco = prisma de pocas caras
## (`_revolve`/`_branch`); copa = volúmenes reales (varias capas/anillos facetados que
## cierran en una punta arriba, nunca en una tapa plana) con un perfil de radio distinto
## por tipo (`FOLIAGE_SHAPES`); hierba alta, juncos, cristales y coral = mechones de hojas
## en V con grosor real (`_blade`). Todo sigue usando la textura pixel real del objeto
## (envuelta alrededor de la malla, igual idea que antes pero ahora con volumen real) salvo
## las tapas pequeñas (base del tronco, puntas de flor...) que usan un color sacado de la
## propia textura (`_sample_uv`) en vez de estirarla sobre un disco diminuto.

## Tipos de copa/forma reconocidos por `foliage_mesh`. "" (no reconocido) cae en "bush".
const FOLIAGE_SHAPES := ["round", "forest", "pine", "palm", "acacia", "dead", "cactus",
		"mushroom_giant", "mushroom_small", "flower", "bush", "bush_dry", "tuft", "reed",
		"coral", "crystal"]

## Deduce la forma a partir de qué textura de PropArt es (cactus, palmera, hongo, flor...);
## "" si la textura no viene de PropArt.texture() (árboles/decoración de BiomeConfig, que no
## tienen una forma fija por textura: la decide quien llama según el bioma, ver
## world_builder.gd _tree_shape) o si no hay una forma mejor que "bush" para ella.
static func auto_shape(texture: Texture2D) -> String:
	match PropArt.kind_of(texture):
		"cactus":
			return "cactus"
		"palm":
			return "palm"
		"acacia":
			return "acacia"
		"mushroom", "glow_mushroom":
			return "mushroom_giant"
		"toxic_mushroom", "brown_mushroom":
			return "mushroom_small"
		"flowers_pink", "flowers_blue", "flowers_white":
			return "flower"
		"dry_bush":
			return "bush_dry"
		"tuft_green", "tuft_light", "tuft_dry":
			return "tuft"
		"reeds", "cattails":
			return "reed"
		"coral", "coral_blue":
			return "coral"
		"ice_crystal":
			return "crystal"
	if texture.resource_path.get_file().begins_with("tuft"):
		return "tuft"
	return ""


## Malla de follaje 3D de verdad: tronco + copa de volúmenes (o el equivalente para
## arbustos/flores/hierba/cactus), con la textura real envuelta alrededor. `shape` fuerza
## una forma (world_builder.gd la calcula por bioma para los árboles); si viene vacía se
## deduce con `auto_shape` (y "bush" si tampoco hay nada mejor). `cheap` usa una copa barata
## de muy pocas caras (para los árboles lejanos en MultiMesh, mismo costo que antes pero sin
## quedar planos). Se cachea por forma/textura/tamaño de píxel.
static func foliage_mesh(texture: Texture2D, pixel_size: float, shape: String = "", cheap: bool = false) -> ArrayMesh:
	var resolved := shape if shape != "" else auto_shape(texture)
	if not resolved in FOLIAGE_SHAPES:
		resolved = "bush"
	var key := "fol:%s:%s:%d:%.4f" % [resolved, "cheap" if cheap else "full", texture.get_instance_id(), pixel_size]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var width := texture.get_size().x * pixel_size
	var height := texture.get_size().y * pixel_size
	var image := texture.get_image()
	var top_uv := _sample_uv(image, 0.0, 0.35)
	var accent_uv := _sample_uv(image, 0.3, 0.8)
	var base_uv := _sample_uv(image, 0.85, 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if cheap:
		_revolve(st, Vector3.ZERO, width, height, [[0.0, 0.1], [0.28, 0.12]], 4, base_uv, base_uv)
		_revolve(st, Vector3.ZERO, width, height, [[0.26, 0.6], [0.6, 0.9], [1.0, 0.0]], 5, Vector2(-1, -1), top_uv)
	else:
		_build_foliage(st, resolved, width, height, top_uv, accent_uv, base_uv, image)
	st.generate_normals()
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


static func _build_foliage(st: SurfaceTool, shape: String, width: float, height: float, top_uv: Vector2, accent_uv: Vector2, base_uv: Vector2, image: Image) -> void:
	var hw := width * 0.5
	match shape:
		"round", "forest":
			# Árbol de pradera/bosque estilo B2W2 (pedido de Fernando, 2026-10-11, tras ver
			# que el follaje no tenía look BW2): tronco corto marrón sólido + copa en capas/
			# bloques de "puffs" redondos (PUFF_PROFILE) con el sprite real de hoja de B2W2
			# (puff_round_*/puff_forest_*, ver docs/sistemas/arte.md) envuelto en cada uno —
			# un puff es casi igual de redondo desde cualquier lado, así que envolverlo no
			# lo corta en tajadas como pasaba con el árbol completo estirado en un tambor.
			var trunk_uv := _sample_uv(image, 0.0, 0.14)
			var puff_uv := _puff_uv_range(image)
			var dense := shape == "forest"
			var trunk_h := height * (0.16 if dense else 0.22)
			_revolve(st, Vector3.ZERO, width, trunk_h, [[0.0, 0.09], [1.0, 0.11]], 6, trunk_uv, trunk_uv)
			# Copa "regordeta" (ancha casi como alta, pedido de Fernando, 2026-10-11) hecha de
			# varios puffs que se solapan bastante entre sí y con la punta del tronco (nunca un
			# cuello/hueco visible), más densa y alta en bosque que en pradera.
			var canopy := hw * (2.0 if dense else 2.15)
			var base_y := trunk_h * 0.7
			_puff(st, Vector3(0.0, base_y, 0.0), hw * 1.7, canopy, puff_uv, 6)
			_puff(st, Vector3(hw * 0.42, base_y + canopy * 0.16, hw * 0.12), hw * 1.05, canopy * 0.64, puff_uv, 5)
			_puff(st, Vector3(-hw * 0.4, base_y + canopy * 0.18, -hw * 0.14), hw * 1.0, canopy * 0.6, puff_uv, 5)
			if dense:
				_puff(st, Vector3(hw * 0.06, base_y + canopy * 0.4, -hw * 0.05), hw * 0.72, canopy * 0.42, puff_uv, 5)
		"pine":
			# Pino escalonado B2W2 (ki02ax): tronco corto + 4 niveles de puffs achatados
			# apilados sobre el mismo eje, metidos uno en el otro (no uno encima suelto del
			# otro), cada uno más chico que el de abajo (silueta cónica por capas).
			var trunk_uv := _sample_uv(image, 0.0, 0.14)
			var puff_uv := _puff_uv_range(image)
			var trunk_h := height * 0.14
			_revolve(st, Vector3.ZERO, width, trunk_h, [[0.0, 0.09], [1.0, 0.11]], 6, trunk_uv, trunk_uv)
			var ch := height - trunk_h
			var tiers := 4
			var tier_h := ch * 0.42
			var base_y := trunk_h * 0.35
			for i in tiers:
				var f := float(i) / float(tiers - 1)
				var y := base_y + ch * 0.58 * f
				var w_frac := lerpf(1.6, 0.5, f)
				_puff(st, Vector3(0.0, y, 0.0), hw * w_frac, tier_h, puff_uv, 6)
		"acacia":
			# Perfil de sabana (más parecido a B2W2/real que el domo redondo de antes,
			# 2026-10-11): tronco expuesto más alto y copa aplastada en forma de sombrilla
			# (ancha y baja, no un montículo redondo) montada arriba del todo.
			_revolve(st, Vector3.ZERO, width, height, [[0.0, 0.06], [0.62, 0.075]], 6, base_uv, base_uv)
			_revolve(st, Vector3.ZERO, width, height, [[0.58, 0.3], [0.68, 0.9], [0.82, 1.0], [0.93, 0.55], [1.0, 0.0]], 8, Vector2(-1, -1), top_uv)
		"dead":
			_revolve(st, Vector3.ZERO, width, height, [[0.0, 0.055], [0.85, 0.09]], 6, base_uv, base_uv)
			_branch_cluster(st, Vector3(0.0, height * 0.78, 0.0), 4, height * 0.18, hw * 0.05, 0.55, accent_uv)
		"palm":
			_revolve(st, Vector3.ZERO, width, height, [[0.0, 0.07], [0.35, 0.095], [0.72, 0.085]], 7, base_uv, base_uv)
			_palm_fronds(st, width, height, top_uv)
		"cactus":
			_revolve(st, Vector3.ZERO, width, height, [[0.0, 0.18], [0.08, 0.2], [0.92, 0.17], [1.0, 0.0]], 7, base_uv, base_uv)
			_branch(st, Vector3(0.0, height * 0.5, 0.0), Vector3(hw * 0.85, height * 0.64, 0.0), hw * 0.14, hw * 0.05, 6, top_uv)
			_branch(st, Vector3(0.0, height * 0.66, 0.0), Vector3(-hw * 0.72, height * 0.82, 0.0), hw * 0.12, hw * 0.04, 6, top_uv)
		"mushroom_giant":
			_revolve(st, Vector3.ZERO, width, height, [[0.0, 0.1], [0.5, 0.13]], 7, base_uv, base_uv)
			_revolve(st, Vector3.ZERO, width, height, [[0.48, 0.7], [0.62, 1.0], [0.8, 0.78], [0.92, 0.3], [1.0, 0.0]], 8, Vector2(-1, -1), top_uv)
		"mushroom_small":
			var offsets: Array[float] = [-0.32, 0.0, 0.32]
			var scales: Array[float] = [0.78, 1.0, 0.82]
			for i in 3:
				var origin := Vector3(hw * offsets[i], 0.0, 0.0)
				var h: float = height * scales[i]
				_revolve(st, origin, width * 0.3, h, [[0.0, 0.16], [0.55, 0.2]], 5, base_uv, base_uv)
				_revolve(st, origin, width * 0.3, h, [[0.5, 0.75], [0.62, 1.0], [0.8, 0.5], [1.0, 0.0]], 6, Vector2(-1, -1), top_uv)
		"flower":
			# El color del pétalo (`top_uv`, ya recoloreado por PropArt._flowers según el
			# tipo rosa/azul/blanco) va en los lados, que son la mayor parte de lo que se
			# ve; la hoja verde (`base_uv`) queda solo en la tapa chica de abajo (pegada al
			# suelo, casi no se ve) — antes era al revés y la mata entera salía verde sin
			# importar el color pedido (2026-10-11).
			_revolve(st, Vector3.ZERO, width, height, [[0.0, 0.3], [0.45, 0.9], [0.8, 0.6], [1.0, 0.0]], 6, base_uv, top_uv)
			_mound_nubs(st, width, height, 5, accent_uv)
		"bush_dry":
			_revolve(st, Vector3.ZERO, width, height, [[0.0, 0.3], [0.35, 0.7], [0.7, 0.45], [1.0, 0.0]], 6, base_uv, base_uv)
			_branch_cluster(st, Vector3(0.0, height * 0.55, 0.0), 5, height * 0.3, hw * 0.04, 0.9, accent_uv)
		"tuft":
			_blade_cluster(st, width, height, 5, 0.45, 0.0)
		"reed":
			_blade_cluster(st, width, height, 4, 0.16, 0.08)
		"coral":
			_branch_cluster(st, Vector3.ZERO, 5, height * 0.95, hw * 0.16, 0.25, top_uv)
		"crystal":
			_branch_cluster(st, Vector3.ZERO, 4, height * 0.98, hw * 0.14, 0.08, top_uv)
		_:
			# "bush": arbustos y matas de flor sin forma de PropArt (p. ej. bush.png/
			# flower_bush_pink.png/lavender.png de BiomeConfig y las flores del pueblo).
			# Pedido de Fernando, 2026-10-11: "burbujas de hoja como los árboles, más
			# bajos" — igual idea que la copa "round" de los árboles (varios puffs
			# achatados que se solapan, sin tronco), pero el sprite es un dibujo de
			# frente (no redondo como un puff real de B2W2), así que cada burbuja usa
			# el color real sacado de la textura (`solid_uv`) en vez de envolverla
			# (se cortaría en tajadas, misma razón que cactus/acacia).
			var lobe_h := height * 0.8
			var base_y := height * 0.04
			_revolve(st, Vector3(0.0, base_y, 0.0), hw * 1.6, lobe_h, PUFF_PROFILE, 6, Vector2(-1, -1), base_uv)
			_revolve(st, Vector3(hw * 0.46, base_y + lobe_h * 0.14, hw * 0.16), hw * 1.05, lobe_h * 0.62, PUFF_PROFILE, 5, Vector2(-1, -1), accent_uv)
			_revolve(st, Vector3(-hw * 0.44, base_y + lobe_h * 0.16, -hw * 0.18), hw * 1.0, lobe_h * 0.58, PUFF_PROFILE, 5, Vector2(-1, -1), base_uv)
			_revolve(st, Vector3(hw * 0.08, base_y + lobe_h * 0.42, -hw * 0.06), hw * 0.68, lobe_h * 0.42, PUFF_PROFILE, 5, Vector2(-1, -1), accent_uv)


## Luminancia por debajo de esto se considera el contorno oscuro de 1 px que `_outline`
## pinta alrededor de cada sprite de PropArt (`Color(0.1, 0.08, 0.08)`, luminancia ~0.084),
## no el color real del dibujo: `_sample_uv` lo salta (ver más abajo) para no terminar
## pintando cactus/acacia/hongos/flores casi negros (el contorno rodea todo el perímetro,
## así que scanear desde la esquina de la franja caía justo en él casi siempre, 2026-10-11).
const OUTLINE_LUMINANCE := 0.15


## Color de un punto representativo de la textura real (no estirarla sobre tapas chicas):
## primer píxel opaco "de verdad" (no el contorno oscuro) en las filas entre y0_frac y
## y1_frac (0 = arriba de la imagen); si la franja fuera solo contorno, se usa ese color
## antes que quedarse sin nada.
static func _sample_uv(image: Image, y0_frac: float, y1_frac: float) -> Vector2:
	if image == null:
		return Vector2(0.5, 0.9)
	var w := image.get_width()
	var h := image.get_height()
	var y_start := clampi(int(h * y0_frac), 0, h - 1)
	var y_end := clampi(maxi(y_start + 1, int(h * y1_frac)), y_start + 1, h)
	var fallback := Vector2(-1, -1)
	for y in range(y_start, y_end):
		for x in w:
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.5:
				continue
			if pixel.get_luminance() < OUTLINE_LUMINANCE:
				if fallback.x < 0.0:
					fallback = Vector2((float(x) + 0.5) / w, (float(y) + 0.5) / h)
				continue
			return Vector2((float(x) + 0.5) / w, (float(y) + 0.5) / h)
	if fallback.x >= 0.0:
		return fallback
	return Vector2(0.5, (y0_frac + y1_frac) * 0.5)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)


## Anillo facetado de revolución: conecta los puntos de `profile` (Array de [t, r], t =
## fracción de `height` 0..1 desde el pie, r = fracción del medio ancho 0..1) con `sides`
## caras por anillo (cada anillo gira medio facet respecto al anterior, para que no se vea
## como un cilindro perfecto). Si el primer radio no es 0 y se pasa `cap_uv`, tapa el pie con
## un color sacado de la textura real (nunca deja el tronco con el fondo abierto). Cuando el
## último radio es 0 la copa cierra sola en una punta (nunca una tapa plana arriba: regla 1).
## `solid_uv`: si se pasa, los lados usan ese único punto de la textura (color plano) en vez
## de envolver la imagen alrededor del tambor — necesario para cualquier sprite que no sea
## radialmente parecido (un árbol o un cactus dibujados de frente): envolverlos alrededor
## los corta en tajadas verticales que no se ven como el dibujo original (no es el estilo
## B2W2 que pidió Fernando, 2026-10-11). Los "puffs" de hoja (`_puff`) sí son redondos de
## verdad y usan el envolvido normal. `uv_v_range` acota en qué franja vertical de la
## textura se muestrea (por defecto toda, 0..1): los sprites de hoja sueltos (puff_*) son
## un blob redondo con margen transparente en las 4 esquinas/bordes del lienzo (para que el
## árbol completo salga alto en vez de cuadrado) — si el pie/la punta del puff cayeran justo
## en ese margen, el recorte de alfa del shader los volvería invisibles (el "hueco" que
## separaba la copa del tronco). `_puff` pasa una franja angosta y centrada en el blob.
static func _revolve(st: SurfaceTool, origin: Vector3, width: float, height: float, profile: Array, sides: int, cap_uv: Vector2 = Vector2(-1, -1), solid_uv: Vector2 = Vector2(-1, -1), uv_v_range: Vector2 = Vector2(0.0, 1.0)) -> void:
	var hw := width * 0.5
	var rings: Array = []
	for i in profile.size():
		var t: float = profile[i][0]
		var r: float = profile[i][1] * hw
		var y := height * t
		var offset := (PI / sides) * (i % 2)
		var ring: Array = []
		for s in sides:
			var angle := TAU * s / sides + offset
			ring.append(origin + Vector3(cos(angle) * r, y, sin(angle) * r))
		rings.append(ring)
	var solid := solid_uv.x >= 0.0
	for i in rings.size() - 1:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		var va: float = lerpf(uv_v_range.y, uv_v_range.x, profile[i][0])
		var vb: float = lerpf(uv_v_range.y, uv_v_range.x, profile[i + 1][0])
		for s in sides:
			var s2 := (s + 1) % sides
			var ua := float(s) / sides
			var ub := float(s + 1) / sides
			var uv0 := solid_uv if solid else Vector2(ua, va)
			var uv1 := solid_uv if solid else Vector2(ub, va)
			var uv2 := solid_uv if solid else Vector2(ub, vb)
			var uv3 := solid_uv if solid else Vector2(ua, vb)
			_tri(st, a[s], a[s2], b[s2], uv0, uv1, uv2)
			_tri(st, a[s], b[s2], b[s], uv0, uv2, uv3)
	if cap_uv.x >= 0.0 and float(profile[0][1]) > 0.001:
		var ring0: Array = rings[0]
		var center: Vector3 = origin + Vector3(0.0, height * float(profile[0][0]), 0.0)
		for s in sides:
			var s2 := (s + 1) % sides
			_tri(st, center, ring0[s2], ring0[s], cap_uv, cap_uv, cap_uv)


## Perfil de un "puff" de hoja (burbuja redondeada de pocas caras, como una esfera achatada):
## empieza ya ancho abajo (no en una punta — así no deja un cuello invisible al apoyarse en
## el tronco o en otro puff), se infla un poco más a la mitad y cierra en punta arriba
## (nunca una tapa plana arriba: regla 1 de docs/reglas_calidad.md).
const PUFF_PROFILE := [[0.0, 0.5], [0.3, 0.92], [0.55, 1.0], [0.82, 0.68], [1.0, 0.0]]


## Franja vertical (fracción 0..1, arriba..abajo) de la textura del puff que sí tiene dibujo:
## el blob redondo deja margen transparente en los bordes del lienzo (más aún con el lienzo
## alto 32×64 para que el árbol salga alto, no cuadrado — ver docs/sistemas/arte.md) y cada
## sprite real de B2W2 lo deja en un sitio/tamaño algo distinto (ki02dx, por ejemplo, es un
## blob más chico que ki03bx), así que no sirve una franja fija para los 4: se calcula una
## vez por textura buscando sus filas con dibujo real (saltando el parche marrón de la
## esquina, que es para el tronco). Sin esto el pie/la punta del puff podían caer en el
## margen transparente y el recorte de alfa del shader los volvía invisibles (el "hueco"
## que separaba la copa del tronco, 2026-10-11).
static func _puff_uv_range(image: Image) -> Vector2:
	if image == null:
		return Vector2(0.2, 0.8)
	var h := image.get_height()
	var w := image.get_width()
	var top := -1
	var bottom := -1
	for y in h:
		for x in w:
			if x < 4 and y < 4:
				continue
			if image.get_pixel(x, y).a > 0.5:
				if top < 0:
					top = y
				bottom = y
				break
	if top < 0 or bottom <= top:
		return Vector2(0.2, 0.8)
	var margin := maxf(float(bottom - top) * 0.12, 1.0)
	var lo := clampf((float(top) + margin) / h, 0.0, 1.0)
	var hi := clampf((float(bottom) - margin) / h, 0.0, 1.0)
	if hi <= lo:
		lo = float(top) / h
		hi = float(bottom) / h
	return Vector2(lo, hi)


## Dibuja un puff centrado en `origin`, de ancho `w` y alto `h` (metros), con el sprite real
## de hoja de B2W2 envuelto alrededor (redondo/parecido desde cualquier lado, a diferencia de
## envolver un árbol completo dibujado de frente). Varios puffs juntos arman la copa en
## capas/bloques (ver `_build_foliage`: "round", "forest", "pine"). `uv_range` viene de
## `_puff_uv_range` (una vez por árbol, no por puff).
static func _puff(st: SurfaceTool, origin: Vector3, w: float, h: float, uv_range: Vector2, sides: int = 6) -> void:
	_revolve(st, origin, w, h, PUFF_PROFILE, sides, Vector2(-1, -1), Vector2(-1, -1), uv_range)


## Rama/brazo/púa: cilindro de pocas caras (pocas caras, pie en `base`, punta en `tip`),
## con radio distinto en cada punta (0 en la punta = termina en punta, no en tapa plana).
static func _branch(st: SurfaceTool, base: Vector3, tip: Vector3, r0: float, r1: float, sides: int, uv: Vector2) -> void:
	var dir := tip - base
	var length := dir.length()
	if length < 0.001:
		return
	dir = dir / length
	var up := Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var side_a := dir.cross(up).normalized()
	var side_b := dir.cross(side_a).normalized()
	for s in sides:
		var a0 := TAU * s / sides
		var a1 := TAU * (s + 1) / sides
		var p0 := base + (side_a * cos(a0) + side_b * sin(a0)) * r0
		var p1 := base + (side_a * cos(a1) + side_b * sin(a1)) * r0
		var p0t := tip + (side_a * cos(a0) + side_b * sin(a0)) * r1
		var p1t := tip + (side_a * cos(a1) + side_b * sin(a1)) * r1
		_tri(st, p0, p1, p1t, uv, uv, uv)
		_tri(st, p0, p1t, p0t, uv, uv, uv)
	if r0 > 0.001:
		for s in sides:
			var a0 := TAU * s / sides
			var a1 := TAU * (s + 1) / sides
			var p0 := base + (side_a * cos(a0) + side_b * sin(a0)) * r0
			var p1 := base + (side_a * cos(a1) + side_b * sin(a1)) * r0
			_tri(st, base, p1, p0, uv, uv, uv)
	if r1 > 0.001:
		for s in sides:
			var a0 := TAU * s / sides
			var a1 := TAU * (s + 1) / sides
			var p0t := tip + (side_a * cos(a0) + side_b * sin(a0)) * r1
			var p1t := tip + (side_a * cos(a1) + side_b * sin(a1)) * r1
			_tri(st, tip, p0t, p1t, uv, uv, uv)


## Varias ramas/púas/ramas de coral que salen de `origin` hacia arriba, en abanico (ramas
## muertas, coral y cristales reusan esta misma idea con otro ángulo/grosor/altura).
static func _branch_cluster(st: SurfaceTool, origin: Vector3, count: int, length: float, radius: float, spread: float, uv: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(length * 1000.0) + int(radius * 7919.0) + count * 13
	for i in count:
		var angle := TAU * i / count + rng.randf_range(-0.2, 0.2)
		var len := length * rng.randf_range(0.75, 1.0)
		var dir := Vector3(cos(angle) * spread, 1.0, sin(angle) * spread).normalized()
		var base := origin
		var tip := origin + dir * len
		_branch(st, base, tip, radius, radius * 0.1, 4, uv)


## Pencas de palmera: hojas en V con grosor real (no un plano), que salen del punto más
## alto del tronco y se abren hacia afuera y un poco hacia abajo (como una palmera de
## verdad), con la textura real de la palmera envuelta en cada penca.
static func _palm_fronds(st: SurfaceTool, width: float, height: float, uv: Vector2) -> void:
	var hw := width * 0.5
	var top := Vector3(0.0, height * 0.72, 0.0)
	var count := 7
	for i in count:
		var angle := TAU * i / count
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var tip := top + out * hw * 1.3 + Vector3(0.0, -height * 0.22, 0.0)
		_blade(st, top, tip, out.cross(Vector3.UP).normalized(), hw * 0.22, hw * 0.12, 0.0, 1.0)


## Montículo con unas puntas pequeñas encima (pétalos de flor, pinchos de arbusto seco...):
## conos bajos en abanico sobre la copa, con el color real sacado de la textura.
static func _mound_nubs(st: SurfaceTool, width: float, height: float, count: int, uv: Vector2) -> void:
	var hw := width * 0.5
	for i in count:
		var angle := TAU * i / count + 0.3
		var r := hw * 0.45
		var origin := Vector3(cos(angle) * r, height * 0.55, sin(angle) * r)
		_revolve(st, origin, hw * 0.5, height * 0.22, [[0.0, 0.35], [1.0, 0.0]], 5, uv, uv)


## Mechón de hojas en V (hierba alta, juncos, cattails...): varias hojas con grosor real
## (cada una es un "libro abierto" de 2 caras que se encuentran en un filo, nunca un plano)
## repartidas en círculo. `count` hojas, `width_frac` ancho de cada hoja (fracción del medio
## ancho de la textura) y `depth_frac` qué tan "abierto" está el filo (0 = casi recto y
## alto, como un junco; más alto = más abierto, como una mata de pasto).
static func _blade_cluster(st: SurfaceTool, width: float, height: float, count: int, width_frac: float, depth_frac: float) -> void:
	var hw := width * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = int(width * 4001.0) + int(height * 7919.0) + count * 17
	for i in count:
		var angle := TAU * i / count + rng.randf_range(-0.25, 0.25)
		var h := height * rng.randf_range(0.8, 1.0)
		var w := hw * width_frac * rng.randf_range(0.8, 1.15)
		var d := hw * maxf(depth_frac, width_frac * 0.5)
		var origin := Vector3(cos(angle) * hw * 0.12, 0.0, sin(angle) * hw * 0.12)
		var tip := origin + Vector3(cos(angle) * hw * 0.08, h, sin(angle) * hw * 0.08)
		var side := Vector3(-sin(angle), 0.0, cos(angle))
		_blade(st, origin, tip, side, w, d, 1.0, 0.0)


## Hoja en V real (2 caras que se encuentran en un filo desplazado hacia adelante, nunca un
## plano): base en `base` (ancho `half_width` a cada lado), punta en `tip`. `side` es el eje
## perpendicular a lo largo del cual se abre la hoja; el filo se desplaza `depth` hacia la
## cámara media (eje vertical) para que la V tenga volumen real desde cualquier ángulo.
static func _blade(st: SurfaceTool, base: Vector3, tip: Vector3, side: Vector3, half_width: float, depth: float, v_base: float, v_tip: float) -> void:
	var up := (tip - base)
	var forward := up.cross(side).normalized() if up.length() > 0.001 else Vector3.FORWARD
	var base_left := base + side * half_width
	var base_right := base - side * half_width
	var ridge_base := base + forward * depth
	var ridge_tip := tip + forward * depth * 0.3
	_tri(st, base_left, ridge_base, ridge_tip, Vector2(0.0, v_base), Vector2(0.5, v_base), Vector2(0.5, v_tip))
	_tri(st, ridge_base, base_right, ridge_tip, Vector2(0.5, v_base), Vector2(1.0, v_base), Vector2(0.5, v_tip))


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


## Malla y material de un objeto de decoración (follaje 3D de verdad, roca, tronco, hueso,
## concha o cerca real) según PropArt.kind_of(texture); por defecto (texturas que no vienen
## de PropArt, como los arbustos y plantas .tres de BiomeConfig) es un montículo genérico
## ("bush", ver foliage_mesh). Lo usan world_builder.gd (decoración del campo abierto) y
## structures.gd (junto a los edificios y las plazas con identidad de pueblo). El material se
## aplica con material_override (la malla base queda compartida y sin tocar, para no gastar
## memoria con miles de instancias).
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
	var mesh := foliage_mesh(texture, pixel_size)
	return {"mesh": mesh, "material": FoliageMaterials.for_texture(texture, tint, seasonal, glow)}


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
