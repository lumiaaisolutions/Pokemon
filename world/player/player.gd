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
## Cómo se desplaza en tierra: a pie, en bicicleta, montando a su compañero o volando sobre él.
enum Ride { NONE, BIKE, MOUNT, FLY }

const BIKE_SPEED_FACTOR := 1.5
## En caminos y pueblos la bicicleta rinde más.
const BIKE_ROAD_FACTOR := 2.0
## Pendiente máxima que suben los escaladores (Roca y Tierra) montados.
const CLIMB_MAX_ANGLE := 68.0
const FLY_SPEED := 15.0
const FLY_FAST_SPEED := 24.0
const FLY_CLIMB := 7.0
## Altura máxima de vuelo sobre el nivel del mar.
const FLY_CEILING := 260.0
## Para bajarse volando hay que estar a menos de esta altura del suelo.
const LAND_HEIGHT := 3.0

## Profundidad de los pies al nadar en la superficie (la cabeza queda fuera).
const SWIM_SURFACE_DEPTH := 1.0
## Velocidad al caminar mientras apunta (fracción de la normal).
const AIM_SPEED_FACTOR := 0.6
## Esquiva de Nate en combate (Fase 4): mientras apuntas, "dodge" lo lanza de lado o
## hacia atrás; durante la esquiva no recibe daño.
const DODGE_SPEED := 12.0
const DODGE_TIME := 0.3
const DODGE_COOLDOWN := 0.8

@export var config: PlayerConfig

@onready var _sprite: DirectionalSprite = $Sprite

var mode: Mode = Mode.WALK
var ride: Ride = Ride.NONE
## Compañero que monta (en tierra o en el aire).
var mount: PokemonActor
var _bike: Sprite3D
var _default_floor_angle := -1.0
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
var _dodge_left := 0.0
var _dodge_cooldown := 0.0
var _dodge_direction := Vector3.ZERO
const HURT_COLOR := Color(1.0, 0.3, 0.3)
var _since_damage: float = 0.0
var _distance_buffer: float = 0.0
var _hurt_tween: Tween
## Hoja overworld del personaje elegido.
var sheet: Texture2D
var _swim_time: float = 0.0
var _swim_bob: float = 0.0
var _splash_timer: float = 0.0
var _swim_shader_on := false
## Hambre vacía: segundos acumulados para el siguiente tic de daño (ver GameState.hunger).
var _starve_tick: float = 0.0


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


## Quien te vio y viene a retarte (ver BattleManager.spotted); tope de seguridad en segundos.
var spotted_by: Node3D = null
var spotted_time := 0.0


