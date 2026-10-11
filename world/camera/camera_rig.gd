class_name CameraRig
extends Node3D
## Cámara de exploración en tercera persona elevada.
## Jerarquía: CameraRig (sigue al objetivo, gira en yaw) > Pitch > SpringArm3D > Camera3D.
## Mouse: clic para capturar el cursor, Esc para liberarlo.
## El SpringArm (ver camera_rig.tscn) solo choca con terreno, frontera y la capa de
## cámara (edificios y monumentos grandes, WorldBuilder.LAYER_CAMERA): el mobiliario
## pequeño (bancas, macetas, cercas, faroles, puestos, cajas, ver Structures._collider y
## _cylinder_collider) no lleva esa capa a propósito, para que la cámara no se pegue de
## golpe al tropezar con un objeto chico (reportado por Fernando el 2026-10-10).

@export var target_path: NodePath
@export_group("Ángulos")
## Inclinación hacia abajo en grados: negativo mira hacia arriba (cielo), 80 casi cenital.
@export_range(-30.0, 89.0) var pitch_min_deg: float = -20.0
## 70°: más arriba los sprites se verían de canto (para ver todo desde arriba está el mapa).
@export_range(-30.0, 89.0) var pitch_max_deg: float = 70.0
@export var mouse_sensitivity: float = 0.15
## Grados por segundo con el stick derecho o las flechas.
@export var stick_speed_deg: float = 150.0
@export_group("Zoom")
@export var zoom_min: float = 4.0
@export var zoom_max: float = 11.0
@export var zoom_step: float = 1.0
@export var zoom_smoothing: float = 10.0
@export_group("Apuntar")
## Al apuntar: cámara sobre el hombro, más cerca; la inclinación es libre (para
## lanzar hacia arriba, lejos o cerca) y empieza casi horizontal.
@export var aim_zoom: float = 2.8
@export var aim_pitch_deg: float = 6.0
## Límites de la inclinación al apuntar (negativo = hacia el cielo).
@export var aim_pitch_min_deg: float = -50.0
@export var aim_pitch_max_deg: float = 45.0
@export var aim_shoulder: float = 0.8
@export var aim_blend_speed: float = 10.0

@export_group("Seguimiento")
@export var follow_smoothing: float = 12.0
## Altura del punto al que mira la cámara sobre los pies del objetivo.
@export var focus_height: float = 1.2

@onready var _pitch: Node3D = $Pitch
@onready var _arm: SpringArm3D = $Pitch/SpringArm

const CAMERA_GROUP := &"camera_rig"

## Apuntando (lo activa el jugador al mantener "aim").
var aiming := false
var _target: Node3D
var _aim_blend: float = 0.0
var _yaw_deg: float = 0.0
var _pitch_deg: float = 30.0
var _aim_pitch_deg: float = 6.0
var _zoom: float = 7.0
## Temblor (0–1) de los ataques fuertes; se apaga solo (ver shake()).
var _shake := 0.0
var _shake_rng := RandomNumberGenerator.new()
## Mirar al cielo (bandadas migratorias, decisión de Fernando 2026-10-10): la cámara se
## levanta sola unos segundos y vuelve; moverla lo cancela (ver look_at_sky()).
const SKY_PITCH_DEG := -16.0
const SKY_BLEND_SPEED := 1.6
var _sky_time := 0.0
var _sky_blend := 0.0


func _ready() -> void:
	add_to_group(CAMERA_GROUP)
	top_level = true
	_target = get_node_or_null(target_path) as Node3D
	if _target is CollisionObject3D:
		# El brazo no debe chocar con el propio jugador.
		_arm.add_excluded_object((_target as CollisionObject3D).get_rid())
	if _target != null:
		global_position = _focus_point()
	_pitch_deg = clampf(_pitch_deg, pitch_min_deg, pitch_max_deg)
	_arm.spring_length = _zoom
	_apply_rotation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sensitivity := GameOptions.mouse_sensitivity
		_yaw_deg -= motion.relative.x * sensitivity
		if motion.relative.length() > 4.0:
			_sky_time = 0.0
		_tilt(motion.relative.y * sensitivity * (-1.0 if GameOptions.invert_y else 1.0))
	elif event.is_action_pressed("zoom_in"):
		# En el mando solo hay un botón de zoom: al llegar al más cercano vuelve al más lejano.
		if event is InputEventJoypadButton and _zoom <= zoom_min + 0.01:
			_zoom = zoom_max
		else:
			_zoom = clampf(_zoom - zoom_step, zoom_min, zoom_max)
	elif event.is_action_pressed("zoom_out"):
		_zoom = clampf(_zoom + zoom_step, zoom_min, zoom_max)


