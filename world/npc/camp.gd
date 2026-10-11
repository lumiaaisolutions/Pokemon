class_name Camp
extends Node3D
## Campamento (de un viajero o tuyo; acordado con Fernando el 2026-10-10). En 3D de pocos
## polígonos con texturas pixel art como las de B2W2 (pedido de Fernando: "que no parezca
## papel al dar la vuelta o ver la fogata"): tienda de lona con postes, cuerdas y estacas;
## fogata con anillo de piedras, troncos en tipi, brasas y llamas en planos cruzados que se
## ven desde cualquier lado; tronco para sentarse y mochila; la tuya, además, con olla.
## Al anochecer el viajero la arma (la tienda se levanta con rebote y enciende el fuego) y
## al amanecer la recoge (apaga el fuego con humo y la tienda se pliega).

const TENT_COLORS := [Color(0.3, 0.62, 0.38), Color(0.32, 0.5, 0.82), Color(0.9, 0.55, 0.25), Color(0.75, 0.35, 0.4)]
## Colores festivos de la tienda mejorada (CampManager.upgrade_camp, extras 2026-10-10 ronda 3).
const UPGRADE_COLORS := [Color(0.85, 0.65, 0.15), Color(0.8, 0.2, 0.45)]
## Dónde está la fogata respecto a la tienda.
const FIRE_OFFSET := Vector3(-2.2, 0, 1.4)

## Armándose o recogiéndose (el viajero espera).
var busy := false
var _tent: Node3D
var _fire: Node3D
var _flames: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _extras: Node3D
var _time := 0.0
var _lit := false
## Mejora del campamento (extras, 2026-10-10, ronda 3): 0 normal, 1 tienda grande y de
## color festivo con mesa, 2 además baúl. Solo la tuya se mejora (ver CampManager).
var level := 0
var _fireflies: Array[Sprite3D] = []
var _upgrade_extras: Node3D


static func create(parent: Node, at: Vector3, color_index: int, with_pot: bool = false) -> Camp:
	var camp := Camp.new()
	camp.name = "Camp"
	parent.add_child(camp)
	camp.global_position = at
	camp._build(color_index, with_pot)
	return camp


func _build(color_index: int, with_pot: bool) -> void:
	_tent = tent_model(TENT_COLORS[absi(color_index) % TENT_COLORS.size()])
	_tent.scale = Vector3(1, 0.02, 1)
	add_child(_tent)
	_fire = firepit(with_pot)
	_fire.position = FIRE_OFFSET
	_fire.scale = Vector3.ONE * 0.01
	add_child(_fire)
	for node in _fire.find_children("Flame*", "MeshInstance3D", true, false):
		_flames.append(node as MeshInstance3D)
		(node as MeshInstance3D).visible = false
	_extras = Node3D.new()
	_extras.position = FIRE_OFFSET
	_extras.scale = Vector3.ONE * 0.01
	add_child(_extras)
	_extras.add_child(_seat_log(Vector3(-1.3, 0, 0.3), 0.5))
	_extras.add_child(_backpack(Vector3(1.1, 0, -1.6)))
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.omni_range = 7.0
	_light.light_energy = 0.0
	_light.position = FIRE_OFFSET + Vector3(0, 0.9, 0)
	add_child(_light)
	_upgrade_extras = Node3D.new()
	_upgrade_extras.name = "UpgradeExtras"
	add_child(_upgrade_extras)
	# Luciérnagas de noche junto al campamento (extras, 2026-10-10 ronda 3): puntitos
	# luminosos que suben y bajan despacio; solo se ven de noche.
	for k in 5:
		var firefly := Sprite3D.new()
		firefly.texture = _firefly_texture()
		firefly.pixel_size = 0.01
		firefly.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		firefly.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		firefly.modulate = Color(1.0, 1.0, 0.75, 0.0)
		firefly.position = Vector3(randf_range(-2.0, 2.0), randf_range(0.6, 1.8), randf_range(-2.0, 2.0))
		firefly.set_meta("seed", randf() * TAU)
		add_child(firefly)
		_fireflies.append(firefly)