func _physics_process(delta: float) -> void:
	if mode == Mode.DOWNED:
		_process_downed(delta)
		return
	if ride == Ride.FLY:
		_process_flight(delta)
		return
	_update_water_mode()
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Hablando con alguien (caja de diálogo) no se mueve.
	if DialogBox.blocking:
		input = Vector2.ZERO
	# Un entrenador te vio (regla de Fernando): te quedas quieto mirándolo hasta que llega;
	# no puedes saltarte el combate.
	if spotted_by != null:
		spotted_time -= delta
		if not is_instance_valid(spotted_by) or spotted_time <= 0.0:
			spotted_by = null
		else:
			input = Vector2.ZERO
			($Sprite as DirectionalSprite).look_at_point(spotted_by.global_position)
	# En combate el teclado mueve a tu Pokémon; tú solo te mueves al apuntar la Pokéball.
	var battle := get_tree().get_first_node_in_group(&"battle") as BattleManager
	if battle != null and battle.active and not ($ThrowAim as ThrowAim).is_aiming():
		input = Vector2.ZERO
	var direction := _camera_relative(input)
	var swimming := mode == Mode.SWIM or mode == Mode.DIVE
	var aiming := ($ThrowAim as ThrowAim).is_aiming() and not swimming
	var wants_run := Input.is_action_pressed("run") and input.length() > 0.1 and not swimming and not aiming
	var running := wants_run and not exhausted and stamina > 0.0 and ride == Ride.NONE
	_update_stamina(running, swimming and riding == null and input.length() > 0.1, delta)
	var target_speed := config.swim_speed if swimming else (config.run_speed if running else config.walk_speed)
	if ride == Ride.BIKE and not swimming:
		var on_road := _world != null and (_world.distance_to_paths(global_position.x, global_position.z) < 4.0 \
				or not _world.settlement_at(global_position.x, global_position.z).is_empty())
		target_speed = config.run_speed * (BIKE_ROAD_FACTOR if on_road else BIKE_SPEED_FACTOR)
	elif ride == Ride.MOUNT and not swimming and mount != null:
		target_speed = mount_speed(mount) * (1.25 if wants_run else 1.0)
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
	var battle_aim := battle != null and battle.active and aiming
	_update_dodge(direction, battle_aim, delta)

	if swimming:
		velocity.y = _swim_vertical(delta)
		_apply_sea_current(delta)
	elif is_on_floor():
		velocity.y = 0.0
		if Input.is_action_just_pressed("jump") and not battle_aim:
			if ride == Ride.MOUNT and mount != null and can_carry_flying(mount) and GameState.world_flags.get("fly_license", false):
				take_off()
			else:
				velocity.y = config.jump_velocity
				AudioBus.play_sfx("jump")
	else:
		velocity.y -= config.gravity * delta

	move_and_slide()
	_update_fall(swimming)
	_update_air(delta)
	_update_regen(delta)
	var fighting := battle != null and battle.active
	_update_hunger(delta, running or (swimming and input.length() > 0.1) or fighting)
	# Distancia recorrida (logros y estadísticas).
	var moved := Vector2(velocity.x, velocity.z).length() * delta
	if moved > 0.001:
		_distance_buffer += moved
		if _distance_buffer >= 10.0:
			Achievements.add("distance", _distance_buffer)
			_distance_buffer = 0.0
	if ride == Ride.NONE:
		_sprite.animate(horizontal, delta, horizontal.length() > config.walk_speed + 0.5)
	else:
		# Sentado: no camina, solo mira hacia donde avanza.
		_sprite.animate(Vector3.ZERO, delta, false)
		if horizontal.length() > 0.1:
			_sprite.look_at_point(global_position + horizontal)
	_update_swim_visuals(horizontal, delta)
	_update_ride_visuals()
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


func is_dodging() -> bool:
	return _dodge_left > 0.0


func _update_dodge(direction: Vector3, battle_aim: bool, delta: float) -> void:
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	if battle_aim and is_on_floor() and Input.is_action_just_pressed("dodge") and _dodge_cooldown <= 0.0:
		dodge(direction)
	if _dodge_left > 0.0:
		_dodge_left -= delta
		velocity.x = _dodge_direction.x * DODGE_SPEED
		velocity.z = _dodge_direction.z * DODGE_SPEED


## Esquiva hacia direction (o hacia atrás de la cámara si no hay dirección).
func dodge(direction: Vector3 = Vector3.ZERO) -> void:
	_dodge_direction = direction.normalized() if direction.length() > 0.1 else -_camera_relative(Vector2(0, -1)).normalized()
	_dodge_left = DODGE_TIME
	_dodge_cooldown = DODGE_COOLDOWN
	AudioBus.play_sfx("jump", 1.3)


## Resta vida (en medios corazones). A 0, queda desmayado. Esquivando no recibe daño.
func take_damage(amount: float) -> void:
	if mode == Mode.DOWNED or amount <= 0.0 or is_dodging():
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


