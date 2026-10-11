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
			fx._melee(MoveFamilies.MELEE.get(id, MoveFamilies.MULTI.get(id, ["fist", "", 1])))
		"sky":
			fx._sky(MoveFamilies.SKY[id])
		"ground":
			fx._ground_attack(String(MoveFamilies.GROUND[id]))
		"gust":
			fx._gust(MoveFamilies.GUSTS[id])
		"twister":
			fx._twister()
		"drain":
			fx._drain()
		"psychic":
			fx._psychic()
		"ghost":
			fx._ghost(String(MoveFamilies.GHOST[id]))
		"fairy_ice":
			fx._fairy_ice(MoveFamilies.FAIRY_ICE[id])
		"charge":
			fx._charge()
		"slam":
			fx._slam()
		"explosion":
			fx._explosion()
		"sound":
			fx._sound(false)
		"uturn":
			fx._uturn()
		"signature":
			fx._signature()
		"ultimate":
			fx._ultimate()
		"typed":
			fx._typed()
	return true


## Ataques de estado (mejoras, clima, terreno, estados alterados, trampas, bajar
## estadísticas y copias): solo la animación y, en clima, terreno y trampas, su efecto
## en el mundo; lo demás lo sigue haciendo PokemonActor.use_move.
static func play_status(by: PokemonActor, to: Node3D, id: String) -> bool:
	var mode := MoveFamilies.status_mode(id)
	if mode == "" or by == null or not is_instance_valid(by):
		return false
	var fx := MoveFx.new()
	fx.attacker = by
	fx.target = to
	fx.move_id = id
	by.get_parent().add_child(fx)
	fx.global_position = by.global_position
	fx._rng.randomize()
	fx._status(mode)
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
		# El atacante pudo desaparecer (capturado) mientras su proyectil volaba.
		if rig != null and _alive(attacker) and attacker.player != null and attacker.global_position.distance_to(attacker.player.global_position) < 35.0:
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
		if rig != null and _alive(attacker) and attacker.player != null and origin.distance_to(attacker.player.global_position) < 40.0:
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


# --- Lote 3 ------------------------------------------------------------------------------

## Drenaje (Gigadrenado, Chupavidas…): golpe con destello verde y orbes que vuelven al atacante.
func _drain() -> void:
	if not _alive(target):
		queue_free()
		return
	PixelBurst.spawn(get_parent(), _center(target), PixelBurst.Kind.LEAVES, 0.7)
	_strike()
	var texture := PixelShapes.get_texture("orb", Color(0.55, 1.0, 0.45))
	var orbs: Array[Sprite3D] = []
	for k in 6:
		orbs.append(_sprite(texture, 0.03))
	var elapsed := 0.0
	while elapsed < 0.9:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if not _alive(attacker) or not _alive(target):
			break
		for k in orbs.size():
			var t := clampf((elapsed - k * 0.06) / 0.6, 0.0, 1.0)
			var swirl := Vector3(cos(k * 1.7 + elapsed * 6.0), sin(k * 1.3 + elapsed * 5.0), 0.0) * 0.4 * sin(t * PI)
			orbs[k].global_position = _center(target).lerp(_center(attacker), t) + swirl
			orbs[k].visible = t > 0.0 and t < 1.0
	if _alive(attacker):
		PixelBurst.spawn(get_parent(), _center(attacker), PixelBurst.Kind.HEAL, 0.8)
	queue_free()


## Psíquico: anillos morados alrededor del rival, que se eleva y cae.
func _psychic() -> void:
	if not _alive(target):
		queue_free()
		return
	var sprite := target.get("_sprite") as Sprite3D
	var rings: Array[Sprite3D] = []
	for k in 3:
		rings.append(_sprite(PixelShapes.get_texture("ring", Color(1.0, 0.45, 0.8)), 0.08))
	var elapsed := 0.0
	var struck := false
	while elapsed < 0.9:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if not _alive(target):
			break
		var lift := sin(clampf(elapsed / 0.9, 0.0, 1.0) * PI) * 0.9
		if sprite != null:
			sprite.position.y = lift
		for k in rings.size():
			var phase := fmod(elapsed * 1.6 + k / 3.0, 1.0)
			rings[k].global_position = _center(target) + Vector3.UP * lift
			rings[k].scale = Vector3.ONE * (0.5 + phase * 1.5)
			rings[k].modulate.a = 1.0 - phase
		if not struck and elapsed > 0.45:
			struck = true
			_strike()
	if _alive(target) and sprite != null:
		sprite.position.y = 0.0
	queue_free()


