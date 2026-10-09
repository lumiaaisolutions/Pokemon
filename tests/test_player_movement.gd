extends Node
## Prueba de la Fase 1 sobre world/main.tscn con input simulado (teclado y mando).
## Uso: godot --headless --path . tests/test_player_movement.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")

var _failures: Array[String] = []
var _main: Node3D
var _player: Player
var _biome: BiomeGreybox
var _rig: CameraRig


func _ready() -> void:
	_main = MAIN_SCENE.instantiate() as Node3D
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_biome = _main.get_node("Pradera") as BiomeGreybox
	_rig = _main.get_node("CameraRig") as CameraRig
	await _run()
	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_player_movement: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run() -> void:
	await _frames(30)
	_check(_player.is_on_floor(), "el jugador debe empezar sobre el suelo")
	_check(absf(_player.global_position.y - _biome.surface_height_at(0, 0)) < 0.2, "el jugador debe quedar a ras del terreno al inicio (y=%.2f)" % _player.global_position.y)
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
	_check(_player.get_visible_facing() == Player.Facing.UP, "alejándose de la cámara debe verse la espalda")

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
	_check(_player.get_visible_facing() == Player.Facing.DOWN, "acercándose a la cámara debe verse el frente")
	await _frames(30)

	# Mando: stick izquierdo a la derecha, completo y a la mitad.
	var x_before := _player.global_position.x
	_joy_axis(JOY_AXIS_LEFT_X, 1.0)
	await _frames(60)
	var pad_speed := _player.get_ground_speed()
	_check(absf(pad_speed - _player.config.walk_speed) < 0.3, "stick completo debe caminar a %.1f m/s (fue %.2f)" % [_player.config.walk_speed, pad_speed])
	_check(_player.global_position.x > x_before + 3.0, "el stick a la derecha debe mover en +X")
	_check(_player.get_visible_facing() == Player.Facing.RIGHT, "moviéndose a la derecha debe verse de lado derecho")
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
		lowest_gap = minf(lowest_gap, p.y - _biome.surface_height_at(p.x, p.z))
	Input.action_release("run")
	Input.action_release("move_forward")
	Input.action_release("move_left")
	_check(lowest_gap > -0.2, "el jugador atravesó el terreno (holgura mínima %.2f m)" % lowest_gap)

	# Muros: tras 10 s corriendo en diagonal debe quedar dentro del bioma.
	var half := _biome.config.size * 0.5
	var p := _player.global_position
	_check(absf(p.x) < half and absf(p.z) < half, "el jugador salió del bioma (%.1f, %.1f)" % [p.x, p.z])

	# Props: corriendo contra un árbol no debe atravesarlo.
	var tree := _biome.get_node("Props/Tree0") as Node3D
	_player.global_position = tree.global_position + Vector3(-3.0, 0.5, 0.0)
	_player.velocity = Vector3.ZERO
	await _frames(20)
	Input.action_press("move_right")
	Input.action_press("run")
	await _frames(90)
	Input.action_release("run")
	Input.action_release("move_right")
	_check(_player.global_position.x < tree.global_position.x - 0.3, "el jugador atravesó un árbol")

	# Muro: corriendo hacia el borde debe detenerse antes del límite.
	_player.global_position = Vector3(half - 6.0, _biome.surface_height_at(half - 6.0, 0.0) + 0.5, 0.0)
	_player.velocity = Vector3.ZERO
	await _frames(20)
	Input.action_press("move_right")
	Input.action_press("run")
	await _frames(120)
	Input.action_release("run")
	Input.action_release("move_right")
	_check(_player.global_position.x < half, "el jugador cruzó el muro del borde (x=%.1f)" % _player.global_position.x)


func _terrain_faces_up() -> bool:
	var mesh := (_biome.get_node("Terrain").get_child(0) as MeshInstance3D).mesh
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