## Hambre (campamento, comida y hambre; acordado con Fernando el 2026-10-10): se vacía
## con el tiempo (más rápido corriendo, nadando o peleando) y, vacía del todo, quita
## vida poco a poco hasta dejarlo sin vida en GameState.STARVE_SECONDS.
func _update_hunger(delta: float, fast: bool) -> void:
	GameState.drain_hunger(delta, fast)
	if GameState.hunger > 0.0:
		_starve_tick = 0.0
		return
	_starve_tick += delta
	if _starve_tick >= 1.0:
		_starve_tick -= 1.0
		take_damage(config.health_max / GameState.STARVE_SECONDS)


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
	if ride != Ride.NONE:
		end_ride()
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
	Achievements.add("recoveries")
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
			# En el agua no se va en bicicleta ni montado en tierra.
			if ride == Ride.BIKE or ride == Ride.MOUNT:
				end_ride()
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
	if ride == Ride.FLY:
		_air_peak_y = global_position.y
		_was_on_floor = true
		return
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


# --- Bicicleta, montura y vuelo ----------------------------------------------------------

## Velocidad montando a un Pokémon: según su Velocidad base (más rápido que correr).
static func mount_speed(actor: PokemonActor) -> float:
	return clampf(7.5 + actor.species.speed * 0.05, 8.5, 14.0)


## ¿Se puede montar a este compañero en tierra? (lo bastante grande y no solo acuático)
static func can_mount(actor: PokemonActor) -> bool:
	var water_only := actor.species.habitats.all(func(h: int) -> bool: return h == SpeciesData.Habitat.SEA or h == SpeciesData.Habitat.FRESHWATER)
	return actor.species.height_m >= 1.0 and not (water_only and not actor.can_fly())


## ¿Sube paredes empinadas? (Roca o Tierra, o especies trepadoras)
static func can_climb(actor: PokemonActor) -> bool:
	return actor.species.types.has(PokemonTypes.Type.ROCK) or actor.species.types.has(PokemonTypes.Type.GROUND) \
			or actor.species.identifier in ["sceptile", "lycanroc", "skiddo", "gogoat", "ariados", "galvantula"]


## ¿Puede volar llevándolo? (vuela y es lo bastante grande)
static func can_carry_flying(actor: PokemonActor) -> bool:
	return actor.can_fly() and actor.species.height_m >= 1.0


## Sube o baja de la bicicleta (si tiene una). Devuelve el mensaje.
func toggle_bicycle() -> String:
	if ride == Ride.BIKE:
		end_ride()
		return "Te bajaste de la bicicleta."
	if ride != Ride.NONE:
		return "Primero bájate de tu Pokémon."
	if GameState.item_count("bicycle") <= 0:
		return "No tienes bicicleta."
	if mode != Mode.WALK or global_position.x > WorldBuilder.INTERIOR_X:
		return "Aquí no puedes usar la bicicleta."
	ride = Ride.BIKE
	AudioBus.play_sfx("bicycle")
	_update_ride_visuals()
	return "¡Vas en bicicleta!"


## Monta al compañero (y, si vuela, despega al saltar).
func start_mount(actor: PokemonActor) -> void:
	mount = actor
	ride = Ride.MOUNT
	actor.set_ridden(self)
	if _default_floor_angle < 0.0:
		_default_floor_angle = floor_max_angle
	if can_climb(actor):
		floor_max_angle = deg_to_rad(CLIMB_MAX_ANGLE)
	_update_ride_visuals()


## Despega (montado en un volador).
func take_off() -> void:
	if ride == Ride.MOUNT and mount != null and can_carry_flying(mount):
		ride = Ride.FLY
		velocity.y = FLY_CLIMB


## Se baja de lo que sea (bicicleta, montura o vuelo).
func end_ride() -> void:
	if mount != null and is_instance_valid(mount):
		mount.set_ridden(null)
		mount.global_position = global_position + _camera_relative(Vector2(1, 0)) * 1.5 + Vector3.UP * 0.2
	mount = null
	ride = Ride.NONE
	if _default_floor_angle >= 0.0:
		floor_max_angle = _default_floor_angle
	_air_peak_y = global_position.y
	_update_ride_visuals()