## Arma el campamento; actor (el sprite del viajero) se agacha mientras tanto.
func pitch(actor: Node3D = null) -> void:
	busy = true
	var tween := create_tween()
	if actor != null:
		tween.tween_property(actor, "scale", Vector3(1.1, 0.8, 1.0), 0.25)
	tween.tween_property(_fire, "scale", Vector3.ONE, 0.3)
	tween.parallel().tween_property(_extras, "scale", Vector3.ONE, 0.3)
	tween.tween_callback(func() -> void: PixelBurst.spawn(get_parent(), global_position + Vector3.UP * 0.3, PixelBurst.Kind.DUST, 0.6))
	tween.tween_property(_tent, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_set_lit(true)
		PixelBurst.spawn(get_parent(), global_position + FIRE_OFFSET + Vector3(0, 0.3, 0), PixelBurst.Kind.SPARK, 1.1))
	tween.tween_property(_light, "light_energy", 1.5, 0.5)
	if actor != null:
		tween.parallel().tween_property(actor, "scale", Vector3.ONE, 0.25)
	tween.tween_callback(func() -> void: busy = false)


## Deja el campamento armado y la fogata prendida sin animación (al cargar la partida
## con tiendas de campaña guardadas; ver CampManager).
func set_lit_instant() -> void:
	_tent.scale = Vector3.ONE
	_fire.scale = Vector3.ONE
	_extras.scale = Vector3.ONE
	_set_lit(true)
	_light.light_energy = 1.5


func _set_lit(on: bool) -> void:
	_lit = on
	for flame in _flames:
		flame.visible = on


