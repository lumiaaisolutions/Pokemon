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
## Aviso breve para el HUD (p. ej. la corriente que lo regresa en el mar abierto).
signal notice(text: String)

enum Mode { WALK, SWIM, DIVE, DOWNED }

## Profundidad de los pies al nadar en la superficie (la cabeza queda fuera).
const SWIM_SURFACE_DEPTH := 1.0
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
## Nate tirado en el suelo (sprite plano que cae hacia atrás) mientras está desmayado.
var _lying: Node3D
var _lying_sprite: Sprite3D
var _heal_sparkle: float = 0.0
var _downed_time: float = 0.0
## Compañero de tipo Agua sobre el que surfea (lo asigna la escena principal).
var riding: PokemonActor
const HURT_COLOR := Color(1.0, 0.3, 0.3)
var _since_damage: float = 0.0
var _hurt_tween: Tween
## Hoja overworld del personaje elegido.
var sheet: Texture2D
var _swim_time: float = 0.0
var _swim_bob: float = 0.0
var _splash_timer: float = 0.0
var _swim_shader_on := false


func _ready() -> void:
	add_to_group(WorldBuilder.GRASS_PUSHERS_GROUP)
	_sprite.step_cycle = PackedInt32Array([0, 1, 0, 2])
	_sprite.run_row_offset = 4
	_sprite.walk_fps = config.walk_fps
	_sprite.run_fps = config.run_fps
	# Hoja del personaje elegido (todas con el formato de Nate). Sin animación de
	# correr, corre con su caminar acelerado.
	sheet = PlayerCharacters.sheet(GameState.character_id)
	if not PlayerCharacters.find(GameState.character_id)["run"]:
		_sprite.run_row_offset = 0
		_sprite.run_fps = config.run_fps * 1.4
	_sprite.setup(sheet, config.hframes, config.vframes, config.pixel_size)
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
	var aiming := ($ThrowAim as ThrowAim).is_aiming() and not swimming
	var wants_run := Input.is_action_pressed("run") and input.length() > 0.1 and not swimming and not aiming
	var running := wants_run and not exhausted and stamina > 0.0
	_update_stamina(running, swimming and riding == null and input.length() > 0.1, delta)
	var target_speed := config.swim_speed if swimming else (config.run_speed if running else config.walk_speed)
	if swimming and riding != null:
		target_speed = config.swim_speed * config.surf_speed_factor
	if GameState.boost_active("speed"):
		target_speed *= 1.3
	if swimming and stamina <= 0.0:
		target_speed *= config.swim_exhausted_speed_factor
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
		_apply_sea_current(delta)
	elif is_on_floor():
		velocity.y = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity.y = config.jump_velocity
	else:
		velocity.y -= config.gravity * delta

	move_and_slide()
	_update_fall(swimming)
	_update_air(delta)
	_update_regen(delta)
	_sprite.animate(horizontal, delta, horizontal.length() > config.walk_speed + 0.5)
	_update_swim_visuals(horizontal, delta)
	if aiming:
		# Al apuntar, Nate mira hacia donde apunta la cámara.
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			_sprite.look_at_point(global_position - camera.global_basis.z)