## Fantasma: Puño Sombra sale de la sombra del rival; Lengüetazo con lengua; Sombra Vil
## avanza como una sombra por el suelo y sale de golpe bajo el rival.
func _ghost(mode: String) -> void:
	if not _alive(target):
		queue_free()
		return
	match mode:
		"punch":
			var fist := _sprite(PixelShapes.get_texture("fist", Color(0.6, 0.45, 0.85)), 0.11)
			var base := _ground(target.global_position)
			fist.global_position = base
			var rise := fist.create_tween()
			rise.tween_property(fist, "global_position", _center(target), 0.18)
			await rise.finished
			_strike()
			await _wait(0.2)
		"lick":
			if attacker.global_position.distance_to(target.global_position) > MELEE_REACH + 1.5:
				queue_free()
				return
			var mesh := _ribbon_mesh()
			var pink := _glow_material(Color(1.0, 0.45, 0.6), 1.0)
			var elapsed := 0.0
			while elapsed < 0.45:
				await get_tree().process_frame
				elapsed += get_process_delta_time()
				if not _alive(attacker) or not _alive(target):
					break
				var reach := sin(clampf(elapsed / 0.45, 0.0, 1.0) * PI)
				var points := PackedVector3Array()
				for i in 10:
					var t := i / 9.0 * reach
					points.append(_center(attacker).lerp(_center(target), t) + Vector3.UP * sin(t * PI) * 0.3)
				_draw_ribbon(mesh, points, 0.22, pink, true)
				if elapsed > 0.2 and elapsed - get_process_delta_time() <= 0.2:
					_strike()
		_:
			var shadow := _sprite(PixelShapes.get_texture("orb", Color(0.15, 0.1, 0.2)), 0.08)
			var elapsed := 0.0
			while elapsed < 0.5:
				await get_tree().process_frame
				elapsed += get_process_delta_time()
				if not _alive(attacker) or not _alive(target):
					break
				shadow.global_position = _ground(attacker.global_position.lerp(target.global_position, elapsed / 0.5)) + Vector3.UP * 0.1
				shadow.scale = Vector3(1.4, 0.4, 1.0)
			PixelBurst.spawn(get_parent(), _center(target), PixelBurst.Kind.SMOKE, 0.9)
			_strike()
	queue_free()


## Hada y Hielo: Brillo Mágico (destellos rosas en círculo), Fuerza Lunar (una luna cae),
## Ventisca (cono de nieve), Canto Helado (carámbanos).
func _fairy_ice(data: Array) -> void:
	var mode: String = data[0]
	var color := Color.html(data[1])
	if not _alive(target):
		queue_free()
		return
	match mode:
		"gleam":
			var stars: Array[Sprite3D] = []
			for k in 10:
				stars.append(_sprite(PixelShapes.get_texture("star", color), 0.06))
			var elapsed := 0.0
			var struck := false
			while elapsed < 0.7:
				await get_tree().process_frame
				elapsed += get_process_delta_time()
				if not _alive(attacker):
					break
				for k in stars.size():
					var angle := TAU * k / stars.size() + elapsed * 3.0
					var radius := 0.5 + elapsed * 6.0
					stars[k].global_position = _center(attacker) + Vector3(cos(angle), 0.3 * sin(angle * 2.0), sin(angle)) * radius
					stars[k].modulate.a = clampf((0.7 - elapsed) / 0.2, 0.0, 1.0)
				if not struck and _alive(target) and 0.5 + elapsed * 6.0 >= attacker.global_position.distance_to(target.global_position):
					struck = true
					_strike()
		"moon":
			var moon := _sprite(PixelShapes.get_texture("moon", color), 0.09)
			moon.global_position = _center(target) + Vector3(0, 7.0, 0)
			var fall := moon.create_tween()
			fall.tween_property(moon, "global_position", _center(target), 0.55).set_ease(Tween.EASE_IN)
			await fall.finished
			PixelBurst.spawn(get_parent(), _center(target), PixelBurst.Kind.HEAL, 1.2)
			_strike("")
			moon.queue_free()
			await _wait(0.2)
		"snow":
			_stream_with(PixelShapes.get_texture("snow", color), 0.05, 0.9 if move_id == "blizzard" else 0.5, 1.2 if move_id == "blizzard" else 0.6)
			return
		"icicle":
			_gust(["icicle", 3, 0.5, false])
			return
	queue_free()


