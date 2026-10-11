class_name MoveFx
extends Node3D
## Animaciones de los ataques por familia (pedido de Fernando, 2026-10-10; ver
## docs/sistemas/animaciones_ataques.md y MoveFamilies). Pixel art como el mundo. Cada
## animación llama a `hit` en el momento del impacto (el daño lo calcula PokemonActor) y
## agrega los extras de los ataques fuertes: temblor de cámara, destello del golpeado y
## una marca en el suelo que dura unos segundos.

const PIXEL := 0.057
## Distancia a la que un ataque cuerpo a cuerpo alcanza (como PokemonActor.MELEE_RANGE).
const MELEE_REACH := 2.4
const MARK_SECONDS := 5.0

var attacker: PokemonActor
var target: Node3D
var move_id := ""
var hit: Callable
var _rng := RandomNumberGenerator.new()


## Reproduce la animación del ataque si tiene familia; devuelve false si no (el atacante
## usa entonces la animación de siempre).
static func play(by: PokemonActor, to: Node3D, id: String, on_hit: Callable) -> bool:
	var family := MoveFamilies.family(id)
	if family == "" or by == null or not is_instance_valid(by):
		return false
	var fx := MoveFx.new()
	fx.attacker = by
	fx.target = to
	fx.move_id = id
	fx.hit = on_hit
	by.get_parent().add_child(fx)
	fx.global_position = by.global_position
	fx._rng.randomize()
	match family:
		"burrow":
			fx._burrow(String(MoveFamilies.BURROW[id]))
		"shaped":
			fx._shaped(MoveFamilies.SHAPED[id])
		"stream":
			fx._stream(MoveFamilies.STREAM[id])
		"vines":
			fx._vines()
		"bite":
			fx._bite(String(MoveFamilies.BITES[id]))
		"beam":
			fx._beam(MoveFamilies.BEAMS[id])
		"bolt":
			fx._bolt(bool(MoveFamilies.BOLTS[id]))
		"melee":
			fx._melee(MoveFamilies.MELEE[id])
		"sky":
			fx._sky(MoveFamilies.SKY[id])
		"ground":
			fx._ground_attack(String(MoveFamilies.GROUND[id]))
		"gust":
			fx._gust(MoveFamilies.GUSTS[id])
		"twister":
			fx._twister()
	return true


# --- Ayudas ----------------------------------------------------------------------------

## Sin tipo: un nodo ya liberado no puede pasarse a un parámetro tipado.
func _alive(node: Variant) -> bool:
	return is_instance_valid(node) and not (node as Node).is_queued_for_deletion()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _sprite(texture: Texture2D, pixel_size: float = PIXEL) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = pixel_size
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.layers = 2
	add_child(sprite)
	return sprite


## Centro del cuerpo visible (mitad de la altura de su sprite).
func _center(node: Node3D) -> Vector3:
	var size := (node as PokemonActor).species.size_scale if node is PokemonActor else 1.0
	return node.global_position + Vector3.UP * PokemonActor.PIXEL_SIZE * 32.0 * size * 0.42


func _ground(at: Vector3) -> Vector3:
	var world := get_tree().get_first_node_in_group(WorldBuilder.WORLD_GROUP) as WorldBuilder
	if world == null:
		return at
	return Vector3(at.x, world.surface_height_at(at.x, at.z), at.z)


func _attacker_sprite() -> Sprite3D:
	return attacker.get("_sprite") as Sprite3D if _alive(attacker) else null


## Golpe: daño (si el rival sigue ahí) y extras de impacto.
func _strike(mark: String = "") -> bool:
	if not hit.is_valid() or not _alive(target):
		return false
	var landed: bool = hit.call(target)
	if landed:
		_impact(mark)
	return landed