## Nado: se mece en la superficie, bracea más lento, deja ondas y salpicaduras al
## avanzar y burbujas al bucear (no hay sprite de nado en B2W2).
## Nado generado (los personajes no traen sprites de nado): en la superficie solo se
## ve de la cintura para arriba, con brazadas (cuadros de caminar lentos) y balanceo;
## buceando se inclina como nadando de pecho, con burbujas. Surfeando va sentado sobre
## su compañero (se ocultan las piernas).
func _update_swim_visuals(horizontal: Vector3, delta: float) -> void:
	var swimming := mode == Mode.SWIM or mode == Mode.DIVE
	if not swimming:
		if _swim_bob != 0.0 or _swim_shader_on:
			_swim_bob = 0.0
			_swim_shader_on = false
			_sprite.place_on_ground()
			_sprite.set_instance_shader_parameter("cut_bottom", -1000.0)
			_sprite.set_instance_shader_parameter("extra_tilt", 0.0)
		_sprite.walk_fps = config.walk_fps
		return
	_swim_shader_on = true
	var level := _world.water_level_at(global_position.x, global_position.z)
	_swim_time += delta
	_sprite.place_on_ground()
	if riding != null:
		_swim_bob = sin(_swim_time * 2.0) * 0.04
		_sprite.position.y += config.surf_seat_height + _swim_bob
		_sprite.set_instance_shader_parameter("cut_bottom", 0.45)
		_sprite.set_instance_shader_parameter("extra_tilt", 0.0)
	else:
		_sprite.walk_fps = config.walk_fps * 0.55
		_swim_bob = sin(_swim_time * 3.0) * 0.07
		_sprite.position.y += _swim_bob
		if mode == Mode.SWIM:
			# Lo que queda bajo la superficie no se dibuja.
			_sprite.set_instance_shader_parameter("cut_bottom", level - global_position.y - _swim_bob)
			_sprite.set_instance_shader_parameter("extra_tilt", 0.0)
		else:
			_sprite.set_instance_shader_parameter("cut_bottom", -1000.0)
			var moving := horizontal.length() > 0.3
			_sprite.set_instance_shader_parameter("extra_tilt", 1.1 if moving else 0.35)
	_splash_timer -= delta
	if _splash_timer > 0.0:
		return
	if mode == Mode.DIVE:
		_splash_timer = 0.5
		PixelBurst.spawn(get_parent(), global_position + Vector3.UP * 1.4, PixelBurst.Kind.BUBBLES, 0.6)
	elif horizontal.length() > 0.3:
		_splash_timer = 0.35
		PixelBurst.spawn(get_parent(), Vector3(global_position.x, level, global_position.z), PixelBurst.Kind.SPLASH, 0.45)


## Velocidad horizontal actual (la usan las pruebas y, más adelante, la UI y el audio).
func get_ground_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Resta vida (en medios corazones). A 0, queda desmayado.
func take_damage(amount: float) -> void:
	if mode == Mode.DOWNED or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health)
	_hurt_flash()
	_since_damage = 0.0
	if health <= 0.0:
		_go_down()


## Descanso: tras un rato sin daño (y con aire), la vida sube poco a poco.
func _update_regen(delta: float) -> void:
	_since_damage += delta
	if _since_damage < config.health_regen_delay or health >= config.health_max or air < config.air_max:
		return
	heal(config.health_regen * delta)


## Se pinta de rojo y parpadea un momento al recibir daño (como en Minecraft).
func _hurt_flash() -> void:
	if _hurt_tween != null and _hurt_tween.is_valid():
		_hurt_tween.kill()
	_sprite.modulate = HURT_COLOR
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.12).set_delay(0.12)
	_hurt_tween.tween_property(_sprite, "modulate", HURT_COLOR, 0.06)
	_hurt_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.18)


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
	_downed_time += delta
	health = minf(health + config.health_max / downed_duration() * delta, config.health_max)
	health_changed.emit(health)
	# Respira (sube y baja un poco) y suelta destellos de curación.
	if _lying_sprite != null:
		_lying_sprite.scale = Vector3.ONE * (1.0 + 0.03 * sin(_downed_time * 3.0))
	# Solo las estrellitas sobre la cabeza (sin nubes de curación mientras está en el suelo).
	if health >= config.health_max:
		_get_up()


## Segundos que tarda en recuperarse del desmayo (según la dificultad).
func downed_duration() -> float:
	return config.downed_duration * GameState.difficulty_value("recovery")


