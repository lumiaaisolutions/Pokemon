class_name Player
extends CharacterBody3D
## Entrenador en exploración: camina, corre (con stamina) y salta relativo a la
## cámara; nada en la superficie y bucea con aire limitado; tiene vida (corazones)
## que pierde por ataques, caídas desde altura y al ahogarse. Al llegar a 0 queda
## desmayado mientras se recupera (su compañero lo protege, ver la Fase 2.8).
## El sprite es un DirectionalSprite con la hoja overworld de Nate (caminar y correr).

signal health_changed(health: float)
## Vida en 0: queda en el suelo recuperándose.
signal downed
## Se levantó tras recuperarse.
signal revived
## Desmayo definitivo (p. ej. su compañero cayó, o se ahogó): pantalla negra y reaparición.
signal blacked_out

enum Mode { WALK, SWIM, DIVE, DOWNED }

## Velocidad al caminar mientras apunta (fracción de la normal).
const AIM_SPEED_FACTOR := 0.6

@export var config: PlayerConfig

@onready var _sprite: DirectionalSprite = $Sprite

var mode: Mode = Mode.WALK
var health: float = 20.0
var stamina: float = 100.0
## Segundos de aire que le quedan bajo el agua.
var air: float = 15.0
## Agotado: no puede correr hasta recuperar stamina_recover_ratio.
var exhausted := false
var _since_run: float = 0.0
var _world: WorldBuilder
## Altura más alta desde que dejó el suelo (para el daño por caída).
var _air_peak_y: float = 0.0
var _was_on_floor := true
var _drown_tick: float = 0.0
var _downed_stars: Node3D


func _ready() -> void:
	add_to_group(WorldBuilder.GRASS_PUSHERS_GROUP)
	_sprite.step_cycle = PackedInt32Array([0, 1, 0, 2])
	_sprite.run_row_offset = 4
	_sprite.walk_fps = config.walk_fps
	_sprite.run_fps = config.run_fps
	_sprite.setup(config.sheet, config.hframes, config.vframes, config.pixel_size)
	_sprite.animate(Vector3.ZERO, 0.0)
	stamina = config.stamina_max
	health = config.health_max
	air = config.air_max
	_world = get_tree().get_first_node_in_group(WorldBuilder.WORLD_GROUP) as WorldBuilder


func _physics_process(delta: float) -> void:
	if mode == Mode.DOWNED:
		_process_downed(delta)
		return
	_update_water_mode()
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera_relative(input)
	var swimming := mode == Mode.SWIM or mode == Mode.DIVE
	var aiming := Input.is_action_pressed("aim") and not swimming
	var wants_run := Input.is_action_pressed("run") and input.length() > 0.1 and not swimming and not aiming
	var running := wants_run and not exhausted and stamina > 0.0
	_update_stamina(running, swimming, delta)
	var target_speed := config.swim_speed if swimming else (config.run_speed if running else config.walk_speed)
	if aiming:
		target_speed = config.walk_speed * AIM_SPEED_FACTOR
	# Con stick analógico, la velocidad escala con la inclinación.
	var target := direction * target_speed * minf(input.length(), 1.0)

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := config.acceleration if target.length() > horizontal.length() else config.deceleration
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if swimming:
		velocity.y = _swim_vertical(delta)
	elif is_on_floor():
		velocity.y = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity.y = config.jump_velocity
	else:
		velocity.y -= config.gravity * delta

	move_and_slide()
	_update_fall(swimming)
	_update_air(delta)
	_sprite.animate(horizontal, delta, horizontal.length() > config.walk_speed + 0.5)
	if aiming:
		# Al apuntar, Nate mira hacia donde apunta la cámara.
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			_sprite.look_at_point(global_position - camera.global_basis.z)


## Velocidad horizontal actual (la usan las pruebas y, más adelante, la UI y el audio).
func get_ground_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Resta vida (en medios corazones). A 0, queda desmayado.
func take_damage(amount: float) -> void:
	if mode == Mode.DOWNED or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health)
	if health <= 0.0:
		_go_down()


func heal(amount: float) -> void:
	health = minf(health + amount, config.health_max)
	health_changed.emit(health)


## Reaparece con todo lleno (lo llama la escena principal tras la pantalla negra).
func respawn_at(point: Vector3) -> void:
	global_position = point
	velocity = Vector3.ZERO
	health = config.health_max
	air = config.air_max
	stamina = config.stamina_max
	exhausted = false
	mode = Mode.WALK
	_set_downed_visuals(false)
	health_changed.emit(health)