## Chorro genérico con textura propia (nieve de Ventisca y Viento Hielo).
func _stream_with(texture: Texture2D, pixel_size: float, duration: float, spread: float) -> void:
	var landed := false
	var elapsed := 0.0
	var drops: Array[Dictionary] = []
	while elapsed < duration + 0.6:
		await get_tree().process_frame
		var delta := get_process_delta_time()
		elapsed += delta
		if not _alive(attacker):
			break
		var origin := _center(attacker)
		var goal := _center(target) if _alive(target) else origin + Vector3.FORWARD * 6.0
		if elapsed < duration:
			for k in 2:
				var drop := _sprite(texture, pixel_size)
				drop.global_position = origin
				drops.append({"node": drop, "t": 0.0, "wobble": Vector3(_rng.randf_range(-spread, spread), _rng.randf_range(-spread * 0.6, spread), _rng.randf_range(-spread, spread))})
		for d in drops.duplicate():
			var node: Sprite3D = d["node"]
			d["t"] = float(d["t"]) + delta * 2.2
			var t: float = d["t"]
			node.global_position = origin.lerp(goal, minf(t, 1.0)) + (d["wobble"] as Vector3) * t
			if t >= 1.0:
				if not landed:
					landed = true
					_strike()
				drops.erase(d)
				node.queue_free()
	for d in drops:
		(d["node"] as Node).queue_free()
	queue_free()


## Auras de carga (Envite Ígneo, Voltio Cruel, Acua Jet, Pájaro Osado, Ataque Rápido…):
## cubierto del color del tipo, embiste en línea recta dejando estela y golpea al llegar.
func _charge() -> void:
	if not _alive(target) or attacker.global_position.distance_to(target.global_position) > PokemonActor.RANGED_MAX:
		queue_free()
		return
	var color := MoveFamilies.color_of(move_id, "")
	var sprite := _attacker_sprite()
	attacker.set_physics_process(false)
	var start := attacker.global_position
	var goal := target.global_position - (target.global_position - start).normalized() * 1.2
	var texture := PixelShapes.get_texture("orb", color)
	var elapsed := 0.0
	var duration := 0.18 if move_id in ["quick-attack", "extreme-speed", "aqua-jet", "accelerock"] else 0.3
	if sprite != null:
		sprite.set_instance_shader_parameter("flash", 0.35)
	while elapsed < duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if not _alive(attacker):
			queue_free()
			return
		attacker.global_position = start.lerp(goal, clampf(elapsed / duration, 0.0, 1.0))
		var trail := _sprite(texture, 0.05)
		trail.global_position = _center(attacker) + Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3), 0)
		trail.create_tween().tween_property(trail, "modulate:a", 0.0, 0.35)
	if sprite != null:
		sprite.set_instance_shader_parameter("flash", 0.0)
	_strike("crack" if MoveFamilies.strong(move_id) else "")
	PixelBurst.spawn(get_parent(), _center(target) if _alive(target) else goal, PixelBurst.Kind.DUST, 1.0)
	attacker.set_physics_process(true)
	await _wait(0.6)
	queue_free()


## Saltos aplastantes (Golpe Cuerpo, Patada Salto Alta, Pisotón…): salta alto y cae sobre
## el rival con onda en el suelo.
func _slam() -> void:
	if not _alive(target) or attacker.global_position.distance_to(target.global_position) > PokemonActor.RANGED_MAX:
		queue_free()
		return
	var sprite := _attacker_sprite()
	attacker.set_physics_process(false)
	var start := attacker.global_position
	var goal := target.global_position - (target.global_position - start).normalized() * 0.8
	var elapsed := 0.0
	while elapsed < 0.55:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if not _alive(attacker):
			queue_free()
			return
		var t := clampf(elapsed / 0.55, 0.0, 1.0)
		attacker.global_position = start.lerp(goal, t)
		if sprite != null:
			sprite.position.y = sin(t * PI) * 3.0
	if sprite != null:
		sprite.position.y = 0.0
	var ring := _sprite(PixelShapes.get_texture("ring", Color(0.8, 0.7, 0.5)), 0.06)
	ring.global_position = _ground(goal) + Vector3.UP * 0.2
	var grow := ring.create_tween()
	grow.tween_property(ring, "scale", Vector3.ONE * 3.0, 0.3)
	grow.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	PixelBurst.spawn(get_parent(), _ground(goal) + Vector3.UP * 0.3, PixelBurst.Kind.DUST, 1.2)
	_strike("crack")
	attacker.set_physics_process(true)
	await _wait(0.4)
	queue_free()


