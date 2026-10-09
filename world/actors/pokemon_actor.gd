class_name PokemonActor
extends CharacterBody3D
## Pokémon en el mundo. Rol salvaje: IA por temperamento (deambula, curioso, tímido,
## agresivo, territorial) alrededor de su punto de aparición; los que persiguen lo
## hacen dentro de un área (indicada en el suelo) y si el jugador sale, se rinden y
## regresan. Los nadadores se mueven solo por el agua. Rol compañero: sigue al
## jugador con navegación y mira a los salvajes cercanos.

signal contact_with_player(actor: PokemonActor)

enum Role { WILD, COMPANION }
enum State { IDLE, WANDER, APPROACH, FLEE, CHASE, RETURN, FOLLOW }

const PIXEL_SIZE := 0.057
const GRAVITY := 20.0
## Distancias en metros.
const DETECT_RADIUS := 9.0
const CONTACT_RADIUS := 1.3
const WANDER_RADIUS := 6.0
const CURIOUS_STOP := 2.5
const FLEE_SAFE := 15.0
const TERRITORY_RADIUS := 7.0
const FOLLOW_DISTANCE := 2.2
const FOLLOW_TELEPORT := 30.0
const COMPANION_WATCH_RADIUS := 8.0
const SPARKLE_INTERVAL := 2.5

@export var species: SpeciesData
@export var role: Role = Role.WILD
@export var shiny := false
## Nada: se mueve sobre la superficie del agua, sin navegación.
@export var swimming := false

var state: State = State.IDLE
var home := Vector3.ZERO
var player: Node3D
var world: WorldBuilder
## Enfriamiento tras un contacto, para no disparar el encuentro en cada frame.
var contact_cooldown: float = 0.0
## Dónde empezó la persecución actual y hasta qué distancia de ahí persigue.
var chase_origin := Vector3.ZERO

@onready var _sprite: DirectionalSprite = $Sprite
@onready var _agent: NavigationAgent3D = $Agent
@onready var _chase_ring: Decal = $ChaseRing

var _state_time: float = 0.0
var _idle_duration: float = 1.0
var _rng := RandomNumberGenerator.new()
## Segundos durante los que ignora al jugador (curioso aburrido o perseguidor que se rindió).
var _ignore_player: float = 0.0
var _sparkle_time: float = 0.0
var _sparkles: CPUParticles3D
var _swim_target := Vector3.ZERO


func _ready() -> void:
	add_to_group(WorldBuilder.GRASS_PUSHERS_GROUP)
	_rng.randomize()
	_sprite.walk_fps = 5.0
	_sprite.run_fps = 9.0
	var sheet := species.overworld_sheet_shiny if shiny and species.overworld_sheet_shiny != null else species.overworld_sheet
	_sprite.setup(sheet, 2, 4, PIXEL_SIZE * species.size_scale, species.foot_offset_px)
	# Colisión y sombra según el tamaño.
	var collision := $Collision as CollisionShape3D
	var capsule := collision.shape.duplicate() as CapsuleShape3D
	capsule.radius *= species.size_scale
	capsule.height = maxf(capsule.height * species.size_scale, capsule.radius * 2.0)
	collision.shape = capsule
	collision.position.y = capsule.height * 0.5
	var shadow := $BlobShadow as Decal
	shadow.size = Vector3(shadow.size.x * species.size_scale, shadow.size.y, shadow.size.z * species.size_scale)
	_chase_ring.top_level = true
	_chase_ring.visible = false
	if shiny:
		_sparkles = _make_sparkles()
		add_child(_sparkles)
	if swimming:
		# Los nadadores no usan física ni navegación: flotan en la superficie.
		collision_layer = 0
		collision_mask = 0
		shadow.visible = false
		_swim_target = global_position
	home = global_position
	_enter(State.FOLLOW if role == Role.COMPANION else State.IDLE)


## Velocidad al caminar y al correr según la stat de velocidad (m/s).
func walk_speed() -> float:
	return 1.4 + species.speed / 70.0


func run_speed() -> float:
	return minf(2.8 + species.speed / 25.0, 7.5)


## Hasta qué distancia del inicio de la persecución te sigue: base 20 m, más lejos
## los rápidos y fuertes (hasta 35 m), menos los lentos (desde 12 m).
func chase_leash() -> float:
	return clampf(12.0 + species.speed * 0.08 + (species.base_total - 300) * 0.03, 12.0, 35.0)