## Altura sobre el suelo (o el agua).
func height_above_ground() -> float:
	if _world == null:
		return 0.0
	var ground := maxf(_world.surface_height_at(global_position.x, global_position.z), _world.water_level_at(global_position.x, global_position.z))
	return global_position.y - ground


## Vuelo libre: se mueve relativo a la cámara; "jump" sube, "dive" baja; correr va más rápido.
func _process_flight(delta: float) -> void:
	if mount == null or not is_instance_valid(mount):
		end_ride()
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera_relative(input)
	var speed := FLY_FAST_SPEED if Input.is_action_pressed("run") else FLY_SPEED
	var target := direction * speed * minf(input.length(), 1.0)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, 30.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var climb := 0.0
	# Vuelo libre: al avanzar, la inclinación de la cámara hace subir o bajar.
	var camera := get_viewport().get_camera_3d()
	if camera != null and input.y < -0.1:
		var look := -camera.global_basis.z
		climb = clampf((look.y + 0.35) * 2.2, -1.0, 1.0) * FLY_CLIMB * -input.y
	if Input.is_action_pressed("jump"):
		climb = FLY_CLIMB
	elif Input.is_action_pressed("dive"):
		climb = -FLY_CLIMB * 1.3
	velocity.y = move_toward(velocity.y, climb, 20.0 * delta)
	if global_position.y > FLY_CEILING and velocity.y > 0.0:
		velocity.y = 0.0
	move_and_slide()
	# Al tocar el suelo bajando, aterriza montado.
	if is_on_floor() and climb < 0.0:
		ride = Ride.MOUNT
		velocity.y = 0.0
	if horizontal.length() > 0.1:
		_sprite.look_at_point(global_position + horizontal)
	_sprite.animate(Vector3.ZERO, delta, false)
	_update_ride_visuals()
	_update_regen(delta)


## Sprite del jugador sentado sobre la montura o la bicicleta.
func _update_ride_visuals() -> void:
	if ride == Ride.BIKE:
		if _bike == null:
			_bike = Sprite3D.new()
			_bike.name = "Bicycle"
			_bike.texture = _bike_texture()
			_bike.pixel_size = config.pixel_size
			_bike.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			SpriteMaterials.apply(_bike)
			add_child(_bike)
		_bike.visible = true
		_sprite.place_on_ground()
		_sprite.position.y += 0.3
	elif _bike != null:
		_bike.visible = false
	if (ride == Ride.MOUNT or ride == Ride.FLY) and mount != null and is_instance_valid(mount):
		_sprite.place_on_ground()
		_sprite.position.y += mount.species.overworld_cell * mount.world_pixel_size() * 0.6
		_sprite.set_instance_shader_parameter("cut_bottom", 0.45)
		_swim_shader_on = true
	elif ride == Ride.NONE and mode == Mode.WALK and _swim_shader_on:
		_swim_shader_on = false
		_sprite.place_on_ground()
		_sprite.set_instance_shader_parameter("cut_bottom", -1000.0)


## Bicicleta pixel art (generada): ruedas, cuadro rojo y manubrio.
static func _bike_texture() -> Texture2D:
	var image := Image.create_empty(30, 18, false, Image.FORMAT_RGBA8)
	var dark := Color(0.12, 0.12, 0.14)
	var frame := Color(0.85, 0.2, 0.2)
	for wheel: Vector2 in [Vector2(6, 12), Vector2(23, 12)]:
		for y in 18:
			for x in 30:
				var d := Vector2(x, y).distance_to(wheel)
				if d <= 5.5 and d >= 4.0:
					image.set_pixel(x, y, dark)
	for i in 14:
		image.set_pixel(8 + i, 8 + i / 5, frame)
		image.set_pixel(8 + i, 9 + i / 5, frame)
	for y in range(4, 12):
		image.set_pixel(21, y, frame)
	for x in range(18, 25):
		image.set_pixel(x, 4, dark)
	return ImageTexture.create_from_image(image)