## Explosiones (Explosión, Autodestrucción, Onda Tóxica…): estallido en anillo con humo y
## temblor; alcanza al rival si está cerca.
func _explosion() -> void:
	var color := MoveFamilies.color_of(move_id, "")
	var center := _center(attacker)
	var rig := get_tree().get_first_node_in_group(CameraRig.CAMERA_GROUP) as CameraRig
	if rig != null:
		rig.shake(1.0)
	for k in 3:
		var ring := _sprite(PixelShapes.get_texture("ring", color), 0.08)
		ring.global_position = center
		var grow := ring.create_tween()
		grow.tween_property(ring, "scale", Vector3.ONE * (3.0 + k), 0.45)
		grow.parallel().tween_property(ring, "modulate:a", 0.0, 0.45)
	for k in 6:
		PixelBurst.spawn(get_parent(), center + Vector3(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-0.3, 1.2), _rng.randf_range(-1.5, 1.5)), PixelBurst.Kind.SMOKE, 1.2)
	await _wait(0.15)
	if _alive(target) and _alive(attacker) and attacker.global_position.distance_to(target.global_position) < PokemonActor.RANGED_MAX:
		_strike("scorch")
	await _wait(0.6)
	queue_free()


## Sonido (Vozarrón, Estruendo, Zumbido…): arcos de onda y notas que viajan al rival.
func _sound(notes_only: bool) -> void:
	var color := MoveFamilies.color_of(move_id, "")
	var struck := false
	var elapsed := 0.0
	var waves: Array[Dictionary] = []
	while elapsed < 0.9:
		await get_tree().process_frame
		var delta := get_process_delta_time()
		elapsed += delta
		if not _alive(attacker):
			break
		if waves.size() < 6 and int(elapsed * 10.0) >= waves.size() * 1.5:
			var shape := "note" if notes_only or waves.size() % 2 == 1 else "ring"
			var node := _sprite(PixelShapes.get_texture(shape, color), 0.07 if shape == "ring" else 0.07)
			waves.append({"node": node, "t": 0.0})
		var goal := _center(target) if _alive(target) else _center(attacker) + Vector3.FORWARD * 6.0
		for w in waves:
			w["t"] = float(w["t"]) + delta * 1.8
			var t: float = w["t"]
			var node: Sprite3D = w["node"]
			node.global_position = _center(attacker).lerp(goal, minf(t, 1.0)) + Vector3.UP * sin(t * 6.0) * 0.2
			node.scale = Vector3.ONE * (0.6 + t)
			node.modulate.a = clampf(1.2 - t, 0.0, 1.0)
			if t >= 1.0 and not struck and not notes_only:
				struck = true
				_strike()
	queue_free()


## Ida y Vuelta, Voltiocambio, Viraje: golpea y vuelve a la ball; si es tu compañero en un
## combate, sale el siguiente de tu equipo.
func _uturn() -> void:
	var data: Array = ["slash" if move_id == "u-turn" else "fist", "", 1]
	await _melee_hit_only(data)
	if not _alive(attacker):
		queue_free()
		return
	var battle := get_tree().get_first_node_in_group(&"battle") as BattleManager
	if attacker.role == PokemonActor.Role.COMPANION and battle != null and battle.active and battle.next_healthy() >= 0:
		battle.set("_switch_cooldown", 0.0)
		battle.switch_to(battle.next_healthy())
	else:
		# Salvaje o sin cambio: salta hacia atrás como si regresara.
		var back := attacker.global_position + (attacker.global_position - (target.global_position if _alive(target) else attacker.global_position)).normalized() * 3.0
		attacker.create_tween().tween_property(attacker, "global_position", back, 0.25)
	queue_free()