func contact_radius() -> float:
	return CONTACT_RADIUS * maxf(1.0, species.size_scale * 0.8)


func _physics_process(delta: float) -> void:
	_state_time += delta
	contact_cooldown = maxf(contact_cooldown - delta, 0.0)
	_ignore_player = maxf(_ignore_player - delta, 0.0)
	_update_sparkles(delta)
	if swimming:
		_swim(delta)
		_check_contact()
		return
	var target_speed := 0.0
	var destination := global_position
	match role:
		Role.WILD:
			var result := _think_wild()
			destination = result[0]
			target_speed = result[1]
		Role.COMPANION:
			var result := _think_companion()
			destination = result[0]
			target_speed = result[1]

	var horizontal := Vector3.ZERO
	if target_speed > 0.0:
		_agent.target_position = destination
		var next := _agent.get_next_path_position()
		var to_next := next - global_position
		to_next.y = 0.0
		if to_next.length() > 0.05:
			horizontal = to_next.normalized() * target_speed
	var current := Vector3(velocity.x, 0.0, velocity.z)
	current = current.move_toward(horizontal, 25.0 * delta)
	velocity.x = current.x
	velocity.z = current.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	_sprite.animate(current, delta, target_speed > walk_speed() + 0.1)
	_chase_ring.visible = state == State.CHASE
	_check_contact()