## Extras al pegar (decisión de Fernando: los 3 en ataques fuertes): destello del golpeado,
## temblor de cámara y marca en el suelo.
func _impact(mark: String) -> void:
	var strong := MoveFamilies.strong(move_id)
	var sprite := target.get("_sprite") as Sprite3D if _alive(target) else null
	if sprite != null:
		var tween := sprite.create_tween()
		tween.tween_method(func(v: float) -> void: sprite.set_instance_shader_parameter("flash", v), 0.9 if strong else 0.55, 0.0, 0.25)
	if strong:
		var rig := get_tree().get_first_node_in_group(CameraRig.CAMERA_GROUP) as CameraRig
		if rig != null and attacker.player != null and attacker.global_position.distance_to(attacker.player.global_position) < 35.0:
			rig.shake(0.7)
		if mark != "" and _alive(target):
			_ground_mark(mark, target.global_position)


func _ground_mark(kind: String, at: Vector3) -> void:
	var color := MoveFamilies.color_of(move_id, "")
	var decal := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 2.4) if kind != "puddle" else Vector2(2.6, 1.7)
	decal.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = PixelShapes.get_texture(kind, color)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	decal.material_override = material
	decal.rotation.x = -PI * 0.5
	decal.rotation.z = _rng.randf() * TAU
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(decal)
	decal.global_position = _ground(at) + Vector3.UP * 0.04
	var tween := decal.create_tween()
	tween.tween_interval(MARK_SECONDS)
	tween.tween_property(material, "albedo_color:a", 0.0, 1.5)
	tween.tween_callback(decal.queue_free)


# --- Familias ----------------------------------------------------------------------------

## Excavar, Buceo, Vuelo, Bote, Golpe Fantasma: se oculta, avanza oculto y sale bajo el rival.
func _burrow(mode: String) -> void:
	var sprite := _attacker_sprite()
	if sprite == null:
		queue_free()
		return
	var shadow := attacker.get_node_or_null("BlobShadow") as Decal
	var start := attacker.global_position
	attacker.set_physics_process(false)
	match mode:
		"ground":
			PixelBurst.spawn(get_parent(), start + Vector3.UP * 0.3, PixelBurst.Kind.DUST, 1.0)
		"water":
			PixelBurst.spawn(get_parent(), start + Vector3.UP * 0.3, PixelBurst.Kind.SPLASH, 1.0)
		"vanish":
			PixelBurst.spawn(get_parent(), start + Vector3.UP * 0.6, PixelBurst.Kind.SMOKE, 0.8)
	# Vuelo/Bote: sube rápido hasta salir de la vista; los demás se esconden.
	if mode == "sky":
		var up := sprite.create_tween()
		up.tween_property(sprite, "position:y", 14.0, 0.35).set_ease(Tween.EASE_IN)
		await up.finished
	sprite.visible = false
	if shadow != null:
		shadow.visible = mode == "sky"
	# Lo que avanza hacia el rival: montículo de tierra, burbujas, sombra o nada.
	var marker: Sprite3D = null
	if mode == "ground":
		marker = _sprite(PixelShapes.get_texture("mound"), 0.07)
	elif mode == "water":
		marker = _sprite(PixelShapes.get_texture("orb", Color(0.7, 0.9, 1.0)), 0.04)
	var travel := 0.0
	var duration := 0.9
	var from := start
	while travel < duration:
		await get_tree().process_frame
		if not _alive(attacker):
			queue_free()
			return
		travel += get_process_delta_time()
		var goal := target.global_position if _alive(target) else from
		var at := from.lerp(goal, clampf(travel / duration, 0.0, 1.0))
		attacker.global_position = at
		if marker != null:
			marker.global_position = _ground(at) + Vector3.UP * 0.25
			if Engine.get_process_frames() % 8 == 0 and mode == "ground":
				PixelBurst.spawn(get_parent(), _ground(at) + Vector3.UP * 0.2, PixelBurst.Kind.DUST, 0.35)
	if marker != null:
		marker.queue_free()
	# Sale bajo el rival (o cae del cielo) y lo golpea.
	var end := attacker.global_position
	sprite.visible = true
	if shadow != null:
		shadow.visible = true
	match mode:
		"ground":
			PixelBurst.spawn(get_parent(), _ground(end) + Vector3.UP * 0.3, PixelBurst.Kind.ROCK, 1.2)
			sprite.position.y = -1.2
			var pop := sprite.create_tween()
			pop.tween_property(sprite, "position:y", 1.4, 0.15).set_ease(Tween.EASE_OUT)
			pop.tween_property(sprite, "position:y", 0.0, 0.25).set_ease(Tween.EASE_IN)
			_strike("crack")
		"water":
			PixelBurst.spawn(get_parent(), end + Vector3.UP * 0.3, PixelBurst.Kind.SPLASH, 1.4)
			_strike("puddle")
		"sky":
			var down := sprite.create_tween()
			down.tween_property(sprite, "position:y", 0.0, 0.22).set_ease(Tween.EASE_IN)
			await down.finished
			PixelBurst.spawn(get_parent(), _ground(end) + Vector3.UP * 0.2, PixelBurst.Kind.DUST, 1.0)
			_strike("crack")
		"vanish":
			PixelBurst.spawn(get_parent(), end + Vector3.UP * 0.6, PixelBurst.Kind.SMOKE, 1.0)
			_strike()
	await _wait(0.45)
	if _alive(attacker):
		sprite.position.y = 0.0
		attacker.set_physics_process(true)
	queue_free()