func _melee_hit_only(data: Array) -> void:
	await _wait(0.12)
	if not _alive(attacker) or not _alive(target):
		return
	var sprite := _sprite(PixelShapes.get_texture(data[0], MoveFamilies.color_of(move_id, data[1])), 0.07)
	sprite.global_position = _center(target)
	_strike()
	sprite.create_tween().tween_property(sprite, "modulate:a", 0.0, 0.3)
	await _wait(0.3)


## Firmas de legendarios: combinaciones únicas y más grandes.
func _signature() -> void:
	match move_id:
		"aeroblast":
			await _beam_wait(["e8eef8", 0.8, 0.9, true])
		"roar-of-time":
			await _rings_at(_center(attacker), Color(0.35, 0.55, 1.0), 5, 8.0)
			_strike("crack")
		"spacial-rend":
			if _alive(target):
				for k in 2:
					var cut := _sprite(PixelShapes.get_texture("cross", Color(1.0, 0.5, 0.85)), 0.16)
					cut.global_position = _center(target)
					cut.create_tween().tween_property(cut, "modulate:a", 0.0, 0.5)
					await _wait(0.12)
				_strike("crack")
		"origin-pulse":
			for k in 5:
				_sky_beam(Color(0.3, 0.6, 1.0))
				await _wait(0.12)
			_strike("puddle")
		"precipice-blades":
			await _sky_wait(["spike", 6, "crack"], Color(0.95, 0.35, 0.2))
		"dragon-ascent":
			await _charge_wait()
		_:
			await _sky_wait(["orb", 4, "scorch"], MoveFamilies.color_of(move_id, ""))
	var rig := get_tree().get_first_node_in_group(CameraRig.CAMERA_GROUP) as CameraRig
	if rig != null:
		rig.shake(1.0)
	await _wait(0.4)
	queue_free()


## Definitivos de los iniciales: Planta Feroz (raíces gigantes), Anillo Ígneo (columna de
## fuego) e Hidrocañón (cañonazo de agua).
func _ultimate() -> void:
	if not _alive(target):
		queue_free()
		return
	var rig := get_tree().get_first_node_in_group(CameraRig.CAMERA_GROUP) as CameraRig
	match move_id:
		"frenzy-plant":
			var texture := PixelShapes.get_texture("vine")
			for k in 6:
				var angle := TAU * k / 6.0
				var root := Vector3(cos(angle), 0, sin(angle)) * 2.0
				for seg in 10:
					var node := _sprite(texture, 0.09)
					node.global_position = _ground(target.global_position + root * (1.0 - seg / 10.0)) + Vector3.UP * seg * 0.35
					node.modulate.a = 0.0
					var tween := node.create_tween()
					tween.tween_interval(seg * 0.03)
					tween.tween_property(node, "modulate:a", 1.0, 0.05)
					tween.tween_interval(0.6)
					tween.tween_property(node, "modulate:a", 0.0, 0.3)
			await _wait(0.35)
			_strike("crack")
		"blast-burn":
			for k in 14:
				var flame := _sprite(PixelShapes.get_texture("flame"), 0.12)
				flame.global_position = _ground(target.global_position) + Vector3(_rng.randf_range(-0.6, 0.6), k * 0.4, _rng.randf_range(-0.6, 0.6))
				flame.scale = Vector3.ONE * (1.6 - k * 0.07)
				var tween := flame.create_tween()
				tween.tween_interval(0.6 + k * 0.02)
				tween.tween_property(flame, "modulate:a", 0.0, 0.3)
				await _wait(0.02)
			_strike("scorch")
		"hydro-cannon":
			var ball := _sprite(PixelShapes.get_texture("orb", Color(0.3, 0.6, 1.0)), 0.18)
			ball.global_position = _center(attacker)
			var shot := ball.create_tween()
			shot.tween_property(ball, "global_position", _center(target), 0.35)
			await shot.finished
			ball.queue_free()
			for k in 3:
				PixelBurst.spawn(get_parent(), _center(target) + Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf_range(0, 1), 0), PixelBurst.Kind.SPLASH, 1.4)
			_strike("puddle")
	if rig != null:
		rig.shake(1.0)
	await _wait(0.8)
	queue_free()


# Variantes que esperan a terminar (para combinarlas en las firmas).