func _enter(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	match new_state:
		State.IDLE:
			_idle_duration = _rng.randf_range(1.0, 3.5)
		State.WANDER:
			var angle := _rng.randf() * TAU
			var r := _rng.randf_range(1.5, WANDER_RADIUS)
			_agent.target_position = home + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
		State.CHASE:
			# Los territoriales defienden su zona: el área se mide desde su casa.
			chase_origin = home if species.temperament == SpeciesData.Temperament.TERRITORIAL else global_position
			var leash := chase_leash()
			_chase_ring.global_position = chase_origin + Vector3.UP * 2.0
			_chase_ring.size = Vector3(leash * 2.0, 8.0, leash * 2.0)


## Devuelve [destino, velocidad] para el rol salvaje.
func _think_wild() -> Array:
	var to_player := INF
	if player != null:
		to_player = global_position.distance_to(player.global_position)
	var sees_player := to_player <= DETECT_RADIUS and _ignore_player <= 0.0
	if state != State.RETURN:
		match species.temperament:
			SpeciesData.Temperament.CURIOUS:
				if sees_player and (state == State.IDLE or state == State.WANDER):
					_enter(State.APPROACH)
			SpeciesData.Temperament.SHY:
				if sees_player and state != State.FLEE:
					_enter(State.FLEE)
			SpeciesData.Temperament.AGGRESSIVE:
				if sees_player and state != State.CHASE:
					_enter(State.CHASE)
			SpeciesData.Temperament.TERRITORIAL:
				var intruder := player != null and _ignore_player <= 0.0 \
						and player.global_position.distance_to(home) <= TERRITORY_RADIUS
				if intruder and state != State.CHASE:
					_enter(State.CHASE)

	match state:
		State.IDLE:
			if _state_time >= _idle_duration:
				_enter(State.WANDER)
			return [global_position, 0.0]
		State.WANDER:
			if _agent.is_navigation_finished() or _state_time > 6.0:
				_enter(State.IDLE)
				return [global_position, 0.0]
			return [_agent.target_position, walk_speed() * 0.6]
		State.APPROACH:
			# Se acerca, se queda mirando y pierde el interés tras un rato.
			if not sees_player or _state_time > 8.0:
				_ignore_player = 10.0
				_enter(State.IDLE)
				return [global_position, 0.0]
			if to_player <= CURIOUS_STOP:
				_sprite.look_at_point(player.global_position)
				return [global_position, 0.0]
			return [player.global_position, walk_speed()]
		State.FLEE:
			if to_player >= FLEE_SAFE or player == null:
				home = global_position
				_enter(State.IDLE)
				return [global_position, 0.0]
			var away := global_position - player.global_position
			away.y = 0.0
			return [global_position + away.normalized() * 6.0, run_speed()]
		State.CHASE:
			# Si el jugador sale del área, se rinde y regresa a casa.
			if player.global_position.distance_to(chase_origin) > chase_leash():
				_ignore_player = 6.0
				_enter(State.RETURN)
				return [home, walk_speed()]
			return [player.global_position, run_speed()]
		State.RETURN:
			if global_position.distance_to(home) < 1.5 or _state_time > 20.0:
				_enter(State.IDLE)
				return [global_position, 0.0]
			return [home, walk_speed()]
	return [global_position, 0.0]


## Devuelve [destino, velocidad] para el rol compañero.
func _think_companion() -> Array:
	if player == null:
		return [global_position, 0.0]
	var distance := global_position.distance_to(player.global_position)
	if distance > FOLLOW_TELEPORT:
		# Se quedó muy atrás (p. ej. atorado): reaparece junto al jugador.
		global_position = player.global_position + Vector3(1.0, 0.5, 1.0)
		velocity = Vector3.ZERO
		return [global_position, 0.0]
	if distance > FOLLOW_DISTANCE:
		var speed := walk_speed() if distance < FOLLOW_DISTANCE * 2.5 else run_speed()
		# No ir más lento que el jugador cuando corre.
		if player is Player:
			speed = maxf(speed, (player as Player).get_ground_speed() * 1.05)
		return [player.global_position, speed]
	# Quieto junto al jugador: mira al salvaje más cercano, si hay uno.
	var nearest := _nearest_wild(COMPANION_WATCH_RADIUS)
	if nearest != null:
		_sprite.look_at_point(nearest.global_position)
	return [global_position, 0.0]


## Nado: elige puntos con agua profunda alrededor de su casa y se desliza hacia ellos.
func _swim(delta: float) -> void:
	if world == null:
		return
	var to_target := _swim_target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.5 or _state_time > 8.0:
		_state_time = 0.0
		for attempt in 10:
			var angle := _rng.randf() * TAU
			var r := _rng.randf_range(2.0, 8.0)
			var candidate := home + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
			if world.water_depth_at(candidate.x, candidate.z) > 0.8:
				_swim_target = candidate
				break
	var step := Vector3.ZERO
	if to_target.length() > 0.05:
		step = to_target.normalized() * walk_speed() * 0.7
	var next := global_position + step * delta
	if world.water_depth_at(next.x, next.z) > 0.6:
		global_position = next
	else:
		_swim_target = global_position
	# Flota en la superficie con la mitad inferior sumergida.
	global_position.y = world.water_level_at(global_position.x, global_position.z) - 0.25 * species.size_scale
	_sprite.animate(step, delta)


func _nearest_wild(radius: float) -> PokemonActor:
	var best: PokemonActor
	var best_d := radius
	for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
		var other := node as PokemonActor
		var d := global_position.distance_to(other.global_position)
		if d < best_d:
			best_d = d
			best = other
	return best


func _check_contact() -> void:
	if role != Role.WILD or player == null or contact_cooldown > 0.0:
		return
	if global_position.distance_to(player.global_position) <= contact_radius():
		contact_cooldown = 3.0
		contact_with_player.emit(self)


func _make_sparkles() -> CPUParticles3D:
	# Estrella de 7×7 px generada por código (pixel art).
	var image := Image.create_empty(7, 7, false, Image.FORMAT_RGBA8)
	for i in 7:
		image.set_pixel(3, i, Color(1, 1, 0.85))
		image.set_pixel(i, 3, Color(1, 1, 0.85))
	image.set_pixel(3, 3, Color.WHITE)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 7.0 * PIXEL_SIZE
	quad.material = material
	var particles := CPUParticles3D.new()
	particles.name = "ShinySparkles"
	particles.mesh = quad
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 6
	particles.lifetime = 0.7
	particles.explosiveness = 0.9
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.6 * species.size_scale
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = 0.3
	particles.initial_velocity_max = 0.8
	particles.position.y = 0.9 * species.size_scale
	particles.layers = WorldBuilder.VISUAL_LAYER_SPRITES
	return particles


func _update_sparkles(delta: float) -> void:
	if _sparkles == null:
		return
	_sparkle_time += delta
	if _sparkle_time >= SPARKLE_INTERVAL:
		_sparkle_time = 0.0
		_sparkles.restart()


## Dirección visible (para pruebas).
func get_visible_facing() -> DirectionalSprite.Facing:
	return _sprite.visible_facing()