## Desmayo definitivo (p. ej. cuando su compañero cae al protegerlo).
func black_out() -> void:
	blacked_out.emit()


func _go_down() -> void:
	velocity = Vector3.ZERO
	# Bajo el agua no hay quien lo proteja: desmayo definitivo.
	if _world != null and _world.water_depth_at(global_position.x, global_position.z) > config.swim_depth:
		black_out()
		return
	mode = Mode.DOWNED
	_set_downed_visuals(true)
	downed.emit()


func _process_downed(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = 0.0 if is_on_floor() else velocity.y - config.gravity * delta
	move_and_slide()
	health = minf(health + config.health_max / config.downed_duration * delta, config.health_max)
	health_changed.emit(health)
	if health >= config.health_max:
		mode = Mode.WALK
		_set_downed_visuals(false)
		revived.emit()


## Estrellitas girando sobre la cabeza mientras está desmayado.
func _set_downed_visuals(on: bool) -> void:
	if _downed_stars != null:
		_downed_stars.queue_free()
		_downed_stars = null
	_sprite.modulate = Color(0.7, 0.7, 0.8) if on else Color.WHITE
	if not on:
		return
	_downed_stars = DizzyStars.create(1.9)
	add_child(_downed_stars)


func _update_water_mode() -> void:
	if _world == null:
		return
	var depth := _world.water_depth_at(global_position.x, global_position.z)
	if depth > config.swim_depth:
		if mode == Mode.WALK:
			mode = Mode.SWIM
	elif mode != Mode.WALK:
		mode = Mode.WALK


## Movimiento vertical en el agua: flota con la cabeza fuera, o bucea con "dive".
## Sin stamina se hunde. Saltar sube a la superficie.
func _swim_vertical(delta: float) -> float:
	var level := _world.water_level_at(global_position.x, global_position.z)
	var surface_y := level - 1.0
	var floor_y := _world.surface_height_at(global_position.x, global_position.z) + 0.2
	var sinking := stamina <= 0.0
	if Input.is_action_pressed("dive") or sinking:
		mode = Mode.DIVE
		return -config.dive_speed if global_position.y > floor_y else 0.0
	if global_position.y < surface_y - 0.05:
		# Bajo la superficie sin bucear: sube (más rápido si salta).
		return config.dive_speed * (1.5 if Input.is_action_pressed("jump") else 1.0)
	mode = Mode.SWIM
	return (surface_y - global_position.y) / maxf(delta, 0.001)


## Aire: se gasta con la cabeza bajo el agua y se recupera al salir; sin aire, daño.
func _update_air(delta: float) -> void:
	var head_under := false
	if _world != null:
		head_under = global_position.y + 1.5 < _world.water_level_at(global_position.x, global_position.z)
	if head_under:
		air = maxf(air - delta, 0.0)
		if air <= 0.0:
			_drown_tick += delta
			if _drown_tick >= 1.0:
				_drown_tick = 0.0
				take_damage(config.drown_damage_per_second)
	else:
		air = minf(air + config.air_refill * delta, config.air_max)
		_drown_tick = 0.0


## Daño por caída: se mide desde lo más alto que llegó en el aire.
func _update_fall(swimming: bool) -> void:
	var on_floor := is_on_floor()
	if swimming:
		_air_peak_y = global_position.y
	elif not on_floor:
		_air_peak_y = global_position.y if _was_on_floor else maxf(_air_peak_y, global_position.y)
	elif not _was_on_floor:
		var drop := _air_peak_y - global_position.y
		if drop > config.fall_safe_height:
			take_damage((drop - config.fall_safe_height) * config.fall_damage_per_meter)
	_was_on_floor = on_floor or swimming


func _update_stamina(running: bool, swimming: bool, delta: float) -> void:
	if running:
		stamina = maxf(stamina - config.stamina_drain * delta, 0.0)
		_since_run = 0.0
		if stamina <= 0.0:
			exhausted = true
	elif swimming:
		# Nadar cansa: sin stamina se hunde (ver _swim_vertical).
		stamina = maxf(stamina - config.swim_stamina_drain * delta, 0.0)
		_since_run = 0.0
	else:
		_since_run += delta
		if _since_run >= config.stamina_regen_delay:
			stamina = minf(stamina + config.stamina_regen * delta, config.stamina_max)
	if exhausted and stamina >= config.stamina_max * config.stamina_recover_ratio:
		exhausted = false


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