func _beam_wait(data: Array) -> void:
	var fx := MoveFx.new()
	fx.attacker = attacker
	fx.target = target
	fx.move_id = move_id
	fx.hit = hit
	get_parent().add_child(fx)
	fx._beam(data)
	hit = Callable()
	await _wait(float(data[2]))


func _sky_wait(data: Array, color: Color) -> void:
	var fx := MoveFx.new()
	fx.attacker = attacker
	fx.target = target
	fx.move_id = move_id
	fx.hit = hit
	get_parent().add_child(fx)
	fx._sky(data)
	hit = Callable()
	await _wait(0.6 * int(data[1]))


func _charge_wait() -> void:
	var fx := MoveFx.new()
	fx.attacker = attacker
	fx.target = target
	fx.move_id = move_id
	fx.hit = hit
	get_parent().add_child(fx)
	fx._charge()
	hit = Callable()
	await _wait(0.6)


func _rings_at(at: Vector3, color: Color, count: int, size: float) -> void:
	for k in count:
		var ring := _sprite(PixelShapes.get_texture("ring", color), 0.08)
		ring.global_position = at
		var grow := ring.create_tween()
		grow.tween_property(ring, "scale", Vector3.ONE * size, 0.6)
		grow.parallel().tween_property(ring, "modulate:a", 0.0, 0.6)
		await _wait(0.1)


func _sky_beam(color: Color) -> void:
	if not _alive(target):
		return
	var mesh := _ribbon_mesh()
	var glow := _glow_material(color, 0.85)
	var at := _ground(target.global_position + Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5)))
	_draw_ribbon(mesh, PackedVector3Array([at + Vector3.UP * 14.0, at]), 0.5, glow, true)
	var tween := mesh.create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(mesh.queue_free)


# --- Estado ------------------------------------------------------------------------------

