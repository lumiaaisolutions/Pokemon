class_name Player
extends CharacterBody3D
## Entrenador en exploración: camina y corre relativo a la cámara activa.
## El sprite es un DirectionalSprite con la hoja overworld de Nate (caminar y correr).

@export var config: PlayerConfig

@onready var _sprite: DirectionalSprite = $Sprite


func _ready() -> void:
	add_to_group(BiomeBuilder.GRASS_PUSHERS_GROUP)
	_sprite.step_cycle = PackedInt32Array([0, 1, 0, 2])
	_sprite.run_row_offset = 4
	_sprite.walk_fps = config.walk_fps
	_sprite.run_fps = config.run_fps
	_sprite.setup(config.sheet, config.hframes, config.vframes, config.pixel_size)
	_sprite.animate(Vector3.ZERO, 0.0)


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
	_sprite.animate(horizontal, delta, horizontal.length() > config.walk_speed + 0.5)


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


## Dirección visible ahora según la cámara. La usan las pruebas.
func get_visible_facing() -> DirectionalSprite.Facing:
	return _sprite.visible_facing()