## Recoge el campamento (la fogata se apaga con humo, la tienda se dobla y "entra a la
## mochila": se achica y se acerca a actor antes de borrarse) y se borra al terminar.
func pack(actor: Node3D = null) -> void:
	busy = true
	var tween := create_tween()
	if actor != null:
		tween.tween_property(actor, "scale", Vector3(1.1, 0.8, 1.0), 0.25)
	tween.tween_callback(func() -> void:
		_set_lit(false)
		PixelBurst.spawn(get_parent(), global_position + FIRE_OFFSET + Vector3(0, 0.4, 0), PixelBurst.Kind.SMOKE, 0.7))
	tween.tween_property(_light, "light_energy", 0.0, 0.3)
	tween.tween_property(_tent, "scale", Vector3(1, 0.02, 1), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_fire, "scale", Vector3.ONE * 0.01, 0.3)
	tween.parallel().tween_property(_extras, "scale", Vector3.ONE * 0.01, 0.3)
	if actor != null:
		tween.tween_property(actor, "scale", Vector3.ONE, 0.2)
		# La tienda doblada vuela hacia la mochila (actor) y se encoge del todo.
		tween.tween_property(_tent, "global_position", actor.global_position + Vector3(0, 0.9, 0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(_tent, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(func() -> void:
		busy = false
		queue_free())


## Mejora el campamento (solo el tuyo; con materiales, ver CampManager.upgrade_camp):
## nivel 1 agranda la tienda y le cambia el color por uno festivo y pone una mesa; nivel 2
## además añade un baúl junto a la mochila (de momento decorativo: guardar ahí de verdad
## queda para cuando Fernando lo pida). "Cocina más rápido" es, por ahora, de palabra en
## el aviso al mejorar: cocinar ya es instantáneo y no hay todavía un tiempo que acortar.
func upgrade(new_level: int) -> void:
	level = new_level
	for child in _upgrade_extras.get_children():
		child.queue_free()
	if level <= 0:
		return
	var tween := create_tween()
	tween.tween_property(_tent, "scale", Vector3.ONE * (1.0 + level * 0.12), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Tienda de colores festivos al mejorar.
	var canvas := _tent.get_node_or_null("Canvas") as MeshInstance3D
	if canvas != null:
		canvas.material_override = _material(_canvas_texture(UPGRADE_COLORS[mini(level - 1, UPGRADE_COLORS.size() - 1)]), Vector3(2, 2, 1))
	if level >= 1:
		_upgrade_extras.add_child(_table(Vector3(0.9, 0, 1.0)))
	if level >= 2:
		_upgrade_extras.add_child(_chest(Vector3(1.4, 0, -1.3)))
	PixelBurst.spawn(get_parent(), global_position + Vector3.UP * 0.5, PixelBurst.Kind.SPARK, 1.2)


## Pequeña mesa de madera (mejora del campamento).
static func _table(at: Vector3) -> Node3D:
	var table := Node3D.new()
	table.position = at
	var wood := _material(_bark_texture(), Vector3(1, 1, 1))
	table.add_child(_box(Vector3(0.9, 0.06, 0.6), Vector3(0, 0.55, 0), wood))
	for sx in [-0.38, 0.38]:
		for sz in [-0.24, 0.24]:
			table.add_child(_box(Vector3(0.07, 0.55, 0.07), Vector3(sx, 0.27, sz), wood))
	return table


## Baúl (mejora del campamento, nivel 2); de momento decorativo.
static func _chest(at: Vector3) -> Node3D:
	var chest := Node3D.new()
	chest.position = at
	var wood := _material(_bark_texture(), Vector3(1, 1, 1))
	var metal := _material(_metal_texture(), Vector3(1, 1, 1))
	chest.add_child(_box(Vector3(0.6, 0.38, 0.4), Vector3(0, 0.19, 0), wood))
	chest.add_child(_box(Vector3(0.64, 0.1, 0.44), Vector3(0, 0.43, 0), metal))
	chest.add_child(_box(Vector3(0.06, 0.1, 0.06), Vector3(0, 0.3, 0.22), metal))
	return chest


## Cocinar en la fogata (pedido de Fernando el 2026-10-10, ronda 3): vapor y burbujas
## sobre la olla, tu compañero mira con corazón y el platillo aparece en un plato sobre
## el tronco. Se llama al cerrar el menú de cocina si se cocinó algo (ver CookingUI).
func cook_flourish(companion: Node3D, dish_icon: Texture2D) -> void:
	var pot_top := global_position + FIRE_OFFSET + Vector3(0, 1.3, 0)
	var tween := create_tween()
	for i in 3:
		tween.tween_callback(func() -> void:
			PixelBurst.spawn(get_parent(), pot_top, PixelBurst.Kind.SMOKE, 0.5)
			PixelBurst.spawn(get_parent(), pot_top, PixelBurst.Kind.BUBBLES, 0.4))
		tween.tween_interval(0.4)
	if companion != null and is_instance_valid(companion):
		tween.tween_callback(func() -> void: SpeechBubbles.say(companion, "♥", 1.8))
	tween.tween_callback(_show_dish.bind(dish_icon))


## Plato con el platillo recién cocinado, sobre el tronco de sentarse; se desvanece solo.
func _show_dish(icon: Texture2D) -> void:
	if icon == null:
		return
	var plate := Sprite3D.new()
	plate.texture = icon
	plate.pixel_size = 0.012
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	plate.position = FIRE_OFFSET + Vector3(-1.3, 0.55, 0.3)
	add_child(plate)
	var tween := create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(plate, "modulate:a", 0.0, 0.6)
	tween.tween_callback(plate.queue_free)


static var _firefly_tex: Texture2D


## Puntito de luz amarillo-verde (luciérnaga de noche junto al campamento).
static func _firefly_texture() -> Texture2D:
	if _firefly_tex != null:
		return _firefly_tex
	var image := Image.create_empty(6, 6, false, Image.FORMAT_RGBA8)
	for y in 6:
		for x in 6:
			if Vector2(x - 2.5, y - 2.5).length() <= 2.2:
				image.set_pixel(x, y, Color(0.85, 1.0, 0.5))
	_firefly_tex = ImageTexture.create_from_image(image)
	return _firefly_tex


func _process(delta: float) -> void:
	_time += delta
	var night := GameState.is_night()
	for firefly in _fireflies:
		var phase: float = firefly.get_meta("seed")
		var target_alpha := 0.85 if night else 0.0
		firefly.modulate.a = move_toward(firefly.modulate.a, target_alpha, delta * 0.6)
		if firefly.modulate.a > 0.01:
			firefly.position.y += sin(_time * 1.4 + phase) * 0.003
			firefly.position.x += cos(_time * 0.9 + phase) * 0.002
	if not _lit:
		return
	var frame := int(_time * 8.0) % 3
	for k in _flames.size():
		var flame := _flames[k]
		(flame.material_override as StandardMaterial3D).albedo_texture = _flame_texture((frame + k) % 3)
		flame.scale.y = 1.0 + sin(_time * 11.0 + k) * 0.08
	_light.light_energy = 1.4 + sin(_time * 13.0) * 0.12 + sin(_time * 7.0) * 0.08


# --- Modelos 3D (también los usa el campamento abandonado de los puntos de interés) ---------

## Tienda de lona: prisma triangular con costuras, puerta oscura, postes, cuerdas y estacas.
static func tent_model(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Tent"
	var w := 2.4
	var d := 2.8
	var h := 1.9
	var canvas := _material(_canvas_texture(color), Vector3(2, 2, 1))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-w * 0.5, 0, -d * 0.5)
	var b := Vector3(w * 0.5, 0, -d * 0.5)
	var c := Vector3(0, h, -d * 0.5)
	var a2 := Vector3(-w * 0.5, 0, d * 0.5)
	var b2 := Vector3(w * 0.5, 0, d * 0.5)
	var c2 := Vector3(0, h, d * 0.5)
	# Laderas izquierda y derecha.
	_quad(st, a, a2, c2, c)
	_quad(st, b2, b, c, c2)
	# Pared de atrás.
	_tri(st, b, a, c, Vector2(1, 1), Vector2(0, 1), Vector2(0.5, 0))
	# Frente: lona a los lados de la puerta.
	var door_w := w * 0.42
	var door_h := h * 0.72
	_tri(st, a2, Vector3(-door_w * 0.5, 0, d * 0.5), Vector3(-door_w * 0.12, door_h, d * 0.5), Vector2(0, 1), Vector2(0.3, 1), Vector2(0.45, 0.25))
	_tri(st, a2, Vector3(-door_w * 0.12, door_h, d * 0.5), c2, Vector2(0, 1), Vector2(0.45, 0.25), Vector2(0.5, 0))
	_tri(st, Vector3(door_w * 0.5, 0, d * 0.5), b2, Vector3(door_w * 0.12, door_h, d * 0.5), Vector2(0.7, 1), Vector2(1, 1), Vector2(0.55, 0.25))
	_tri(st, Vector3(door_w * 0.12, door_h, d * 0.5), b2, c2, Vector2(0.55, 0.25), Vector2(1, 1), Vector2(0.5, 0))
	_tri(st, Vector3(-door_w * 0.12, door_h, d * 0.5), Vector3(door_w * 0.12, door_h, d * 0.5), c2, Vector2(0.45, 0.25), Vector2(0.55, 0.25), Vector2(0.5, 0))
	st.generate_normals()
	var shell := MeshInstance3D.new()
	shell.name = "Canvas"
	shell.mesh = st.commit()
	shell.material_override = canvas
	root.add_child(shell)
	# Interior oscuro detrás de la puerta.
	var inner := MeshInstance3D.new()
	var inner_st := SurfaceTool.new()
	inner_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tri(inner_st, Vector3(-door_w * 0.5, 0.01, d * 0.5 - 0.05), Vector3(door_w * 0.5, 0.01, d * 0.5 - 0.05), Vector3(0, door_h + 0.1, d * 0.5 - 0.05), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	inner.mesh = inner_st.commit()
	inner.material_override = _flat(Color(0.12, 0.1, 0.12))
	root.add_child(inner)
	# Postes y cumbrera de madera.
	var wood := _material(_bark_texture(), Vector3(1, 1, 1))
	for z in [-d * 0.5 - 0.05, d * 0.5 + 0.05]:
		root.add_child(_box(Vector3(0.09, h + 0.25, 0.09), Vector3(0, (h + 0.25) * 0.5, z), wood))
	root.add_child(_box(Vector3(0.07, 0.07, d + 0.3), Vector3(0, h + 0.02, 0), wood))
	# Cuerdas y estacas.
	var rope := _flat(Color(0.85, 0.8, 0.65))
	for side in [-1.0, 1.0]:
		for z in [-d * 0.5, d * 0.5]:
			var top := Vector3(0, h, z * 1.02)
			var stake := Vector3(side * (w * 0.5 + 0.9), 0.05, z * 1.25)
			root.add_child(_stick(top, stake, 0.025, rope))
			root.add_child(_box(Vector3(0.07, 0.25, 0.07), stake + Vector3(0, 0.08, 0), wood))
	# Colisión: no se atraviesa.
	var body := StaticBody3D.new()
	body.collision_layer = WorldBuilder.LAYER_OBSTACLES
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w * 0.8, h * 0.7, d)
	shape.shape = box
	shape.position.y = h * 0.35
	body.add_child(shape)
	root.add_child(body)
	return root


## Fogata: anillo de piedras, troncos en tipi, brasas y tres llamas cruzadas; con olla y
## trípode si with_pot (la tuya, para cocinar).
static func firepit(with_pot: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "Firepit"
	var stone := _material(_stone_texture(), Vector3(1, 1, 1))
	for k in 9:
		var angle := TAU * k / 9.0
		var rock := _box(Vector3(0.32, 0.2, 0.26), Vector3(cos(angle) * 0.62, 0.1, sin(angle) * 0.62), stone)
		rock.rotation.y = -angle
		root.add_child(rock)
	var wood := _material(_bark_texture(), Vector3(1, 1, 1))
	for k in 4:
		var angle := TAU * k / 4.0 + 0.4
		root.add_child(_stick(Vector3(cos(angle) * 0.45, 0.02, sin(angle) * 0.45), Vector3(0, 0.62, 0), 0.07, wood))
	var embers := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.38
	disc.bottom_radius = 0.42
	disc.height = 0.06
	disc.radial_segments = 8
	embers.mesh = disc
	embers.material_override = _flat(Color(0.95, 0.35, 0.1), 1.6)
	embers.position.y = 0.03
	root.add_child(embers)
	# Llamas: tres planos cruzados (0°, 60°, 120°): se ven igual desde cualquier lado.
	for k in 3:
		var flame := MeshInstance3D.new()
		flame.name = "Flame%d" % k
		var quad := QuadMesh.new()
		quad.size = Vector2(0.75, 1.0)
		quad.center_offset = Vector3(0, 0.5, 0)
		flame.mesh = quad
		var material := StandardMaterial3D.new()
		material.albedo_texture = _flame_texture(k)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		flame.material_override = material
		flame.rotation.y = PI * k / 3.0
		flame.position.y = 0.08
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(flame)
	if with_pot:
		var metal := _material(_metal_texture(), Vector3(1, 1, 1))
		for k in 3:
			var angle := TAU * k / 3.0
			root.add_child(_stick(Vector3(cos(angle) * 0.75, 0.0, sin(angle) * 0.75), Vector3(0, 1.45, 0), 0.03, metal))
		var pot := MeshInstance3D.new()
		var body := CylinderMesh.new()
		body.top_radius = 0.3
		body.bottom_radius = 0.24
		body.height = 0.38
		body.radial_segments = 10
		pot.mesh = body
		pot.material_override = metal
		pot.position.y = 0.95
		root.add_child(pot)
		var lid := MeshInstance3D.new()
		var cap := CylinderMesh.new()
		cap.top_radius = 0.12
		cap.bottom_radius = 0.31
		cap.height = 0.1
		cap.radial_segments = 10
		lid.mesh = cap
		lid.material_override = metal
		lid.position.y = 1.19
		root.add_child(lid)
		root.add_child(_stick(Vector3(0, 1.45, 0), Vector3(0, 1.2, 0), 0.015, metal))
	return root


static func _seat_log(at: Vector3, angle: float) -> Node3D:
	var log := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.2
	mesh.bottom_radius = 0.2
	mesh.height = 1.3
	mesh.radial_segments = 8
	log.mesh = mesh
	log.material_override = _material(_bark_texture(), Vector3(1, 1, 1))
	log.rotation = Vector3(0, angle, PI * 0.5)
	log.position = at + Vector3(0, 0.2, 0)
	return log


static func _backpack(at: Vector3) -> Node3D:
	var pack := Node3D.new()
	pack.position = at
	var fabric := _material(_canvas_texture(Color(0.75, 0.3, 0.25)), Vector3(1, 1, 1))
	pack.add_child(_box(Vector3(0.45, 0.55, 0.3), Vector3(0, 0.28, 0), fabric))
	pack.add_child(_box(Vector3(0.47, 0.18, 0.32), Vector3(0, 0.58, 0.01), _material(_canvas_texture(Color(0.6, 0.22, 0.2)), Vector3(1, 1, 1))))
	pack.add_child(_box(Vector3(0.5, 0.12, 0.12), Vector3(0, 0.05, 0.22), _flat(Color(0.35, 0.55, 0.3))))
	pack.rotation.y = 0.5
	return pack


# --- Ayudas de malla -----------------------------------------------------------------------

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0))
	_tri(st, a, c, d, Vector2(0, 1), Vector2(1, 0), Vector2(0, 0))


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)


static func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	return mesh


## Palo (cilindro de 5 lados) de from a to.
static func _stick(from: Vector3, to: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = from.distance_to(to)
	cylinder.radial_segments = 5
	cylinder.rings = 1
	mesh.mesh = cylinder
	mesh.material_override = material
	var mid := (from + to) * 0.5
	var dir := (to - from).normalized()
	var basis := Basis()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 0.0001:
		basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	mesh.transform = Transform3D(basis, mid)
	return mesh


static func _material(texture: Texture2D, uv_scale: Vector3) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.uv1_scale = uv_scale
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func _flat(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


# --- Texturas pixel art ---------------------------------------------------------------------

static var _textures := {}


## Lona: color con costuras claras y sombra en los bordes.
static func _canvas_texture(color: Color) -> Texture2D:
	var key := "canvas:" + color.to_html()
	if _textures.has(key):
		return _textures[key]
	var image := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var c := color
			if x % 8 == 0:
				c = color.lightened(0.18)
			elif (x + y * 3) % 11 == 0:
				c = color.darkened(0.08)
			if y == 15 or y == 0:
				c = color.darkened(0.25)
			image.set_pixel(x, y, c)
	_textures[key] = ImageTexture.create_from_image(image)
	return _textures[key]


static func _bark_texture() -> Texture2D:
	if _textures.has("bark"):
		return _textures["bark"]
	var image := Image.create_empty(8, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 8:
			var c := Color(0.45, 0.29, 0.17)
			if x % 3 == 0:
				c = Color(0.32, 0.2, 0.11)
			elif (x + y) % 7 == 0:
				c = Color(0.55, 0.37, 0.22)
			image.set_pixel(x, y, c)
	_textures["bark"] = ImageTexture.create_from_image(image)
	return _textures["bark"]


static func _stone_texture() -> Texture2D:
	if _textures.has("stone"):
		return _textures["stone"]
	var image := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var shade := 0.55 + ((x * 3 + y * 5) % 7) * 0.025
			image.set_pixel(x, y, Color(shade, shade, shade + 0.03))
	_textures["stone"] = ImageTexture.create_from_image(image)
	return _textures["stone"]


static func _metal_texture() -> Texture2D:
	if _textures.has("metal"):
		return _textures["metal"]
	var image := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			image.set_pixel(x, y, Color(0.25, 0.25, 0.3) if y > 1 else Color(0.45, 0.45, 0.52))
	_textures["metal"] = ImageTexture.create_from_image(image)
	return _textures["metal"]


static var _flame_cache := {}


static func _flame_texture(frame: int) -> Texture2D:
	if _flame_cache.has(frame):
		return _flame_cache[frame]
	var image := Image.create_empty(12, 16, false, Image.FORMAT_RGBA8)
	var sway: int = [0, 1, -1][frame]
	for y in 16:
		var t := float(y) / 15.0
		var half := int(lerpf(1.0, 5.5, t))
		var cx := 6 + int(round(sway * (1.0 - t)))
		for x in range(cx - half, cx + half):
			if x < 0 or x >= 12:
				continue
			var inner := absi(x - cx) < half * 0.5 and y > 5
			image.set_pixel(x, y, Color(1.0, 0.95, 0.55) if inner else (Color(1.0, 0.55, 0.15) if y > 3 else Color(0.95, 0.3, 0.1)))
	_flame_cache[frame] = ImageTexture.create_from_image(image)
	return _flame_cache[frame]