func _status(mode: String) -> void:
	var color := MoveFamilies.color_of(move_id, "")
	match mode:
		"swords":
			var swords: Array[Sprite3D] = []
			for k in 4:
				swords.append(_sprite(PixelShapes.get_texture("sword", color), 0.06))
			var elapsed := 0.0
			while elapsed < 1.0:
				await get_tree().process_frame
				elapsed += get_process_delta_time()
				if not _alive(attacker):
					break
				for k in swords.size():
					var angle := TAU * k / 4.0 + elapsed * 6.0
					swords[k].global_position = _center(attacker) + Vector3(cos(angle), 0.6, sin(angle)) * 1.1
		"aura", "speed":
			for k in 4:
				if not _alive(attacker):
					break
				var ring := _sprite(PixelShapes.get_texture("ring", color), 0.04)
				ring.global_position = _ground(attacker.global_position) + Vector3.UP * 0.2
				var rise := ring.create_tween()
				rise.tween_property(ring, "global_position:y", ring.global_position.y + 1.8, 0.5)
				rise.parallel().tween_property(ring, "modulate:a", 0.0, 0.5)
				if mode == "speed":
					PixelBurst.spawn(get_parent(), attacker.global_position + Vector3.UP * 0.4, PixelBurst.Kind.DUST, 0.5)
				await _wait(0.12)
		"shield":
			var shield := _sprite(PixelShapes.get_texture("ring", Color(0.6, 0.95, 0.6) if move_id == "protect" or move_id == "detect" else color), 0.07)
			var elapsed := 0.0
			while elapsed < 1.1:
				await get_tree().process_frame
				elapsed += get_process_delta_time()
				if not _alive(attacker):
					break
				shield.global_position = _center(attacker)
				shield.scale = Vector3.ONE * (1.0 + sin(elapsed * 12.0) * 0.05) * maxf(1.0, attacker.species.size_scale)
				shield.modulate.a = clampf((1.1 - elapsed) / 0.3, 0.0, 1.0)
		"rain", "sun", "hail", "sand":
			var kinds := {"rain": Weather.Kind.RAIN, "sun": Weather.Kind.CLEAR, "hail": Weather.Kind.SNOW, "sand": Weather.Kind.SAND}
			Weather.forced = int(kinds[mode])
			GameState.notice.emit({"rain": "¡Empezó a llover!", "sun": "¡El sol pega fuerte!", "hail": "¡Empezó a granizar!", "sand": "¡Se levantó una tormenta de arena!"}[mode])
			await _rings_at(_center(attacker), color, 2, 6.0)
			# El clima dura unos minutos y luego vuelve el normal.
			get_tree().create_timer(90.0).timeout.connect(func() -> void:
				if Weather.forced == int(kinds[mode]):
					Weather.forced = -1)
		"terrain":
			var ground := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(16, 16)
			ground.mesh = quad
			var material := _glow_material(color, 0.35)
			ground.material_override = material
			ground.rotation.x = -PI * 0.5
			get_parent().add_child(ground)
			ground.global_position = _ground(attacker.global_position) + Vector3.UP * 0.05
			var fade := ground.create_tween()
			fade.tween_interval(20.0)
			fade.tween_property(material, "albedo_color:a", 0.0, 2.0)
			fade.tween_callback(ground.queue_free)
		"powder":
			await _over_target("cloud", color, "ZZZ" if move_id in ["sleep-powder", "spore"] else ("PAR" if move_id == "stun-spore" else "PSN"))
		"zap":
			if _alive(target):
				var mesh := _ribbon_mesh()
				var glow := _glow_material(Color(1.0, 0.9, 0.25), 0.9)
				for k in 6:
					var points := PackedVector3Array()
					for i in 8:
						points.append(_center(attacker).lerp(_center(target), i / 7.0) + Vector3(0, _rng.randf_range(-0.2, 0.2), 0))
					_draw_ribbon(mesh, points, 0.15, glow, true)
					await _wait(0.05)
				_label_over(target, "PAR", Color(1.0, 0.9, 0.3))
		"wisp":
			if _alive(target):
				var wisp := _sprite(PixelShapes.get_texture("orb", Color(0.55, 0.4, 1.0) if move_id == "will-o-wisp" else Color(1.0, 0.85, 0.3)), 0.06)
				var tween := wisp.create_tween()
				wisp.global_position = _center(attacker)
				tween.tween_property(wisp, "global_position", _center(target), 0.5)
				await tween.finished
				_label_over(target, "BRN" if move_id == "will-o-wisp" else "¿?", Color(1.0, 0.5, 0.3))
		"waves":
			await _rings_toward(Color(0.85, 0.85, 1.0))
		"notes":
			await _sound_wait()
			if _alive(target):
				_label_over(target, "ZZZ", Color(0.8, 0.85, 1.0))
		"eyes":
			var eye := _sprite(PixelShapes.get_texture("eye", Color(0.85, 0.15, 0.15)), 0.05)
			eye.global_position = _center(attacker) + Vector3.UP * 0.6
			eye.create_tween().tween_property(eye, "modulate:a", 0.0, 0.8)
			if _alive(target):
				var sprite := target.get("_sprite") as Sprite3D
				if sprite != null:
					var shrink := sprite.create_tween()
					shrink.tween_property(sprite, "scale", Vector3(0.9, 0.9, 1.0), 0.15)
					shrink.tween_property(sprite, "scale", Vector3.ONE, 0.2)
			await _wait(0.8)
		"hearts", "feathers":
			var shape := "heart" if mode == "hearts" else "feather"
			for k in 5:
				if not _alive(attacker) or not _alive(target):
					break
				var node := _sprite(PixelShapes.get_texture(shape, Color(1.0, 0.5, 0.7) if mode == "hearts" else Color(0.95, 0.95, 1.0)), 0.05)
				node.global_position = _center(attacker)
				var tween := node.create_tween()
				tween.tween_property(node, "global_position", _center(target) + Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(0, 0.8), 0), 0.6)
				tween.tween_property(node, "modulate:a", 0.0, 0.2)
				await _wait(0.1)
			await _wait(0.6)
		"web-shot":
			if _alive(target):
				var web := _sprite(PixelShapes.get_texture("web"), 0.06)
				web.global_position = _center(attacker)
				var tween := web.create_tween()
				tween.tween_property(web, "global_position", _center(target), 0.35)
				tween.tween_interval(0.8)
				tween.tween_property(web, "modulate:a", 0.0, 0.3)
				await _wait(1.4)
		"hazard":
			_place_hazards()
		"clones":
			var sprite := _attacker_sprite()
			if sprite != null:
				for k in 3:
					var clone := sprite.duplicate() as Sprite3D
					add_child(clone)
					clone.global_position = attacker.global_position + Vector3(cos(k * 2.1), 0, sin(k * 2.1)) * 1.4
					clone.modulate.a = 0.5
				await _wait(2.0)
		"doll":
			var doll := _sprite(PixelShapes.get_texture("doll"), 0.07)
			doll.global_position = _ground(attacker.global_position) + attacker.global_basis.x * 1.2 + Vector3.UP * 0.5
			PixelBurst.spawn(get_parent(), doll.global_position, PixelBurst.Kind.SMOKE, 0.6)
			await _wait(3.0)
		"transform":
			for k in 8:
				PixelBurst.spawn(get_parent(), _center(attacker) + Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.4, 0.6), 0), PixelBurst.Kind.HEAL, 0.5)
			await _wait(0.6)
	queue_free()