func _process(delta: float) -> void:
	var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	var stick := GameOptions.stick_speed
	_yaw_deg -= look.x * stick * delta
	_tilt(look.y * stick * 0.6 * delta * (-1.0 if GameOptions.invert_y else 1.0))
	if look.length() > 0.3:
		_sky_time = 0.0
	_sky_time = maxf(_sky_time - delta, 0.0)
	_sky_blend = move_toward(_sky_blend, 1.0 if _sky_time > 0.0 and not aiming else 0.0, SKY_BLEND_SPEED * delta)
	_apply_rotation()

	if aiming and _aim_blend <= 0.0:
		_aim_pitch_deg = aim_pitch_deg
	_aim_blend = move_toward(_aim_blend, 1.0 if aiming else 0.0, aim_blend_speed * delta)
	var zoom := lerpf(_zoom, aim_zoom, _aim_blend)
	_arm.spring_length = lerpf(_arm.spring_length, zoom, 1.0 - exp(-zoom_smoothing * delta))
	if _target != null:
		# Sobre el hombro derecho al apuntar.
		var shoulder := global_basis.x * aim_shoulder * _aim_blend
		global_position = global_position.lerp(_focus_point() + shoulder, 1.0 - exp(-follow_smoothing * delta))
	_update_shake(delta)


## La cámara mira al cielo durante seconds (y vuelve sola); moverla lo cancela.
func look_at_sky(seconds: float) -> void:
	_sky_time = seconds


func looking_at_sky() -> bool:
	return _sky_time > 0.0


## Temblor de cámara (Terremoto, Llamarada, Hiperrayo, críticos…). strength 0–1.
func shake(strength: float) -> void:
	_shake = clampf(maxf(_shake, strength), 0.0, 1.0)


func _update_shake(delta: float) -> void:
	var camera := _arm.get_child(0) as Camera3D if _arm.get_child_count() > 0 else null
	if camera == null:
		return
	if _shake <= 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		return
	var amount := _shake * _shake * 0.35
	camera.h_offset = _shake_rng.randf_range(-amount, amount)
	camera.v_offset = _shake_rng.randf_range(-amount, amount)
	_shake = maxf(_shake - delta * 1.6, 0.0)


## Inclina la cámara: al apuntar mueve la mira (libre), si no la vista normal.
func _tilt(degrees: float) -> void:
	if aiming:
		_aim_pitch_deg = clampf(_aim_pitch_deg + degrees, aim_pitch_min_deg, aim_pitch_max_deg)
	else:
		_pitch_deg = clampf(_pitch_deg + degrees, pitch_min_deg, pitch_max_deg)


## Cambia a quién sigue la cámara (p. ej. al compañero mientras Nate está desmayado).
func set_target(node: Node3D) -> void:
	if _target is CollisionObject3D:
		_arm.remove_excluded_object((_target as CollisionObject3D).get_rid())
	_target = node
	if _target is CollisionObject3D:
		_arm.add_excluded_object((_target as CollisionObject3D).get_rid())


## Coloca la cámara de golpe sobre su objetivo (teletransportes, interiores). También el
## zoom de golpe (bug encontrado el 2026-10-11 con las capturas de la Tienda y el
## Centro: _arm.spring_length solo se acercaba al zoom nuevo poco a poco en _process, así
## que justo al entrar la cámara quedaba un instante con la distancia de afuera y el
## ángulo de la sala, a veces metida en el piso o muy cerca de él).
func snap() -> void:
	if _target != null:
		global_position = _focus_point()
	_arm.spring_length = _zoom
	# El yaw y el pitch (p. ej. _set_indoor_look reiniciando el yaw al entrar a un
	# interior) también deben verse ya en este mismo cuadro, no hasta el próximo
	# _process (si no, el primer cuadro adentro aún mostraba el ángulo/dirección de
	# afuera, a veces una pared en vez del cuarto completo).
	_apply_rotation()


## Pitch actual en grados (hacia abajo). Lo usan las pruebas.
func get_pitch_deg() -> float:
	return _pitch_deg


func _apply_rotation() -> void:
	rotation_degrees.y = _yaw_deg
	var pitch := lerpf(_pitch_deg, SKY_PITCH_DEG, smoothstep(0.0, 1.0, _sky_blend))
	_pitch.rotation_degrees.x = -lerpf(pitch, _aim_pitch_deg, _aim_blend)


func _focus_point() -> Vector3:
	return _target.global_position + Vector3.UP * focus_height
