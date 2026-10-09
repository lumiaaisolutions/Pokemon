extends Node
## Prueba de la Fase 1 sobre world/main.tscn con input simulado (teclado y mando).
## Uso: godot --headless --path . tests/test_player_movement.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")

var _failures: Array[String] = []
var _main: Node3D
var _player: Player
var _world: WorldBuilder
var _rig: CameraRig


func _ready() -> void:
	_main = MAIN_SCENE.instantiate() as Node3D
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_world = _main.get_node("World") as WorldBuilder
	_rig = _main.get_node("CameraRig") as CameraRig
	await _run()
	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_player_movement: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run() -> void:
	await _frames(30)
	_check(_player.is_on_floor(), "el jugador debe empezar sobre el suelo")
	_check(absf(_player.global_position.y - _world.surface_height_at(0, 0)) < 0.2, "el jugador debe quedar a ras del terreno al inicio (y=%.2f)" % _player.global_position.y)
	_check(_terrain_faces_up(), "las caras del terreno deben mirar hacia arriba")
	_check(_rig.get_pitch_deg() >= _rig.pitch_min_deg and _rig.get_pitch_deg() <= _rig.pitch_max_deg, "el pitch de la cámara debe estar dentro de sus límites")

	# Caminar hacia adelante (teclado): con la cámara en yaw 0 es -Z.
	var start := _player.global_position
	Input.action_press("move_forward")
	await _frames(60)
	var walk_speed := _player.get_ground_speed()
	Input.action_release("move_forward")
	_check(absf(walk_speed - _player.config.walk_speed) < 0.3, "caminar debe llegar a %.1f m/s (fue %.2f)" % [_player.config.walk_speed, walk_speed])
	_check(_player.global_position.z < start.z - 3.0, "caminar hacia adelante debe avanzar en -Z")
	_check(_player.get_visible_facing() == DirectionalSprite.Facing.UP, "alejándose de la cámara debe verse la espalda")

	# Correr.
	Input.action_press("move_forward")
	Input.action_press("run")
	await _frames(60)
	var run_speed := _player.get_ground_speed()
	Input.action_release("run")
	Input.action_release("move_forward")
	_check(absf(run_speed - _player.config.run_speed) < 0.4, "correr debe llegar a %.1f m/s (fue %.2f)" % [_player.config.run_speed, run_speed])
	var sprite := _player.get_node("Sprite") as Sprite3D
	_check(sprite.frame / _player.config.hframes >= 4, "al correr debe usarse una fila de la animación de correr")

	# Frenar.
	await _frames(30)
	_check(_player.get_ground_speed() < 0.05, "al soltar debe frenar")

	# Hacia la cámara: se ve el frente.
	Input.action_press("move_back")
	await _frames(20)
	Input.action_release("move_back")
	_check(_player.get_visible_facing() == DirectionalSprite.Facing.DOWN, "acercándose a la cámara debe verse el frente")
	await _frames(30)

	# Mando: stick izquierdo a la derecha, completo y a la mitad.
	var x_before := _player.global_position.x
	_joy_axis(JOY_AXIS_LEFT_X, 1.0)
	await _frames(60)
	var pad_speed := _player.get_ground_speed()
	_check(absf(pad_speed - _player.config.walk_speed) < 0.3, "stick completo debe caminar a %.1f m/s (fue %.2f)" % [_player.config.walk_speed, pad_speed])
	_check(_player.global_position.x > x_before + 3.0, "el stick a la derecha debe mover en +X")
	_check(_player.get_visible_facing() == DirectionalSprite.Facing.RIGHT, "moviéndose a la derecha debe verse de lado derecho")
	_joy_axis(JOY_AXIS_LEFT_X, 0.5)
	await _frames(40)
	var half_speed := _player.get_ground_speed()
	_check(half_speed > 1.0 and half_speed < _player.config.walk_speed * 0.8, "stick a la mitad debe caminar más lento (fue %.2f)" % half_speed)
	_joy_axis(JOY_AXIS_LEFT_X, 0.0)
	await _frames(30)

	# Recorrido largo por las colinas corriendo: nunca debe atravesar el terreno.
	var lowest_gap := INF
	Input.action_press("move_left")
	Input.action_press("move_forward")
	Input.action_press("run")
	for i in 600:
		await get_tree().physics_frame
		var p := _player.global_position
		lowest_gap = minf(lowest_gap, p.y - _world.surface_height_at(p.x, p.z))
	Input.action_release("run")
	Input.action_release("move_forward")
	Input.action_release("move_left")
	_check(lowest_gap > -0.2, "el jugador atravesó el terreno (holgura mínima %.2f m)" % lowest_gap)

	# Muros: tras 10 s corriendo en diagonal debe quedar dentro del bioma.
	var half := _world.config.size * 0.5
	var p := _player.global_position
	_check(absf(p.x) < half and absf(p.z) < half, "el jugador salió del bioma (%.1f, %.1f)" % [p.x, p.z])

	# Ningún árbol, roca o decoración debe flotar: su base queda en o bajo el terreno
	# en todo su contorno, y cada sprite tiene píxeles opacos en su fila inferior.
	_check(_props_grounded(), "hay elementos flotando sobre el terreno")

	# Props: corriendo contra un árbol no debe atravesarlo.
	var tree := _first_prop("Tree")
	_player.global_position = tree.global_position + Vector3(-3.0, 0.5, 0.0)
	_player.velocity = Vector3.ZERO
	await _frames(20)
	Input.action_press("move_right")
	Input.action_press("run")
	await _frames(90)
	Input.action_release("run")
	Input.action_release("move_right")
	_check(_player.global_position.x < tree.global_position.x - 0.3, "el jugador atravesó un árbol")
	var arm := _rig.get_node("Pitch/SpringArm") as SpringArm3D
	_check(arm.get_hit_length() > arm.spring_length * 0.8, "la cámara no debe acortarse al chocar con un árbol (%.1f m)" % arm.get_hit_length())

	# Muro: corriendo hacia el borde debe detenerse antes del límite.
	_player.global_position = Vector3(half - 6.0, _world.surface_height_at(half - 6.0, 0.0) + 0.5, 0.0)
	_player.velocity = Vector3.ZERO
	await _frames(20)
	Input.action_press("move_right")
	Input.action_press("run")
	await _frames(120)
	Input.action_release("run")
	Input.action_release("move_right")
	_check(_player.global_position.x < half, "el jugador cruzó el muro del borde (x=%.1f)" % _player.global_position.x)

	# Stamina: correr la agota; agotado camina, y al recuperarse vuelve a correr.
	_player.global_position = Vector3(0, _world.surface_height_at(0, 0) + 0.5, 0)
	_player.stamina = _player.config.stamina_max
	await _frames(10)
	Input.action_press("move_back")
	Input.action_press("run")
	await _frames(int((_player.config.stamina_max / _player.config.stamina_drain + 0.5) * 60))
	_check(_player.exhausted and _player.stamina <= 0.0, "correr más de 5 s debe agotar la stamina (%.0f)" % _player.stamina)
	await _frames(20)
	_check(_player.get_ground_speed() <= _player.config.walk_speed + 0.1, "agotado no debe poder correr (%.1f m/s)" % _player.get_ground_speed())
	Input.action_release("run")
	Input.action_release("move_back")
	await _frames(150)
	_check(not _player.exhausted and _player.stamina > 0.0, "al descansar debe recuperarse")

	# Salto: sube y vuelve al suelo sin daño.
	_player.global_position = Vector3(0, _world.surface_height_at(0, 0) + 0.5, 0)
	_player.velocity = Vector3.ZERO
	await _frames(20)
	var ground_y := _player.global_position.y
	var health_before := _player.health
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	var peak := ground_y
	for i in 60:
		await get_tree().physics_frame
		peak = maxf(peak, _player.global_position.y)
	_check(peak > ground_y + 1.0, "saltar debe elevar al jugador (%.2f m)" % (peak - ground_y))
	_check(_player.is_on_floor() and is_equal_approx(_player.health, health_before), "un salto normal no hace daño")

	# Caída desde 10 m: pierde (10 - 4) × 1 = 6 de vida (3 corazones).
	_player.global_position = Vector3(0, _world.surface_height_at(0, 0) + 10.5, 0)
	_player.velocity = Vector3.ZERO
	await _frames(90)
	var fall_damage := health_before - _player.health
	_check(fall_damage > 4.5 and fall_damage < 7.5, "una caída de 10 m debe quitar unos 6 de vida (quitó %.1f)" % fall_damage)

	# Nadar: al entrar al lago nada con la cabeza fuera y no gasta aire.
	_player.heal(100.0)
	var lake := _world.config.lake_center
	_player.global_position = Vector3(lake.x, _world.water_level_at(lake.x, lake.y) - 1.0, lake.y)
	_player.velocity = Vector3.ZERO
	await _frames(60)
	_check(_player.mode == Player.Mode.SWIM, "en el lago debe nadar (modo %d)" % _player.mode)
	_check(_player.air >= _player.config.air_max - 0.01, "nadando en la superficie no debe gastar aire")
	var level := _world.water_level_at(_player.global_position.x, _player.global_position.z)
	_check(_player.global_position.y + 1.5 > level, "nadando debe tener la cabeza fuera del agua")

	# Bucear sin parar: se acaba el aire y pierde vida.
	Input.action_press("dive")
	await _frames(int((_player.config.air_max + 3.5) * 60))
	_check(_player.air <= 0.0, "buceando más de %.0f s se acaba el aire" % _player.config.air_max)
	_check(_player.health < _player.config.health_max, "sin aire debe perder vida")
	Input.action_release("dive")
	await _frames(240)
	_check(_player.mode == Player.Mode.SWIM, "al soltar bucear debe volver a la superficie")

	# Desmayo en tierra: estrellitas, recuperación y se levanta.
	_player.global_position = Vector3(0, _world.surface_height_at(0, 0) + 0.5, 0)
	_player.velocity = Vector3.ZERO
	await _frames(30)
	var saved_duration := _player.config.downed_duration
	_player.config.downed_duration = 2.0
	_player.take_damage(1000.0)
	await _frames(2)
	_check(_player.mode == Player.Mode.DOWNED and _player.has_node("DizzyStars"), "a 0 de vida debe quedar desmayado con estrellitas")
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_release("move_forward")
	_check(_player.get_ground_speed() < 0.05, "desmayado no debe poder moverse")
	await _frames(150)
	_check(_player.mode == Player.Mode.WALK and is_equal_approx(_player.health, _player.config.health_max), "tras recuperarse debe levantarse con la vida llena")
	_player.config.downed_duration = saved_duration

	# Desmayo en el agua: pantalla negra y reaparece en el inicio.
	var blacked := [false]
	_player.blacked_out.connect(func() -> void: blacked[0] = true)
	_player.global_position = Vector3(lake.x, _world.water_level_at(lake.x, lake.y) - 1.0, lake.y)
	await _frames(20)
	_player.take_damage(1000.0)
	await _frames(90)
	_check(blacked[0], "desmayarse en el agua debe ser desmayo definitivo")
	_check(_player.global_position.distance_to(GameState.respawn_point) < 3.0, "tras el desmayo debe reaparecer en el punto de inicio")


