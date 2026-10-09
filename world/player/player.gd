class_name Player
extends CharacterBody3D
## Entrenador en exploración: camina y corre relativo a la cámara activa.
## El sprite es un DirectionalSprite con la hoja overworld de Nate (caminar y correr).

@export var config: PlayerConfig

## Agua desde la que Nate no puede seguir avanzando.
const DEEP_WATER := 0.6

@onready var _sprite: DirectionalSprite = $Sprite

var stamina: float = 100.0
## Agotado: no puede correr hasta recuperar stamina_recover_ratio.
var exhausted := false
var _since_run: float = 0.0
var _world: WorldBuilder


func _ready() -> void:
	add_to_group(WorldBuilder.GRASS_PUSHERS_GROUP)
	_sprite.step_cycle = PackedInt32Array([0, 1, 0, 2])
	_sprite.run_row_offset = 4
	_sprite.walk_fps = config.walk_fps
	_sprite.run_fps = config.run_fps
	_sprite.setup(config.sheet, config.hframes, config.vframes, config.pixel_size)
	_sprite.animate(Vector3.ZERO, 0.0)
	stamina = config.stamina_max
	_world = get_tree().get_first_node_in_group(WorldBuilder.WORLD_GROUP) as WorldBuilder


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera_relative(input)
	var wants_run := Input.is_action_pressed("run") and input.length() > 0.1
	var running := wants_run and not exhausted and stamina > 0.0
	_update_stamina(running, delta)
	var target_speed := config.run_speed if running else config.walk_speed
	# Con stick analógico, la velocidad escala con la inclinación.
	var target := direction * target_speed * minf(input.length(), 1.0)

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := config.acceleration if target.length() > horizontal.length() else config.deceleration
	horizontal = horizontal.move_toward(target, rate * delta)
	horizontal = _block_deep_water(horizontal, delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= config.gravity * delta

	move_and_slide()
	_sprite.animate(horizontal, delta, horizontal.length() > config.walk_speed + 0.5)


func _update_stamina(running: bool, delta: float) -> void:
	if running:
		stamina = maxf(stamina - config.stamina_drain * delta, 0.0)
		_since_run = 0.0
		if stamina <= 0.0:
			exhausted = true
	else:
		_since_run += delta
		if _since_run >= config.stamina_regen_delay:
			stamina = minf(stamina + config.stamina_regen * delta, config.stamina_max)
	if exhausted and stamina >= config.stamina_max * config.stamina_recover_ratio:
		exhausted = false


## No deja entrar al agua profunda (sí salir de ella).
func _block_deep_water(horizontal: Vector3, delta: float) -> Vector3:
	if _world == null:
		return horizontal
	var next := global_position + horizontal * delta * 4.0
	var depth_next := _world.water_depth_at(next.x, next.z)
	if depth_next > DEEP_WATER and depth_next > _world.water_depth_at(global_position.x, global_position.z):
		return Vector3.ZERO
	return horizontal


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