## Proyectiles con forma (Shuriken de Agua ×3 girando, estrella de Llamarada…).
func _shaped(data: Array) -> void:
	var shape: String = data[0]
	var count: int = data[1]
	var pixel_size: float = data[2]
	var speed: float = data[3]
	var color := MoveFamilies.color_of(move_id, data[4])
	var frames: Array[Texture2D] = []
	if shape == "shuriken":
		for f in 4:
			frames.append(PixelShapes.get_texture("shuriken", color, f))
	else:
		frames.append(PixelShapes.get_texture(shape, color))
	for i in count:
		if not _alive(attacker):
			break
		var origin := _center(attacker)
		var to := _center(target) if _alive(target) else origin + (attacker.get("_sprite") as DirectionalSprite).facing_world * PokemonActor.RANGED_MAX
		var targets: Array[Node3D] = []
		if _alive(target):
			targets.append(target)
		var projectile := AttackProjectile.launch(get_parent(), origin, to, int(Moves.get_move(move_id)["type"]), attacker, targets, hit)
		projectile.set_look(frames, pixel_size)
		projectile.speed = speed
		var mark := "scorch" if shape == "fire_star" else ("puddle" if shape == "shuriken" else "")
		projectile.on_impact = func(at: Vector3) -> void: _projectile_impact(at, shape, mark)
		if shape == "fire_star":
			# La estrella crece al salir, como en los juegos.
			projectile.scale = Vector3.ONE * 0.4
			projectile.create_tween().tween_property(projectile, "scale", Vector3.ONE * 1.3, 0.35)
		await _wait(0.18)
	await _wait(2.0)
	queue_free()


func _projectile_impact(at: Vector3, shape: String, mark: String) -> void:
	match shape:
		"fire_star":
			for k in 3:
				PixelBurst.spawn(get_parent(), at + Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.3, 0.5), 0), PixelBurst.Kind.SMOKE, 1.0)
		"shuriken":
			PixelBurst.spawn(get_parent(), at, PixelBurst.Kind.SPLASH, 0.8)
		_:
			PixelBurst.spawn(get_parent(), at, PixelBurst.Kind.DUST, 0.7)
	if is_inside_tree() and _alive(target):
		_impact(mark)


