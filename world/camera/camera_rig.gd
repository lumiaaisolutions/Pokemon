class_name CameraRig
extends Node3D
## Cámara de exploración en tercera persona elevada.
## Jerarquía: CameraRig (sigue al objetivo, gira en yaw) > Pitch > SpringArm3D > Camera3D.
## Mouse: clic para capturar el cursor, Esc para liberarlo.

@export var target_path: NodePath
@export_group("Ángulos")
## Inclinación hacia abajo en grados: negativo mira hacia arriba (cielo), 80 casi cenital.
@export_range(-30.0, 89.0) var pitch_min_deg: float = -20.0
@export_range(-30.0, 89.0) var pitch_max_deg: float = 80.0
@export var mouse_sensitivity: float = 0.15
## Grados por segundo con el stick derecho o las flechas.
@export var stick_speed_deg: float = 150.0
@export_group("Zoom")
@export var zoom_min: float = 4.0
@export var zoom_max: float = 11.0
@export var zoom_step: float = 1.0
@export var zoom_smoothing: float = 10.0
@export_group("Apuntar")
## Al apuntar: cámara sobre el hombro, más cerca y casi horizontal.
@export var aim_zoom: float = 2.8
@export var aim_pitch_deg: float = 6.0
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
var _zoom: float = 7.0


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
	elif event.is_action_pressed("menu"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw_deg -= motion.relative.x * mouse_sensitivity
		_pitch_deg = clampf(_pitch_deg + motion.relative.y * mouse_sensitivity, pitch_min_deg, pitch_max_deg)
	elif event.is_action_pressed("zoom_in"):
		_zoom = clampf(_zoom - zoom_step, zoom_min, zoom_max)
	elif event.is_action_pressed("zoom_out"):
		_zoom = clampf(_zoom + zoom_step, zoom_min, zoom_max)


func _process(delta: float) -> void:
	var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	_yaw_deg -= look.x * stick_speed_deg * delta
	_pitch_deg = clampf(_pitch_deg + look.y * stick_speed_deg * 0.6 * delta, pitch_min_deg, pitch_max_deg)
	_apply_rotation()

	_aim_blend = move_toward(_aim_blend, 1.0 if aiming else 0.0, aim_blend_speed * delta)
	var zoom := lerpf(_zoom, aim_zoom, _aim_blend)
	_arm.spring_length = lerpf(_arm.spring_length, zoom, 1.0 - exp(-zoom_smoothing * delta))
	if _target != null:
		# Sobre el hombro derecho al apuntar.
		var shoulder := global_basis.x * aim_shoulder * _aim_blend
		global_position = global_position.lerp(_focus_point() + shoulder, 1.0 - exp(-follow_smoothing * delta))


## Pitch actual en grados (hacia abajo). Lo usan las pruebas.
func get_pitch_deg() -> float:
	return _pitch_deg


func _apply_rotation() -> void:
	rotation_degrees.y = _yaw_deg
	_pitch.rotation_degrees.x = -lerpf(_pitch_deg, aim_pitch_deg, _aim_blend)


func _focus_point() -> Vector3:
	return _target.global_position + Vector3.UP * focus_height
