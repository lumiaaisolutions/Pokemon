class_name Player
extends CharacterBody3D
## Entrenador en exploración: camina y corre relativo a la cámara activa.
## El sprite es un billboard en eje Y que alterna frente/espalda según hacia
## dónde se mueve respecto a la cámara, con rebote procedural al caminar.

@export var config: PlayerConfig

@onready var _sprite: Sprite3D = $Sprite

var _bob_phase: float = 0.0
var _facing_away: bool = true
var _sprite_base_y: float = 0.0


func _ready() -> void:
	_sprite.pixel_size = config.pixel_size
	_sprite.texture = config.texture_back
	# Pies en el origen del cuerpo.
	_sprite_base_y = config.texture_front.get_height() * config.pixel_size * 0.5
	_sprite.position.y = _sprite_base_y


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


func _update_sprite(horizontal: Vector3, delta: float) -> void:
	var speed := horizontal.length()
	if speed > 0.1:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			var to_camera := camera.global_position - global_position
			to_camera.y = 0.0
			_facing_away = horizontal.dot(to_camera) < 0.0
		_sprite.texture = config.texture_back if _facing_away else config.texture_front
		_bob_phase += delta * config.bob_frequency * TAU * (speed / config.walk_speed)
		_sprite.position.y = _sprite_base_y + absf(sin(_bob_phase)) * config.bob_height
	else:
		_bob_phase = 0.0
		_sprite.position.y = move_toward(_sprite.position.y, _sprite_base_y, delta)