## Chorros (Lanzallamas, Hidrobomba, Pistola Agua…): gotas que salen seguidas del
## atacante al rival durante un rato; el golpe cuenta cuando llega la primera.
func _stream(data: Array) -> void:
	var shape: String = data[0]
	var color := MoveFamilies.color_of(move_id, data[1])
	var duration: float = data[2]
	var texture := PixelShapes.get_texture(shape, color)
	var landed := false
	var elapsed := 0.0
	var drops: Array[Dictionary] = []
	var spawn_timer := 0.0
	while elapsed < duration + 0.6:
		await get_tree().process_frame
		var delta := get_process_delta_time()
		elapsed += delta
		if not _alive(attacker):
			break
		var origin := _center(attacker)
		var goal := _center(target) if _alive(target) else origin + (attacker.get("_sprite") as DirectionalSprite).facing_world * 6.0
		spawn_timer -= delta
		if elapsed < duration:
			while spawn_timer <= 0.0:
				spawn_timer += 0.012
				var drop := _sprite(texture, (0.075 if shape == "flame" else 0.06) * _rng.randf_range(0.8, 1.2))
				drop.global_position = origin
				drops.append({"node": drop, "t": _rng.randf_range(0.0, 0.05), "wobble": Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.25, 0.35), _rng.randf_range(-0.35, 0.35))})
		for d in drops.duplicate():
			var node: Sprite3D = d["node"]
			d["t"] = float(d["t"]) + delta * 2.6
			var t: float = d["t"]
			node.global_position = origin.lerp(goal, minf(t, 1.0)) + (d["wobble"] as Vector3) * t * 1.6
			# Las llamas crecen y se abren hacia el final del chorro.
			node.scale = Vector3.ONE * (0.5 + t * 1.3)
			if t >= 1.0:
				if not landed:
					landed = true
					_strike("scorch" if shape == "flame" else ("puddle" if shape == "drop" else ""))
				drops.erase(d)
				node.queue_free()
	for d in drops:
		(d["node"] as Node).queue_free()
	queue_free()


## Látigo Cepa y Latigazo: dos lianas salen del atacante, se estiran y azotan al rival.
func _vines() -> void:
	if not _alive(target) or attacker.global_position.distance_to(target.global_position) > PokemonActor.RANGED_MAX:
		queue_free()
		return
	var texture := PixelShapes.get_texture("vine")
	var vines: Array = []
	for side in [-1.0, 1.0]:
		var segments: Array[Sprite3D] = []
		for k in 22:
			segments.append(_sprite(texture, 0.065))
		vines.append({"side": side, "segments": segments})
	var elapsed := 0.0
	var struck := false
	while elapsed < 0.75:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if not _alive(attacker) or not _alive(target):
			break
		var origin := _center(attacker)
		var goal := _center(target)
		var reach := clampf(elapsed / 0.3, 0.0, 1.0) if elapsed < 0.45 else clampf(1.0 - (elapsed - 0.45) / 0.3, 0.0, 1.0)
		var dir := (goal - origin)
		var side_dir := dir.cross(Vector3.UP).normalized()
		for vine in vines:
			var segments: Array[Sprite3D] = vine["segments"]
			for k in segments.size():
				var u := float(k + 1) / segments.size()
				var t := u * reach
				# Arco de látigo: sale por un costado, se curva hacia arriba y cae sobre el rival;
				# la punta ondula como un látigo.
				var arc := side_dir * float(vine["side"]) * sin(t * PI) * 1.6 + Vector3.UP * sin(t * PI) * (1.4 - elapsed)
				var wave := side_dir * sin(u * 9.0 - elapsed * 18.0) * 0.18 * u
				segments[k].global_position = origin + dir * t + arc + wave
		if not struck and elapsed >= 0.3:
			struck = true
			_strike()
			PixelBurst.spawn(get_parent(), goal, PixelBurst.Kind.LEAVES, 0.8)
	queue_free()


