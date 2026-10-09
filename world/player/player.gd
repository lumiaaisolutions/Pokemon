class_name Player
extends CharacterBody3D
## Entrenador en exploración: camina y corre relativo a la cámara activa.
## El sprite es un billboard en eje Y con hoja overworld (4 direcciones, caminar
## y correr). La fila se elige según la dirección de mirada respecto a la cámara,
## así que al orbitar la cámara alrededor del jugador también cambia su lado visible.

enum Facing { DOWN, LEFT, RIGHT, UP }

## Ciclo de pasos: parado, paso A, parado, paso B.
const STEP_CYCLE: Array[int] = [0, 1, 0, 2]

@export var config: PlayerConfig

@onready var _sprite: Sprite3D = $Sprite

## Hacia dónde mira el jugador en el mundo (horizontal, normalizado).
var _facing_world := Vector3.FORWARD
var _anim_time: float = 0.0


func _ready() -> void:
	_sprite.texture = config.sheet
	_sprite.hframes = config.hframes
	_sprite.vframes = config.vframes
	_sprite.pixel_size = config.pixel_size
	# Pies en el origen del cuerpo: la celda tiene los pies en su borde inferior.
	var cell_height := config.sheet.get_height() / float(config.vframes)
	_sprite.position.y = cell_height * config.pixel_size * 0.5
	_update_sprite(Vector3.ZERO, 0.0)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera_relative(input)
	var running := Input.is_action_pressed("run")
	var target_speed := config.run_speed if running else config.walk_speed
	# Con stick analógico, la velocidad escala con la inclinación.
	var target := direction * target_speed * minf(input.length(), 1.0)

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := config.acceleration if target.length() > horizontal.length() else config.deceleration
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= config.gravity * delta

	move_and_slide()
	_update_sprite(horizontal, delta)


## Velocidad horizontal actual (la usan las pruebas y, más adelante, la UI y el audio).
func get_ground_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _camera_relative(input: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var forward := Vector3.FORWARD
	if camera != null:
		forward = -camera.global_basis.z
		forward.y = 0.0
		if forward.length_squared() < 0.0001:
			forward = Vector3.FORWARD
		forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var direction := right * input.x - forward * input.y
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.ZERO


## Fila de dirección visible ahora (Facing), según la cámara. La usan las pruebas.
func get_visible_facing() -> Facing:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Facing.UP
	var forward := -camera.global_basis.z
	forward.y = 0.0
	var right := camera.global_basis.x
	right.y = 0.0
	var along := _facing_world.dot(forward.normalized())
	var side := _facing_world.dot(right.normalized())
	if absf(side) > absf(along):
		return Facing.RIGHT if side > 0.0 else Facing.LEFT
	return Facing.UP if along > 0.0 else Facing.DOWN


func _update_sprite(horizontal: Vector3, delta: float) -> void:
	var speed := horizontal.length()
	var moving := speed > 0.1
	if moving:
		_facing_world = horizontal / speed
	var running := speed > config.walk_speed + 0.5
	var row := int(get_visible_facing()) + (4 if running else 0)
	var column := 0
	if moving:
		_anim_time += delta * (config.run_fps if running else config.walk_fps)
		column = STEP_CYCLE[int(_anim_time) % STEP_CYCLE.size()]
	else:
		_anim_time = 0.0
	_sprite.frame = row * config.hframes + column