## Se levanta: el sprite plano vuelve a quedar de pie y suelta un destello.
func _get_up() -> void:
	mode = Mode.WALK
	if _downed_stars != null:
		_downed_stars.queue_free()
		_downed_stars = null
	if _lying != null:
		var tween := create_tween()
		tween.tween_property(_lying, "rotation:x", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tween.finished
	_set_downed_visuals(false)
	PixelBurst.spawn(get_parent(), global_position + Vector3.UP * 0.8, PixelBurst.Kind.HEAL, 1.6)
	revived.emit()


## Desmayado: cae de espaldas al suelo (sprite plano mirando a la cámara), con
## estrellitas girando sobre la cabeza. off lo deja otra vez de pie al instante.
func _set_downed_visuals(on: bool) -> void:
	if _downed_stars != null:
		_downed_stars.queue_free()
		_downed_stars = null
	if _lying != null:
		_lying.queue_free()
		_lying = null
		_lying_sprite = null
	_sprite.visible = not on
	_sprite.modulate = Color.WHITE
	if not on:
		return
	_downed_time = 0.0
	_heal_sparkle = 0.0
	_lying = Node3D.new()
	add_child(_lying)
	# El eje +Z del pivote apunta a la cámara: al girar en X cae hacia atrás y
	# queda boca arriba, visible desde la cámara.
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var to_camera := camera.global_position - global_position
		to_camera.y = 0.0
		if to_camera.length() > 0.01:
			_lying.global_basis = Basis.looking_at(-to_camera.normalized(), Vector3.UP)
	_lying_sprite = Sprite3D.new()
	_lying_sprite.texture = sheet
	_lying_sprite.hframes = config.hframes
	_lying_sprite.vframes = config.vframes
	_lying_sprite.frame = 0
	_lying_sprite.pixel_size = config.pixel_size
	_lying_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_lying_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_lying_sprite.shaded = false
	_lying_sprite.double_sided = true
	_lying_sprite.modulate = Color(0.85, 0.85, 0.95)
	_lying_sprite.layers = 2
	_lying_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cell_height := sheet.get_height() / float(config.vframes)
	_lying_sprite.position = Vector3(0.0, cell_height * 0.5 * config.pixel_size, 0.0)
	_lying.add_child(_lying_sprite)
	_lying.position.y = 0.06
	var tween := create_tween()
	tween.tween_property(_lying, "rotation:x", -PI * 0.47, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	PixelBurst.spawn(get_parent(), global_position + Vector3.UP * 0.1, PixelBurst.Kind.DUST, 0.8)
	# Estrellitas sobre la cabeza (que quedó atrás, en el suelo).
	_downed_stars = DizzyStars.create(0.45)
	add_child(_downed_stars)
	var head := _lying.global_basis * Vector3(0.0, 0.0, -cell_height * config.pixel_size * 0.75)
	_downed_stars.position = Vector3(head.x, 0.45, head.z)


func _update_water_mode() -> void:
	if _world == null:
		return
	var depth := _world.water_depth_at(global_position.x, global_position.z)
	if depth > config.swim_depth:
		if mode == Mode.WALK:
			mode = Mode.SWIM
	elif mode != Mode.WALK:
		mode = Mode.WALK


## Metros antes del borde del mundo donde empieza la corriente del mar abierto.
const CURRENT_MARGIN := 30.0
const CURRENT_STRENGTH := 9.0
var _current_notice: float = 0.0


## Mar abierto: cerca del borde, una corriente lo regresa hacia la costa.
func _apply_sea_current(delta: float) -> void:
	_current_notice = maxf(_current_notice - delta, 0.0)
	if _world == null:
		return
	var half := _world.config.size * 0.5 - CURRENT_MARGIN
	var push := Vector3.ZERO
	if global_position.z > half:
		push.z = -1.0
	if absf(global_position.x) > half:
		push.x = -signf(global_position.x)
	if push == Vector3.ZERO:
		return
	velocity += push.normalized() * CURRENT_STRENGTH * delta * 10.0
	if _current_notice <= 0.0:
		_current_notice = 6.0
		notice.emit("La corriente es muy fuerte... no puedes ir más lejos.")


## Movimiento vertical en el agua: se hunde poco a poco solo; mantener "jump" lo
## mantiene a flote o lo sube, y "dive" lo baja más rápido. Surfeando no se hunde.
func _swim_vertical(delta: float) -> float:
	var level := _world.water_level_at(global_position.x, global_position.z)
	var surface_y := level - SWIM_SURFACE_DEPTH
	var floor_y := _world.surface_height_at(global_position.x, global_position.z) + 0.2
	if riding != null:
		mode = Mode.SWIM
		return (level - 0.15 - global_position.y) / maxf(delta, 0.001)
	if Input.is_action_pressed("dive"):
		mode = Mode.DIVE
		return -config.dive_speed if global_position.y > floor_y else 0.0
	if Input.is_action_pressed("jump"):
		if global_position.y < surface_y - 0.05:
			return config.dive_speed * 1.6
		mode = Mode.SWIM
		return (surface_y - global_position.y) / maxf(delta, 0.001)
	# Sin mantener a flote: se hunde despacio (bucea cuando la cabeza queda bajo el agua).
	mode = Mode.SWIM if global_position.y > surface_y - 0.6 else Mode.DIVE
	return -config.sink_speed if global_position.y > floor_y else 0.0


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
		# Nadar cansa poco; sin stamina nada más lento.
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