## Mordisco, Triturar y Colmillos: al acercarse, unas mandíbulas se cierran sobre el rival.
func _bite(tint_html: String) -> void:
	await _wait(0.12)
	if not _alive(attacker) or not _alive(target):
		queue_free()
		return
	var reach := MELEE_REACH + 0.4 * ((target as PokemonActor).species.size_scale if target is PokemonActor else 1.0)
	if attacker.global_position.distance_to(target.global_position) > reach:
		queue_free()
		return
	var tint := Color.html(tint_html) if tint_html != "" else Color.WHITE
	var size := 0.06 * maxf(1.0, (target as PokemonActor).species.size_scale if target is PokemonActor else 1.0)
	var top := _sprite(PixelShapes.get_texture("jaw_top", tint), size)
	var bottom := _sprite(PixelShapes.get_texture("jaw_bottom", tint), size)
	var center := _center(target)
	var gap := 0.9 * size / 0.06
	var elapsed := 0.0
	var struck := false
	while elapsed < 0.55:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if _alive(target):
			center = _center(target)
		# Se abren un poco y se cierran de golpe (rebote al morder).
		var open := gap * (1.0 + 0.3 * sin(minf(elapsed / 0.18, 1.0) * PI)) if elapsed < 0.18 else gap * maxf(0.0, 1.0 - (elapsed - 0.18) / 0.08)
		top.global_position = center + Vector3.UP * (open * 0.5 + 0.2)
		bottom.global_position = center - Vector3.UP * (open * 0.5 + 0.2)
		if not struck and elapsed >= 0.26:
			struck = true
			_strike()
			if tint_html != "":
				PixelBurst.spawn(get_parent(), center, PixelBurst.Kind.SMOKE if tint_html == "ff7a20" else PixelBurst.Kind.SPLASH, 0.6)
		if elapsed > 0.4:
			top.modulate.a = 1.0 - (elapsed - 0.4) / 0.15
			bottom.modulate.a = top.modulate.a
	queue_free()


# --- Lote 2 ------------------------------------------------------------------------------

## Cinta de luz entre puntos (rayos y relámpagos), siempre de cara a la cámara.
func _ribbon_mesh() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = ImmediateMesh.new()
	mesh.top_level = true
	mesh.layers = 2
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh


func _glow_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _draw_ribbon(mesh: MeshInstance3D, points: PackedVector3Array, width: float, material: Material, clear: bool) -> void:
	var immediate := mesh.mesh as ImmediateMesh
	if clear:
		immediate.clear_surfaces()
	var camera := get_viewport().get_camera_3d()
	if camera == null or points.size() < 2:
		return
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, material)
	for i in points.size():
		var view := (camera.global_position - points[i]).normalized()
		var along := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var across := along.cross(view).normalized() * width * 0.5
		immediate.surface_add_vertex(points[i] + across)
		immediate.surface_add_vertex(points[i] - across)
	immediate.surface_end()


## Rayos (Rayo Hielo, Hiperrayo, Rayo Solar, Psicorrayo…): cinta del color con centro
## blanco que tiembla; los ondulados serpentean.
func _beam(data: Array) -> void:
	var color := MoveFamilies.color_of(move_id, data[0])
	var width: float = data[1]
	var duration: float = data[2]
	var wavy: bool = data[3]
	var mesh := _ribbon_mesh()
	var glow := _glow_material(color, 0.8)
	var core := _glow_material(Color(1, 1, 1), 1.0)
	var elapsed := 0.0
	var struck := false
	while elapsed < duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if not _alive(attacker):
			break
		var origin := _center(attacker)
		var goal := _center(target) if _alive(target) else origin + (attacker.get("_sprite") as DirectionalSprite).facing_world * 7.0
		var grow := clampf(elapsed / 0.12, 0.0, 1.0)
		var points := PackedVector3Array()
		var side := (goal - origin).cross(Vector3.UP).normalized()
		for i in 24:
			var t := i / 23.0 * grow
			var offset := side * sin(t * 18.0 - elapsed * 20.0) * 0.25 if wavy else Vector3.ZERO
			points.append(origin.lerp(goal, t) + offset)
		var flicker := 1.0 + sin(elapsed * 60.0) * 0.15
		var fade := clampf((duration - elapsed) / 0.15, 0.0, 1.0)
		_draw_ribbon(mesh, points, width * flicker * fade, glow, true)
		_draw_ribbon(mesh, points, width * 0.35 * flicker * fade, core, false)
		if not struck and grow >= 1.0:
			struck = true
			_strike("crack" if move_id in ["hyper-beam", "giga-impact"] else ("puddle" if move_id == "ice-beam" else ""))
			PixelBurst.spawn(get_parent(), goal, PixelBurst.Kind.SMOKE if color.v > 0.6 else PixelBurst.Kind.DUST, 0.8)
	queue_free()