func _props_grounded() -> bool:
	var ok := true
	for group in _world.get_children():
		if not group.name.begins_with("Props_"):
			continue
		for child in group.get_children():
			if child is StaticBody3D:
				var body := child as StaticBody3D
				var sprite := body.get_node("Sprite") as Sprite3D
				var radius := sprite.texture.get_width() * sprite.pixel_size * 0.5
				var p := body.global_position
				if p.y > _world.ground_base_height(p.x, p.z, radius) + 0.001 or not _bottom_row_opaque(sprite.texture):
					printerr("flota: %s en %s" % [body.name, p])
					ok = false
			elif child is MultiMeshInstance3D and child.name != "Bruma":
				# (La bruma del pantano flota a propósito: no es un objeto apoyado.)
				var instance := child as MultiMeshInstance3D
				var multimesh := instance.multimesh
				var quad := multimesh.mesh as QuadMesh
				if not _bottom_row_opaque((quad.material as StandardMaterial3D).albedo_texture):
					printerr("sprite con fila inferior transparente: %s" % instance.name)
					ok = false
				for i in multimesh.instance_count:
					var p := multimesh.get_instance_transform(i).origin
					if p.y > _world.ground_base_height(p.x, p.z, quad.size.x * 0.5) + 0.001:
						printerr("decoración flotando: %s #%d" % [instance.name, i])
						return false
	return ok


func _first_prop(prefix: String) -> Node3D:
	for child in _world.get_node("Props_Pradera").get_children():
		if child.name.begins_with(prefix):
			return child as Node3D
	return null


func _bottom_row_opaque(texture: Texture2D) -> bool:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var y := image.get_height() - 1
	for x in image.get_width():
		if image.get_pixel(x, y).a > 0.5:
			return true
	return false


func _terrain_faces_up() -> bool:
	var mesh := (_world.get_node("Terrain").get_child(0) as MeshInstance3D).mesh
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for n in normals:
		if n.y <= 0.0:
			return false
	return normals.size() > 0


func _joy_axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