## Nube que cae sobre el rival y el ícono del estado sobre su cabeza.
func _over_target(shape: String, color: Color, icon: String) -> void:
	if not _alive(target):
		return
	var cloud := _sprite(PixelShapes.get_texture(shape, color), 0.13)
	cloud.global_position = _center(target) + Vector3.UP * 2.0
	var tween := cloud.create_tween()
	tween.tween_property(cloud, "global_position", _center(target) + Vector3.UP * 0.4, 0.5)
	tween.tween_property(cloud, "modulate:a", 0.0, 0.4)
	await tween.finished
	if _alive(target):
		_label_over(target, icon, color.lightened(0.2))


func _label_over(node: Node3D, text: String, color: Color) -> void:
	if node is PokemonActor:
		(node as PokemonActor).float_text(text, color, 0.6)


func _rings_toward(color: Color) -> void:
	for k in 3:
		if not _alive(attacker):
			break
		var ring := _sprite(PixelShapes.get_texture("ring", color), 0.04)
		ring.global_position = _center(attacker)
		var goal := _center(target) if _alive(target) else _center(attacker) + Vector3.FORWARD * 4.0
		var tween := ring.create_tween()
		tween.tween_property(ring, "global_position", goal, 0.5)
		tween.parallel().tween_property(ring, "scale", Vector3.ONE * 2.0, 0.5)
		tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.5)
		await _wait(0.15)
	await _wait(0.4)


func _sound_wait() -> void:
	var fx := MoveFx.new()
	fx.attacker = attacker
	fx.target = target
	fx.move_id = move_id
	get_parent().add_child(fx)
	fx._sound(true)
	await _wait(0.9)


## Trampas: de 3 a 5 alrededor del rival (Red Viscosa: una red).
func _place_hazards() -> void:
	var center := target.global_position if _alive(target) else attacker.global_position + Vector3.FORWARD * 3.0
	var count := 1 if move_id == "sticky-web" else 4
	for k in count:
		var hazard := MoveHazard.new()
		hazard.owner_actor = attacker
		hazard.kind = move_id
		var shape: String = {"stealth-rock": "rock", "toxic-spikes": "caltrop", "sticky-web": "web"}.get(move_id, "caltrop")
		var look := Sprite3D.new()
		look.texture = PixelShapes.get_texture(shape, Color(0.65, 0.3, 0.75) if move_id == "toxic-spikes" else Color(0.6, 0.55, 0.5))
		look.pixel_size = 0.07 if shape != "web" else 0.09
		look.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		look.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y if shape != "web" else BaseMaterial3D.BILLBOARD_DISABLED
		look.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		look.shaded = false
		if shape == "web":
			look.rotation.x = -PI * 0.5
		hazard.add_child(look)
		get_parent().add_child(hazard)
		var spot := center + Vector3(cos(TAU * k / count), 0, sin(TAU * k / count)) * (1.6 if count > 1 else 0.0)
		hazard.global_position = _ground(spot) + Vector3.UP * (0.25 if shape != "web" else 0.05)
	await _wait(0.2)


## Ataques sin familia propia: según su tipo. Los físicos golpean con la forma de su tipo
## (puño, tajo, zarpazo, cruz); los especiales lanzan un proyectil con la forma del tipo.
func _typed() -> void:
	var move := Moves.get_move(move_id)
	var type := int(move["type"])
	if move["class"] == "physical":
		_melee([MoveFamilies.TYPE_MELEE.get(type, "fist"), "", 1])
	else:
		_shaped([MoveFamilies.TYPE_SHAPES.get(type, "orb"), 1, 0.06, 13.0, ""])