## Relámpagos (Rayo, Trueno…): zigzag amarillo que tiembla; Trueno cae del cielo.
func _bolt(from_sky: bool) -> void:
	var mesh := _ribbon_mesh()
	var glow := _glow_material(Color(1.0, 0.9, 0.25), 0.9)
	var core := _glow_material(Color(1, 1, 0.9), 1.0)
	var elapsed := 0.0
	var struck := false
	var duration := 0.45 if not from_sky else 0.55
	while elapsed < duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if not _alive(attacker):
			break
		var goal := _center(target) if _alive(target) else _center(attacker) + (attacker.get("_sprite") as DirectionalSprite).facing_world * 6.0
		var origin := goal + Vector3(0.6, 14.0, 0.0) if from_sky else _center(attacker)
		var length := origin.distance_to(goal)
		var count := clampi(int(length / 0.5), 4, 30)
		var dir := (goal - origin) / maxf(length, 0.01)
		var side := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
		var points := PackedVector3Array()
		var sign := 1.0
		for i in count + 1:
			var t := float(i) / count
			var inner := i != 0 and i != count
			points.append(origin.lerp(goal, t) + (side * sign * _rng.randf_range(0.15, 0.45) if inner else Vector3.ZERO))
			sign = -sign
		_draw_ribbon(mesh, points, 0.3, glow, true)
		_draw_ribbon(mesh, points, 0.1, core, false)
		if not struck and elapsed > 0.08:
			struck = true
			_strike("scorch" if from_sky else "")
			PixelBurst.spawn(get_parent(), goal, PixelBurst.Kind.SMOKE, 0.7)
	queue_free()


## Golpes y cortes (Puño Fuego, Cuchillada, Garra Dragón, Tijera X…): al alcanzar al rival,
## la forma aparece sobre él (puño que se estrella, tajo que barre, zarpazo).
func _melee(data: Array) -> void:
	await _wait(0.12)
	if not _alive(attacker) or not _alive(target):
		queue_free()
		return
	var reach := MELEE_REACH + 0.4 * ((target as PokemonActor).species.size_scale if target is PokemonActor else 1.0)
	if attacker.global_position.distance_to(target.global_position) > reach and move_id != "psycho-cut":
		queue_free()
		return
	var shape: String = data[0]
	var color := MoveFamilies.color_of(move_id, data[1])
	var hits: int = data[2]
	var size := 0.07 * maxf(1.0, (target as PokemonActor).species.size_scale if target is PokemonActor else 1.0)
	for k in hits:
		if not _alive(target):
			break
		var sprite := _sprite(PixelShapes.get_texture(shape, color), size)
		var jitter := Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.3, 0.3), 0.0) if hits > 1 else Vector3.ZERO
		sprite.global_position = _center(target) + jitter
		sprite.scale = Vector3.ONE * (0.3 if shape == "fist" else 0.6)
		var tween := sprite.create_tween()
		tween.tween_property(sprite, "scale", Vector3.ONE * (1.25 if shape == "fist" else 1.0), 0.08)
		tween.tween_interval(0.12)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.12)
		tween.tween_callback(sprite.queue_free)
		if k == 0:
			_strike("crack" if shape == "fist" and MoveFamilies.strong(move_id) else "")
		PixelBurst.spawn(get_parent(), sprite.global_position, PixelBurst.Kind.DUST, 0.5)
		await _wait(0.1)
	if hits > 1 and _alive(target) and target is PokemonActor:
		(target as PokemonActor).float_text("×%d" % hits, Color.WHITE, 0.4)
	await _wait(0.4)
	queue_free()


