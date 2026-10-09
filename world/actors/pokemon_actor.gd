class_name PokemonActor
extends CharacterBody3D
## Pokémon en el mundo. Rol salvaje: IA por temperamento (deambular, curioso,
## tímido, agresivo) alrededor de su punto de aparición en la hierba. Rol compañero:
## sigue al jugador con navegación y mira a los salvajes cercanos.

signal contact_with_player(actor: PokemonActor)

enum Role { WILD, COMPANION }
enum State { IDLE, WANDER, APPROACH, FLEE, CHASE, FOLLOW }

const PIXEL_SIZE := 0.057
const GRAVITY := 20.0
## Distancias en metros.
const DETECT_RADIUS := 9.0
const CONTACT_RADIUS := 1.3
const WANDER_RADIUS := 6.0
const CURIOUS_STOP := 2.5
const FLEE_SAFE := 15.0
const FOLLOW_DISTANCE := 2.2
const FOLLOW_TELEPORT := 30.0
const COMPANION_WATCH_RADIUS := 8.0

@export var species: SpeciesData
@export var role: Role = Role.WILD

var state: State = State.IDLE
var home := Vector3.ZERO
var player: Node3D
## Enfriamiento tras un contacto, para no disparar el encuentro en cada frame.
var contact_cooldown: float = 0.0

@onready var _sprite: DirectionalSprite = $Sprite
@onready var _agent: NavigationAgent3D = $Agent

var _state_time: float = 0.0
var _idle_duration: float = 1.0
var _rng := RandomNumberGenerator.new()
## Segundos durante los que un curioso ya aburrido ignora al jugador.
var _ignore_player: float = 0.0


func _ready() -> void:
	add_to_group(BiomeBuilder.GRASS_PUSHERS_GROUP)
	_rng.randomize()
	_sprite.walk_fps = 5.0
	_sprite.run_fps = 9.0
	_sprite.setup(species.overworld_sheet, 2, 4, PIXEL_SIZE, species.foot_offset_px)
	home = global_position
	_enter(State.FOLLOW if role == Role.COMPANION else State.IDLE)


## Velocidad al caminar y al correr según la stat de velocidad (m/s).
func walk_speed() -> float:
	return 1.4 + species.speed / 70.0


func run_speed() -> float:
	return minf(2.8 + species.speed / 25.0, 7.5)


func _physics_process(delta: float) -> void:
	_state_time += delta
	contact_cooldown = maxf(contact_cooldown - delta, 0.0)
	_ignore_player = maxf(_ignore_player - delta, 0.0)
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
	_check_contact()


func _enter(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	if new_state == State.IDLE:
		_idle_duration = _rng.randf_range(1.0, 3.5)
	elif new_state == State.WANDER:
		var angle := _rng.randf() * TAU
		var r := _rng.randf_range(1.5, WANDER_RADIUS)
		_agent.target_position = home + Vector3(cos(angle) * r, 0.0, sin(angle) * r)


## Devuelve [destino, velocidad] para el rol salvaje.
func _think_wild() -> Array:
	var to_player := INF
	if player != null:
		to_player = global_position.distance_to(player.global_position)
	var sees_player := to_player <= DETECT_RADIUS and _ignore_player <= 0.0
	if sees_player:
		match species.temperament:
			SpeciesData.Temperament.CURIOUS:
				if state == State.IDLE or state == State.WANDER:
					_enter(State.APPROACH)
			SpeciesData.Temperament.SHY:
				if state != State.FLEE:
					_enter(State.FLEE)
			SpeciesData.Temperament.AGGRESSIVE:
				if state != State.CHASE:
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
			if to_player > DETECT_RADIUS * 1.6:
				_enter(State.IDLE)
				return [global_position, 0.0]
			return [player.global_position, run_speed()]
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
	if global_position.distance_to(player.global_position) <= CONTACT_RADIUS:
		contact_cooldown = 3.0
		contact_with_player.emit(self)


## Dirección visible (para pruebas).
func get_visible_facing() -> DirectionalSprite.Facing:
	return _sprite.visible_facing()