## Desde el cielo (Avalancha, Meteoro Draco, Roca Afilada…): caen sobre el rival una tras otra.
func _sky(data: Array) -> void:
	var shape: String = data[0]
	var count: int = data[1]
	var mark: String = data[2]
	var color := MoveFamilies.color_of(move_id, "")
	if shape == "rock":
		color = Color(0.62, 0.55, 0.45)
	var struck := false
	for k in count:
		if not _alive(target):
			break
		var landing := _ground(target.global_position + Vector3(_rng.randf_range(-1.2, 1.2), 0, _rng.randf_range(-1.2, 1.2)) * (0.0 if k == 0 else 1.0))
		var sprite := _sprite(PixelShapes.get_texture(shape, color), 0.12 if shape in ["rock", "meteor"] else 0.08)
		if shape == "spike":
			# Roca Afilada: los picos salen del suelo.
			sprite.global_position = landing - Vector3.UP * 1.2
			var rise := sprite.create_tween()
			rise.tween_property(sprite, "global_position", landing + Vector3.UP * 0.5, 0.12)
			rise.tween_interval(0.5)
			rise.tween_property(sprite, "global_position", landing - Vector3.UP * 1.2, 0.2)
			rise.tween_callback(sprite.queue_free)
			await _wait(0.12)
		else:
			sprite.global_position = landing + Vector3(1.5, 12.0, 0.0)
			var fall := sprite.create_tween()
			fall.tween_property(sprite, "global_position", landing + Vector3.UP * 0.4, 0.45).set_ease(Tween.EASE_IN)
			fall.tween_callback(sprite.queue_free)
			await fall.finished
		PixelBurst.spawn(get_parent(), landing + Vector3.UP * 0.3, PixelBurst.Kind.ROCK if shape in ["rock", "spike"] else PixelBurst.Kind.SMOKE, 0.9)
		if not struck:
			struck = true
			_strike(mark)
		await _wait(0.08)
	await _wait(0.5)
	queue_free()


## Suelo: Terremoto (anillos que se abren por el suelo, temblor y grietas) o Surf (ola que
## avanza del atacante al rival).
func _ground_attack(kind: String) -> void:
	if not _alive(target):
		queue_free()
		return
	var origin := _ground(attacker.global_position)
	var goal := target.global_position
	var distance := origin.distance_to(_ground(goal))
	var struck := false
	if kind == "quake":
		var rig := get_tree().get_first_node_in_group(CameraRig.CAMERA_GROUP) as CameraRig
		if rig != null and attacker.player != null and origin.distance_to(attacker.player.global_position) < 40.0:
			rig.shake(1.0)
		var texture := PixelShapes.get_texture("ring", Color(0.75, 0.6, 0.35))
		for k in 3:
			var ring := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(2, 2)
			ring.mesh = quad
			var material := _glow_material(Color.WHITE, 1.0)
			material.albedo_texture = texture
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			ring.material_override = material
			ring.rotation.x = -PI * 0.5
			add_child(ring)
			ring.global_position = origin + Vector3.UP * 0.08
			var grow := ring.create_tween()
			grow.tween_property(ring, "scale", Vector3.ONE * (distance + 3.0), 0.7)
			grow.parallel().tween_property(material, "albedo_color:a", 0.0, 0.7)
			await _wait(0.15)
		await _wait(0.2)
		_strike("crack")
		PixelBurst.spawn(get_parent(), goal + Vector3.UP * 0.3, PixelBurst.Kind.ROCK, 1.2)
	else:
		var wave := _sprite(PixelShapes.get_texture("wave", Color(0.3, 0.6, 1.0)), 0.1)
		var elapsed := 0.0
		while elapsed < 0.9:
			await get_tree().process_frame
			elapsed += get_process_delta_time()
			var t := elapsed / 0.9
			var at := origin.lerp(_ground(goal) + (_ground(goal) - origin).normalized() * 2.0, t)
			wave.global_position = at + Vector3.UP * (1.0 + sin(t * PI) * 0.4)
			wave.modulate.a = 1.0 if t < 0.8 else (1.0 - t) / 0.2
			if not struck and t > 0.55:
				struck = true
				_strike("puddle")
				PixelBurst.spawn(get_parent(), goal + Vector3.UP * 0.5, PixelBurst.Kind.SPLASH, 1.4)
	await _wait(0.4)
	queue_free()


## Ráfagas (Hoja Afilada, Pin Misil, Semilladora…): varios proyectiles en abanico; el
## primero hace el daño y los demás se ven (con contador ×N al final).
func _gust(data: Array) -> void:
	var shape: String = data[0]
	var count: int = data[1]
	var spread: float = data[2]
	var spin: bool = data[3]
	var color := MoveFamilies.color_of(move_id, "")
	var frames: Array[Texture2D] = [PixelShapes.get_texture(shape, color)]
	var landed := [0]
	for i in count:
		if not _alive(attacker):
			break
		var origin := _center(attacker)
		var goal := _center(target) if _alive(target) else origin + (attacker.get("_sprite") as DirectionalSprite).facing_world * 7.0
		var side := (goal - origin).cross(Vector3.UP).normalized()
		var aim := goal + side * _rng.randf_range(-spread, spread) * 0.4 + Vector3.UP * _rng.randf_range(-spread, spread) * 0.2
		var targets: Array[Node3D] = []
		if _alive(target):
			targets.append(target)
		var on_hit := hit if i == 0 else (func(_node: Node3D) -> bool: return true)
		var projectile := AttackProjectile.launch(get_parent(), origin + side * _rng.randf_range(-spread, spread) * 0.5, aim, int(Moves.get_move(move_id)["type"]), attacker, targets, on_hit)
		projectile.set_look(frames, 0.055)
		projectile.speed = 15.0
		projectile.on_impact = func(at: Vector3) -> void:
			landed[0] += 1
			PixelBurst.spawn(get_parent(), at, PixelBurst.Kind.LEAVES if shape == "leaf" else PixelBurst.Kind.DUST, 0.4)
			if landed[0] == 1 and is_inside_tree():
				_impact("")
		if spin:
			projectile.create_tween().set_loops(8).tween_property(projectile, "rotation:y", TAU, 0.25).as_relative()
		await _wait(0.07)
	await _wait(1.2)
	if count > 1 and landed[0] > 1 and _alive(target) and target is PokemonActor:
		(target as PokemonActor).float_text("×%d" % landed[0], Color.WHITE, 0.4)
	queue_free()


## Remolino sobre el rival (Tornado, Vendaval, Torbellino, Bucle Arena…): embudo de
## espirales que giran, angosto abajo y ancho arriba.
func _twister() -> void:
	if not _alive(target):
		queue_free()
		return
	var color: Color = {"whirlpool": Color(0.35, 0.65, 1.0), "sand-tomb": Color(0.85, 0.72, 0.45), "leaf-tornado": Color(0.45, 0.8, 0.3)}.get(move_id, Color(0.86, 0.92, 1.0))
	var layers: Array[Sprite3D] = []
	for k in 6:
		layers.append(_sprite(PixelShapes.get_texture("swirl", color, k % 4), 0.05 + k * 0.018))
	var elapsed := 0.0
	var struck := false
	while elapsed < 1.1:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if not _alive(target):
			break
		var base := target.global_position
		for k in layers.size():
			var frame := int(elapsed * 18.0 + k) % 4
			layers[k].texture = PixelShapes.get_texture("swirl", color, frame)
			layers[k].global_position = base + Vector3.UP * (0.2 + k * 0.6) + Vector3(sin(elapsed * 8.0 + k) * 0.15, 0, 0)
			layers[k].modulate.a = clampf((1.1 - elapsed) / 0.25, 0.0, 1.0)
		if not struck and elapsed > 0.3:
			struck = true
			_strike()
	queue_free()
