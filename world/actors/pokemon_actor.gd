class_name PokemonActor
extends CharacterBody3D
## Pokémon en el mundo. Rol salvaje: IA por temperamento (deambula, curioso, tímido,
## agresivo, territorial) alrededor de su punto de aparición; los que persiguen lo
## hacen dentro de un área (indicada en el suelo) y si el jugador sale, se rinden y
## regresan. Los nadadores se mueven solo por el agua. Rol compañero: sigue al
## jugador con navegación y mira a los salvajes cercanos.

signal contact_with_player(actor: PokemonActor)
## Avisa al spawner cuando se esconde o desaparece (libera su cupo).
signal vanished(actor: PokemonActor)
## Quedó debilitado (aturdido): durante STUN_TIME se le puede capturar.
signal stunned(actor: PokemonActor)

enum Role { WILD, COMPANION }
enum State { IDLE, WANDER, APPROACH, FLEE, CHASE, RETURN, FOLLOW, HIDE, NOTICE, ESCAPE, FLY, FIGHT, STUNNED, PERCHED, AMBUSH, DROP }

const PIXEL_SIZE := 0.057
const GRAVITY := 20.0
## Distancias en metros.
const DETECT_RADIUS := 9.0
const CONTACT_RADIUS := 1.3
const WANDER_RADIUS := 14.0
## Cada cuántos paseos se muda a otro lugar (mentalidad propia: recorre todo).
const WANDERS_BEFORE_MOVING := 4
const RELOCATE_DISTANCE := 25.0
## Sin interacción durante este rango de segundos, se esconde y desaparece.
const HIDE_AFTER_MIN := 60.0
const HIDE_AFTER_MAX := 180.0
## El jugador a menos de esta distancia cuenta como interacción.
const INTERACTION_RADIUS := 10.0
## Legendarios: alcance de su vista (cono frontal), distancia a la que te oye aunque
## no te vea (más si corres) y cuánto se reubican.
const LEGEND_SIGHT := 16.0
const LEGEND_SIGHT_CONE := 0.35
const LEGEND_HEARING := 5.0
const LEGEND_HEARING_RUNNING := 11.0
const LEGEND_NOTICE_TIME := 0.9
const LEGEND_ESCAPE_DISTANCE := 45.0
const FLY_SPEED := 14.0
const FLY_HEIGHT := 14.0
const ESCAPE_PLAYER_CLEARANCE := 5.0
## Peleas en el mundo.
const STUN_TIME := 5.0
const ATTACK_WINDUP := 0.45
const ATTACK_COOLDOWN_MIN := 1.4
const ATTACK_COOLDOWN_MAX := 2.4
const MELEE_RANGE := 1.8
const RANGED_MIN := 5.0
const RANGED_MAX := 9.0
## Emboscadas desde los árboles.
const AMBUSH_TRIGGER_RADIUS := 3.0
const AMBUSH_WATCH_RADIUS := 8.0
const AMBUSH_SHY_FLEE_RADIUS := 4.0
const AMBUSH_WINDUP := 0.5
const DROP_SPEED := 14.0
## Cuánto se adelanta hacia la cámara el sprite de un Pokémon posado en un árbol.
const PERCH_FRONT_OFFSET := 1.2
const AMBUSH_HIT_RADIUS := 1.6
## Cada cuánto busca pelea con otros salvajes (rivalidades), en segundos.
const RIVAL_SCAN_INTERVAL := 1.5
const RIVAL_RADIUS := 9.0
## Enemigos clásicos: siempre pelean al encontrarse.
const CLASSIC_ENEMIES := {
	"zangoose": ["seviper"], "seviper": ["zangoose"], "heatmor": ["durant"], "durant": ["heatmor"],
	"mightyena": ["poochyena"], "absol": ["mightyena"],
}
const CURIOUS_STOP := 2.5
const FLEE_SAFE := 15.0
const TERRITORY_RADIUS := 7.0
const FOLLOW_DISTANCE := 2.2
const FOLLOW_TELEPORT := 30.0
const COMPANION_WATCH_RADIUS := 8.0
const SPARKLE_INTERVAL := 2.5
## Distancia que debe moverse el destino para recalcular el camino.
const REPATH_DISTANCE := 1.5

@export var species: SpeciesData
@export var role: Role = Role.WILD
@export var shiny := false
## Nada: se mueve sobre la superficie del agua, sin navegación.
@export var swimming := false
## Lo controla el jugador (mientras Nate está desmayado y lo protege).
var controlled := false
## Legendario: nunca ataca; es cauteloso. Si te ve o lo asustas, muestra "?" y se
## reubica rápido: los voladores levantan el vuelo y los demás corren a un lugar seguro.
@export var legendary := false

var state: State = State.IDLE
var home := Vector3.ZERO
var player: Node3D
var world: WorldBuilder
## Enfriamiento tras un contacto, para no disparar el encuentro en cada frame.
var contact_cooldown: float = 0.0
## Dónde empezó la persecución actual y hasta qué distancia de ahí persigue.
var chase_origin := Vector3.ZERO
## Manada: id del grupo (-1 = solo), su líder (null si es el líder) y su lugar en la formación.
var group_id: int = -1
var leader: PokemonActor
var pack_offset := Vector3.ZERO


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
## Último destino pedido a la navegación (INF = ninguno todavía).
var _last_target := Vector3.INF
var _unseen_time: float = 0.0
var _hide_after: float = 120.0
var _wanders: int = 0
var _hide_target := Vector3.ZERO
## Vida en el mundo (no es la del combate de la Fase 3, que la usará como referencia).
var hp: float = 50.0
var hp_max: float = 50.0
## Con quién pelea (otro PokemonActor o el jugador).
var fight_target: Node3D
var _attack_cooldown: float = 0.0
var _windup: float = 0.0
var _rival_scan: float = 0.0
var _health_bar: HealthBar3D
var _faded := false
var _dizzy: DizzyStars
## Emboscada: colgado de una rama (Bicho) o posado en la copa (ave) de perch_tree.
var perched := false
var perch_is_bird := false
var perch_tree: Node3D
var _drop_target := Vector3.ZERO
var _exclaim: Sprite3D
var _thread: MeshInstance3D
var _shake_timer: float = 3.0
var _escape_target := Vector3.ZERO
var _fly_start := Vector3.ZERO
var _question: Sprite3D


func _ready() -> void:
	add_to_group(WorldBuilder.GRASS_PUSHERS_GROUP)
	_rng.randomize()
	_sprite.walk_fps = 5.0
	_sprite.run_fps = 9.0
	var sheet := species.overworld_sheet_shiny if shiny and species.overworld_sheet_shiny != null else species.overworld_sheet
	_sprite.setup(sheet, 2, 4, world_pixel_size(), species.foot_offset_px)
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
	_hide_after = _rng.randf_range(HIDE_AFTER_MIN, HIDE_AFTER_MAX)
	if legendary:
		_question = _make_question_mark()
		add_child(_question)
	hp_max = 20.0 + species.hp * 0.6
	hp = hp_max
	_health_bar = HealthBar3D.create(species.overworld_cell * world_pixel_size() + 0.25)
	add_child(_health_bar)
	_rival_scan = _rng.randf() * RIVAL_SCAN_INTERVAL
	_enter(State.FOLLOW if role == Role.COMPANION else State.IDLE)


## Metros por píxel del sprite: 32 px × escalón de tamaño, sea la hoja de 32 o de 64 px.
func world_pixel_size() -> float:
	return PIXEL_SIZE * species.size_scale * 32.0 / species.overworld_cell


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
	_update_occlusion()
	contact_cooldown = maxf(contact_cooldown - delta, 0.0)
	_ignore_player = maxf(_ignore_player - delta, 0.0)
	_update_sparkles(delta)
	if role == Role.WILD and not legendary:
		_track_interaction(delta)
	if legendary and state == State.FLY:
		_fly(delta)
		return
	if state == State.STUNNED:
		_process_stunned(delta)
		return
	if perched:
		_process_perched(delta)
		return
	if controlled:
		_process_controlled(delta)
		return
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
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
		# Recalcular el camino es caro: solo cuando el destino se mueve de verdad.
		if _last_target.distance_squared_to(destination) > REPATH_DISTANCE * REPATH_DISTANCE:
			_last_target = destination
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
	# El área de persecución se ve mientras te persigue o pelea contigo.
	_chase_ring.visible = state == State.CHASE or (state == State.FIGHT and fight_target == player and role == Role.WILD)
	_check_contact()


func _enter(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	match new_state:
		State.IDLE:
			_idle_duration = _rng.randf_range(1.0, 3.5)
		State.WANDER:
			_wanders += 1
			if leader == null and _wanders % WANDERS_BEFORE_MOVING == 0:
				# Se muda: su nueva casa queda a unos metros, y así recorre el mundo.
				var a := _rng.randf() * TAU
				home += Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(RELOCATE_DISTANCE * 0.5, RELOCATE_DISTANCE)
			var angle := _rng.randf() * TAU
			var r := _rng.randf_range(1.5, WANDER_RADIUS)
			_agent.target_position = home + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
		State.HIDE:
			_hide_target = global_position
			if world != null:
				var cover := world.nearest_tall_grass_point(global_position, 15.0)
				if cover != Vector3.INF:
					_hide_target = cover
				else:
					var a := _rng.randf() * TAU
					_hide_target = global_position + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(3.0, 6.0)
		State.CHASE:
			_tell_pack(State.CHASE)
			# Los territoriales defienden su zona: el área se mide desde su casa.
			chase_origin = home if species.temperament == SpeciesData.Temperament.TERRITORIAL else global_position
			var leash := chase_leash()
			_chase_ring.global_position = chase_origin + Vector3.UP * 2.0
			_chase_ring.size = Vector3(leash * 2.0, 8.0, leash * 2.0)


## Devuelve [destino, velocidad] para el rol salvaje.
func _think_wild() -> Array:
	if legendary:
		return _think_legendary()
	var to_player := INF
	if player != null:
		to_player = global_position.distance_to(player.global_position)
	var sees_player := to_player <= DETECT_RADIUS and _ignore_player <= 0.0
	if state == State.FIGHT:
		return _think_fight()
	_rival_scan -= get_physics_process_delta_time()
	if _rival_scan <= 0.0 and (state == State.IDLE or state == State.WANDER):
		_rival_scan = RIVAL_SCAN_INTERVAL
		var rival := _find_rival()
		if rival != null:
			start_fight(rival)
			return [global_position, 0.0]
	if state == State.HIDE:
		if global_position.distance_to(_hide_target) < 1.2 or _state_time > 6.0:
			vanish()
			return [global_position, 0.0]
		return [_hide_target, walk_speed()]
	if state != State.RETURN:
		match species.temperament:
			SpeciesData.Temperament.CURIOUS:
				if sees_player and (state == State.IDLE or state == State.WANDER):
					_enter(State.APPROACH)
			SpeciesData.Temperament.SHY:
				if sees_player and state != State.FLEE:
					_enter(State.FLEE)
					_tell_pack(State.FLEE)
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
			if leader != null and is_instance_valid(leader) and global_position.distance_to(_formation_point()) > 3.0:
				return [_formation_point(), walk_speed()]
			if _state_time >= _idle_duration:
				_enter(State.WANDER)
			return [global_position, 0.0]
		State.WANDER:
			# Los miembros de una manada siguen al líder en formación.
			if leader != null and is_instance_valid(leader):
				if _state_time > 6.0:
					_enter(State.IDLE)
				return [_formation_point(), walk_speed() * 0.8]
			if _agent.is_navigation_finished() or _state_time > 8.0:
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
			# Al alcanzarlo, lo ataca (el combate completo llega en la Fase 3).
			if global_position.distance_to(player.global_position) <= attack_range() + 0.5:
				start_fight(player)
			return [player.global_position, run_speed()]
		State.RETURN:
			if global_position.distance_to(home) < 1.5 or _state_time > 20.0:
				_enter(State.IDLE)
				return [global_position, 0.0]
			return [home, walk_speed()]
	return [global_position, 0.0]


## Máximo de salvajes peleando a la vez con el compañero cuando protege a Nate.
const GUARD_MAX_ATTACKERS := 2
const DEFEND_RADIUS := 12.0
const GUARD_RADIUS := 8.0


## Devuelve [destino, velocidad] para el rol compañero.
func _think_companion() -> Array:
	if player == null:
		return [global_position, 0.0]
	if state == State.FIGHT:
		# No se aleja de Nate: si el rival huye lejos, vuelve.
		if fight_target != null and is_instance_valid(fight_target) and fight_target.global_position.distance_to(player.global_position) > DEFEND_RADIUS * 1.5:
			fight_target = null
			_enter(State.FOLLOW)
		else:
			return _think_fight()
	var threat := _threat_to_player()
	if threat != null:
		start_fight(threat)
		return [global_position, 0.0]
	if player is Player and (player as Player).mode == Player.Mode.DOWNED:
		# Guardia: junto a Nate desmayado.
		if global_position.distance_to(player.global_position) > 2.0:
			return [player.global_position, run_speed()]
		return [global_position, 0.0]
	var distance := global_position.distance_to(player.global_position)
	# Si el jugador nada, el compañero lo espera en la orilla.
	if world != null and world.water_depth_at(player.global_position.x, player.global_position.z) > 0.6:
		_sprite.look_at_point(player.global_position)
		return [global_position, 0.0]
	if distance > FOLLOW_TELEPORT:
		# Se quedó muy atrás (p. ej. atorado): reaparece junto al jugador.
		global_position = player.global_position + Vector3(1.0, 0.5, 1.0)
		velocity = Vector3.ZERO
		return [global_position, 0.0]
	# Camina a un costado de Nate (según la cámara), para no taparlo.
	var side := _beside_player()
	if global_position.distance_to(side) > FOLLOW_DISTANCE * 0.6:
		var speed := walk_speed() if distance < FOLLOW_DISTANCE * 2.5 else run_speed()
		# No ir más lento que el jugador cuando corre.
		if player is Player:
			speed = maxf(speed, (player as Player).get_ground_speed() * 1.05)
		return [side, speed]
	# Quieto junto al jugador: mira al salvaje más cercano, si hay uno.
	var nearest := _nearest_wild(COMPANION_WATCH_RADIUS)
	if nearest != null:
		_sprite.look_at_point(nearest.global_position)
	return [global_position, 0.0]


## Nado: elige puntos con agua profunda alrededor de su casa y se desliza hacia ellos.
func _swim(delta: float) -> void:
	if world == null:
		return
	if state == State.HIDE:
		vanish()  # Se sumerge con una salpicadura.
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


## Cuenta el tiempo sin interacción; al pasar el límite busca escondite.
func _track_interaction(delta: float) -> void:
	var interacting := state == State.APPROACH or state == State.FLEE or state == State.CHASE
	if player != null and global_position.distance_to(player.global_position) < INTERACTION_RADIUS:
		interacting = true
	if interacting:
		_unseen_time = 0.0
		return
	_unseen_time += delta
	# Los miembros se esconden cuando lo hace su líder (o si se quedaron sin líder).
	if _unseen_time >= _hide_after and state != State.HIDE and (leader == null or not is_instance_valid(leader)):
		hide_now()


## Empieza a esconderse (y la manada con él).
func hide_now() -> void:
	if state == State.HIDE:
		return
	if perched:
		# Posado en un árbol: se pierde entre las hojas de la copa.
		PixelBurst.spawn(get_parent(), global_position, PixelBurst.Kind.FOREST_LEAVES, species.size_scale)
		vanished.emit(self)
		queue_free()
		return
	_enter(State.HIDE)
	_tell_pack(State.HIDE)


## Desaparece con el efecto del lugar (hojas, polvo, salpicadura, arena).
func vanish() -> void:
	if world != null:
		PixelBurst.spawn(get_parent(), global_position + Vector3.UP * 0.4 * species.size_scale,
				world.hide_effect_at(global_position.x, global_position.z), species.size_scale)
	vanished.emit(self)
	queue_free()


func _formation_point() -> Vector3:
	return leader.global_position + pack_offset


## Propaga un estado a los demás de la manada (huir, perseguir o esconderse juntos).
func _tell_pack(new_state: State) -> void:
	if group_id < 0:
		return
	for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
		var mate := node as PokemonActor
		if mate == self or mate.group_id != group_id or mate.state == new_state:
			continue
		if new_state == State.HIDE:
			mate.hide_now()
		elif new_state == State.FLEE and mate.species.temperament != SpeciesData.Temperament.AGGRESSIVE:
			mate._enter(State.FLEE)
		elif new_state == State.CHASE and mate.species.temperament != SpeciesData.Temperament.SHY:
			mate._enter(State.CHASE)


## Si tapa al jugador desde la cámara, se vuelve semitransparente.
func _update_occlusion() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or player == null or perched or role == Role.COMPANION:
		return
	var from := camera.global_position
	var to := player.global_position + Vector3.UP * 0.9
	var center := global_position + Vector3.UP * species.overworld_cell * world_pixel_size() * 0.5
	var segment := to - from
	var t := clampf((center - from).dot(segment) / segment.length_squared(), 0.0, 1.0)
	var radius := maxf(0.6, species.size_scale * 0.7)
	var blocking := t < 0.97 and center.distance_to(from + segment * t) < radius
	if blocking != _faded:
		_faded = blocking
		_sprite.set_faded(blocking)


# --- Control directo (Nate desmayado) -------------------------------------------

## Distancia máxima a Nate mientras lo protege.
const GUARD_LEASH := 10.0
const DASH_SPEED := 11.0
const DASH_TIME := 0.25
const DASH_COOLDOWN := 0.8
## Al atacar, apunta al salvaje más cercano dentro de este radio.
const CONTROL_TARGET_RADIUS := 10.0

const PHYSICAL_COOLDOWN := 0.55
const SPECIAL_COOLDOWN := 1.2
const LUNGE_TIME := 0.22

var _dash_time: float = 0.0
var _special_cooldown: float = 0.0
var _lunge_time: float = 0.0
var _lunge_dir := Vector3.ZERO
var _lunge_target: PokemonActor
var _dash_cooldown: float = 0.0
var _dash_dir := Vector3.ZERO


## El jugador lo mueve (relativo a la cámara) y pelea: golpe físico (embestida al
## salvaje más cercano), ataque especial (proyectil de su tipo, al salvaje más cercano
## o al frente) y esquivar con un impulso (invulnerable mientras dura). No se aleja
## más de GUARD_LEASH de Nate.
func _process_controlled(delta: float) -> void:
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_special_cooldown = maxf(_special_cooldown - delta, 0.0)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera := get_viewport().get_camera_3d()
	var forward := Vector3.FORWARD
	if camera != null:
		forward = -camera.global_basis.z
		forward.y = 0.0
		forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var right := forward.cross(Vector3.UP)
	var direction := right * input.x - forward * input.y
	if direction.length() > 1.0:
		direction = direction.normalized()
	var horizontal := direction * run_speed()
	# Esquivar.
	if Input.is_action_just_pressed("dodge") and _dash_cooldown <= 0.0:
		_dash_time = DASH_TIME
		_dash_cooldown = DASH_COOLDOWN
		_dash_dir = direction.normalized() if direction.length() > 0.1 else -_sprite.facing_world
		PixelBurst.spawn(get_parent(), global_position + Vector3.UP * 0.2, PixelBurst.Kind.DUST, 0.5)
	if _dash_time > 0.0:
		_dash_time -= delta
		horizontal = _dash_dir * DASH_SPEED
		_sprite.modulate.a = 0.55
	else:
		_sprite.modulate.a = 1.0
	# Golpe físico: embestida hacia el más cercano.
	if Input.is_action_just_pressed("attack_1") and _attack_cooldown <= 0.0 and _dash_time <= 0.0:
		_attack_cooldown = PHYSICAL_COOLDOWN
		var target := _nearest_wild(CONTROL_TARGET_RADIUS * 0.5)
		var lunge_dir := _sprite.facing_world
		if target != null:
			lunge_dir = target.global_position - global_position
			lunge_dir.y = 0.0
			lunge_dir = lunge_dir.normalized()
			_sprite.look_at_point(target.global_position)
		_lunge_time = LUNGE_TIME
		_lunge_dir = lunge_dir
		_lunge_target = target
		_flash(Color(1.6, 1.6, 1.6))
	if _lunge_time > 0.0:
		_lunge_time -= delta
		horizontal = _lunge_dir * DASH_SPEED * 0.9
		if _lunge_target != null and is_instance_valid(_lunge_target) \
				and global_position.distance_to(_lunge_target.global_position) <= MELEE_RANGE + 0.4 * _lunge_target.species.size_scale:
			_apply_hit(_lunge_target, true)
			PixelBurst.spawn(get_parent(), _lunge_target.global_position + Vector3.UP * 0.5, PixelBurst.Kind.DUST, 0.7)
			_lunge_target = null
			_lunge_time = 0.0
	# Ataque especial: proyectil de su tipo.
	if Input.is_action_just_pressed("attack_2") and _special_cooldown <= 0.0:
		_special_cooldown = SPECIAL_COOLDOWN
		var target := _nearest_wild(CONTROL_TARGET_RADIUS)
		var origin := global_position + Vector3.UP * 0.6 * species.size_scale
		var to := origin + _sprite.facing_world * RANGED_MAX
		var targets: Array[Node3D] = []
		if target != null:
			_sprite.look_at_point(target.global_position)
			to = target.global_position + Vector3.UP * 0.6
			targets.append(target)
		var hit := func(node: Node3D) -> bool: return _apply_hit(node, false)
		AttackProjectile.launch(get_parent(), origin, to, species.types[0], self, targets, hit)
		_flash(Color(1.4, 1.4, 1.8))
	# Correa: no se aleja de Nate.
	if player != null:
		var next := global_position + horizontal * delta
		if next.distance_to(player.global_position) > GUARD_LEASH:
			horizontal = (player.global_position - global_position).normalized() * run_speed()
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	_sprite.animate(horizontal, delta, horizontal.length() > walk_speed())


## ¿Está esquivando (invulnerable)?
func is_dashing() -> bool:
	return _dash_time > 0.0


## Lo controla el jugador o vuelve a seguir a Nate solo.
func set_controlled(on: bool) -> void:
	controlled = on
	fight_target = null
	_windup = 0.0
	_lunge_time = 0.0
	_dash_time = 0.0
	_sprite.modulate.a = 1.0
	if not on:
		_enter(State.FOLLOW)


# --- Emboscadas desde los árboles ---------------------------------------------

## Lo cuelga de una rama de tree (Bicho) o lo posa en su copa (ave). Sin física
## hasta que caiga.
func perch_on(tree: Node3D, as_bird: bool) -> void:
	perched = true
	perch_is_bird = as_bird
	perch_tree = tree
	collision_layer = 0
	collision_mask = 0
	($BlobShadow as Decal).visible = false
	var sprite := tree.get_node("Sprite") as Sprite3D
	var tree_height := sprite.texture.get_height() * sprite.pixel_size
	global_position = tree.global_position + Vector3(0.0, tree_height * (0.92 if as_bird else 0.6), 0.0)
	if not as_bird:
		# Hilo de seda desde la rama.
		var line := BoxMesh.new()
		line.size = Vector3(0.03, tree_height * 0.25, 0.03)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.95, 0.95, 0.95, 0.8)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		line.material = material
		_thread = MeshInstance3D.new()
		_thread.mesh = line
		_thread.position.y = species.overworld_cell * world_pixel_size() + tree_height * 0.125
		add_child(_thread)
	_exclaim = _make_exclamation()
	add_child(_exclaim)
	_shake_timer = _rng.randf_range(2.0, 6.0)
	_enter(State.PERCHED)


func _process_perched(delta: float) -> void:
	_tree_shake_cue(delta)
	_in_front_of_canopy()
	if player == null:
		return
	var flat := player.global_position - global_position
	flat.y = 0.0
	var distance := flat.length()
	var hostile := species.temperament == SpeciesData.Temperament.AGGRESSIVE or species.temperament == SpeciesData.Temperament.TERRITORIAL
	var player_down := player is Player and (player as Player).mode == Player.Mode.DOWNED
	match state:
		State.PERCHED:
			if distance < AMBUSH_WATCH_RADIUS:
				_sprite.look_at_point(player.global_position)
			if hostile and not player_down and distance < AMBUSH_TRIGGER_RADIUS:
				_drop_target = player.global_position
				_exclaim.visible = true
				_enter(State.AMBUSH)
			elif species.temperament == SpeciesData.Temperament.SHY and distance < AMBUSH_SHY_FLEE_RADIUS:
				# Los tímidos se van: el ave sale volando y el Bicho se esconde en la copa.
				PixelBurst.spawn(get_parent(), global_position, PixelBurst.Kind.FOREST_LEAVES, species.size_scale)
				vanished.emit(self)
				queue_free()
		State.AMBUSH:
			if _state_time >= AMBUSH_WINDUP:
				_enter(State.DROP)
		State.DROP:
			var to_target := _drop_target - global_position
			var step := DROP_SPEED * delta
			if to_target.length() <= step:
				_land()
			else:
				global_position += to_target.normalized() * step
				_sprite.animate(Vector3(to_target.x, 0, to_target.z), delta, true)


## El árbol y el Pokémon son billboards en el mismo punto: sin separarlos se
## pelean por la profundidad y parpadean. Adelanta el sprite (y el hilo) hacia la
## cámara para que siempre quede delante de la copa.
func _in_front_of_canopy() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var to_camera := camera.global_position - global_position
	to_camera.y = 0.0
	if to_camera.length() < 0.01:
		return
	var offset := to_camera.normalized() * PERCH_FRONT_OFFSET
	_sprite.position.x = offset.x
	_sprite.position.z = offset.z
	if _thread != null:
		_thread.position.x = offset.x
		_thread.position.z = offset.z


## Aterriza: si cae sobre Nate lo golpea y empieza la pelea; si no, lo persigue.
func _land() -> void:
	perched = false
	_sprite.position.x = 0.0
	_sprite.position.z = 0.0
	global_position = _drop_target
	collision_layer = 4
	collision_mask = 3
	($BlobShadow as Decal).visible = true
	_exclaim.visible = false
	if _thread != null:
		_thread.queue_free()
		_thread = null
	home = global_position
	PixelBurst.spawn(get_parent(), global_position + Vector3.UP * 0.3, PixelBurst.Kind.LEAVES if not perch_is_bird else PixelBurst.Kind.DUST, species.size_scale)
	if player != null and player.global_position.distance_to(global_position) <= AMBUSH_HIT_RADIUS:
		_apply_hit(player, true)
		start_fight(player)
	else:
		_enter(State.CHASE)


## Pista: la copa se sacude de vez en cuando.
func _tree_shake_cue(delta: float) -> void:
	if perch_tree == null or not is_instance_valid(perch_tree) or state != State.PERCHED:
		return
	_shake_timer -= delta
	if _shake_timer > 0.0:
		return
	_shake_timer = _rng.randf_range(4.0, 7.0)
	var sprite := perch_tree.get_node("Sprite") as Sprite3D
	var base_x := sprite.position.x
	var tween := create_tween()
	for k in 4:
		tween.tween_property(sprite, "position:x", base_x + (0.06 if k % 2 == 0 else -0.06), 0.06)
	tween.tween_property(sprite, "position:x", base_x, 0.06)


## Signo de exclamación pixel art (rojo) sobre la cabeza.
func _make_exclamation() -> Sprite3D:
	var rows := ["WW", "WW", "WW", "WW", "WW", "..", "WW"]
	var image := Image.create_empty(2, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 2:
			if rows[y][x] == "W":
				image.set_pixel(x, y, Color(1.0, 0.25, 0.2))
	var sprite := Sprite3D.new()
	sprite.name = "Exclamation"
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.pixel_size = PIXEL_SIZE * 2.0
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.layers = WorldBuilder.VISUAL_LAYER_SPRITES
	sprite.position.y = species.overworld_cell * world_pixel_size() + 0.5
	sprite.visible = false
	return sprite


# --- Peleas en el mundo -----------------------------------------------------

## Pelea a distancia si su ataque especial supera al físico; si no, cuerpo a cuerpo.
func is_ranged() -> bool:
	return species.sp_attack > species.attack


func attack_range() -> float:
	return RANGED_MAX if is_ranged() else MELEE_RANGE


## Empieza (o cambia) a pelear con target: otro Pokémon o el jugador.
func start_fight(target: Node3D) -> void:
	if target == null or target == self or state == State.STUNNED or legendary:
		return
	# Contra el jugador rige el área de persecución: si no venía persiguiéndolo, el
	# área empieza aquí (o en su casa, si es territorial).
	if target == player and state != State.CHASE:
		chase_origin = home if species.temperament == SpeciesData.Temperament.TERRITORIAL else global_position
	fight_target = target
	_enter(State.FIGHT)


## Recibe un golpe: baja la vida, parpadea y responde (o huye si es tímido).
func receive_hit(damage: float, from: Node3D) -> void:
	if state == State.STUNNED or is_dashing():
		return
	hp = maxf(hp - damage, 0.0)
	_health_bar.set_ratio(hp / hp_max)
	_flash(Color(1, 0.4, 0.4))
	_unseen_time = 0.0
	if hp <= 0.0:
		_stun()
		return
	if role == Role.COMPANION:
		if controlled:
			return
		if fight_target == null or not is_instance_valid(fight_target):
			start_fight(from)
		return
	var crowded := from is PokemonActor and (from as PokemonActor).role == Role.COMPANION \
			and (from as PokemonActor).attackers_count() >= GUARD_MAX_ATTACKERS and fight_target != from
	if (species.temperament == SpeciesData.Temperament.SHY and state != State.FIGHT) or crowded:
		_enter(State.FLEE)
	elif state != State.FIGHT or fight_target != from:
		start_fight(from)


## Daño de un ataque de attacker contra defender (estadísticas, tipo y azar).
static func compute_damage(attacker: SpeciesData, defender: SpeciesData, physical: bool, rng: RandomNumberGenerator) -> float:
	var attack_stat := float(attacker.attack if physical else attacker.sp_attack)
	var defense_stat := float(defender.defense if physical else defender.sp_defense)
	var type: PokemonTypes.Type = attacker.types[0]
	var stab := 1.5
	var effectiveness := TypeChart.effectiveness(type, defender.types)
	return 6.0 * (attack_stat / maxf(defense_stat, 1.0)) * stab * effectiveness * rng.randf_range(0.85, 1.0)


## Daño al jugador (en medios corazones): de 1 a 6 según el ataque del Pokémon.
func damage_to_player() -> float:
	return clampf(1.0 + maxf(species.attack, species.sp_attack) / 45.0, 1.0, 6.0)


func _think_fight() -> Array:
	if not _fight_target_valid():
		fight_target = null
		_enter(State.IDLE if role == Role.WILD else State.FOLLOW)
		return [global_position, 0.0]
	# Si el jugador sale del área de persecución, el salvaje se rinde y regresa.
	if role == Role.WILD and fight_target == player and player.global_position.distance_to(chase_origin) > chase_leash():
		fight_target = null
		_ignore_player = 6.0
		_enter(State.RETURN)
		return [home, walk_speed()]
	var target_pos := fight_target.global_position
	var distance := global_position.distance_to(target_pos)
	_sprite.look_at_point(target_pos)
	if _windup > 0.0:
		_windup -= get_physics_process_delta_time()
		if _windup <= 0.0:
			_deliver_attack()
		return [global_position, 0.0]
	if is_ranged():
		if distance > RANGED_MAX:
			return [target_pos, run_speed()]
		if distance < RANGED_MIN:
			var away := (global_position - target_pos)
			away.y = 0.0
			return [global_position + away.normalized() * 3.0, walk_speed()]
	elif distance > MELEE_RANGE:
		return [target_pos, run_speed()]
	if _attack_cooldown <= 0.0:
		_windup = ATTACK_WINDUP
		_flash(Color(1.6, 1.6, 1.6))
	return [global_position, 0.0]


func _fight_target_valid() -> bool:
	if fight_target == null or not is_instance_valid(fight_target):
		return false
	if fight_target is PokemonActor and (fight_target as PokemonActor).state == State.STUNNED:
		return false
	if fight_target is Player and (fight_target as Player).mode == Player.Mode.DOWNED and role == Role.WILD:
		# Con el jugador desmayado, pelean con su compañero (si los enfrenta).
		return false
	return global_position.distance_to(fight_target.global_position) < 30.0


func _deliver_attack() -> void:
	_attack_cooldown = _rng.randf_range(ATTACK_COOLDOWN_MIN, ATTACK_COOLDOWN_MAX)
	if not _fight_target_valid():
		return
	var origin := global_position + Vector3.UP * 0.6 * species.size_scale
	if is_ranged():
		var hit := func(node: Node3D) -> bool: return _apply_hit(node, false)
		AttackProjectile.launch(get_parent(), origin, fight_target.global_position + Vector3.UP * 0.6, species.types[0], self, [fight_target] as Array[Node3D], hit)
	elif global_position.distance_to(fight_target.global_position) <= MELEE_RANGE + 0.6:
		# Embestida: un pequeño impulso hacia el objetivo y el golpe.
		var lunge := fight_target.global_position - global_position
		lunge.y = 0.0
		velocity += lunge.normalized() * 6.0
		_apply_hit(fight_target, true)


func _apply_hit(node: Node3D, physical: bool) -> bool:
	if node is PokemonActor:
		var target := node as PokemonActor
		target.receive_hit(compute_damage(species, target.species, physical, _rng), self)
		return true
	if node is Player:
		var target_player := node as Player
		if target_player.mode == Player.Mode.DOWNED:
			return false
		target_player.take_damage(damage_to_player())
		contact_with_player.emit(self)
		return true
	return false


## Busca un rival cercano según su naturaleza: enemigos clásicos, manadas rivales,
## agresivos contra más débiles, territoriales contra intrusos y ventaja de tipo.
func _find_rival() -> PokemonActor:
	if role != Role.WILD or legendary or species.temperament == SpeciesData.Temperament.SHY:
		return null
	for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
		var other := node as PokemonActor
		if other == self or other.state == State.STUNNED or other.swimming != swimming:
			continue
		if global_position.distance_to(other.global_position) > RIVAL_RADIUS:
			continue
		if group_id >= 0 and other.group_id == group_id:
			continue
		if CLASSIC_ENEMIES.get(species.identifier, []).has(other.species.identifier):
			return other
		var same_line := other.species.evolution_chain == species.evolution_chain
		var hostile := species.temperament == SpeciesData.Temperament.AGGRESSIVE \
				or species.temperament == SpeciesData.Temperament.TERRITORIAL
		if group_id >= 0 and other.group_id >= 0 and hostile:
			return other  # Manadas rivales.
		if same_line:
			continue
		if species.temperament == SpeciesData.Temperament.AGGRESSIVE \
				and (other.species.base_total < species.base_total - 30 or TypeChart.has_advantage(species.types, other.species.types)):
			return other
		if species.temperament == SpeciesData.Temperament.TERRITORIAL and other.global_position.distance_to(home) <= TERRITORY_RADIUS:
			return other
	return null


## Debilitado: aturdido STUN_TIME s con estrellitas (se puede capturar). Después, si
## es salvaje, desaparece en humo; si es el compañero, lo decide la escena principal.
func _stun() -> void:
	velocity = Vector3.ZERO
	_windup = 0.0
	fight_target = null
	_enter(State.STUNNED)
	_tell_pack_fight_over()
	_dizzy = DizzyStars.create(species.overworld_cell * world_pixel_size() + 0.1, maxf(1.0, species.size_scale * 0.8))
	add_child(_dizzy)
	stunned.emit(self)
	# Tono apagado después del parpadeo del golpe.
	await get_tree().create_timer(0.25).timeout
	if state == State.STUNNED:
		_sprite.modulate = Color(0.75, 0.75, 0.85)


func _process_stunned(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not swimming:
		velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
		move_and_slide()
	if role == Role.WILD and _state_time >= STUN_TIME:
		PixelBurst.spawn(get_parent(), global_position + Vector3.UP * 0.5 * species.size_scale, PixelBurst.Kind.SMOKE, species.size_scale)
		vanished.emit(self)
		queue_free()


## Se recupera (lo usa el compañero al volver de su Pokéball).
func recover(ratio: float) -> void:
	hp = hp_max * ratio
	_health_bar.set_ratio(hp / hp_max)
	_sprite.modulate = Color.WHITE
	if _dizzy != null:
		_dizzy.queue_free()
		_dizzy = null
	_enter(State.FOLLOW if role == Role.COMPANION else State.IDLE)


func _tell_pack_fight_over() -> void:
	# Quien peleaba con este Pokémon vuelve a lo suyo (el ganador queda herido).
	for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
		var other := node as PokemonActor
		if other.fight_target == self:
			other.fight_target = null


func _flash(color: Color) -> void:
	_sprite.modulate = color
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.2)


## Punto a un costado de Nate (derecha de la cámara), más lejos si es grande.
func _beside_player() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var right := Vector3.RIGHT
	if camera != null:
		right = camera.global_basis.x
		right.y = 0.0
		right = right.normalized()
	return player.global_position + right * (1.6 + species.size_scale * 0.6)


## Salvaje que amenaza a Nate: lo persigue o ataca cerca, o (con Nate desmayado)
## entra a la zona de guardia.
func _threat_to_player() -> PokemonActor:
	var downed := player is Player and (player as Player).mode == Player.Mode.DOWNED
	var radius := GUARD_RADIUS if downed else DEFEND_RADIUS
	for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
		var other := node as PokemonActor
		if other.state == State.STUNNED or other.global_position.distance_to(player.global_position) > radius:
			continue
		if downed or other.fight_target == player or other.state == State.CHASE:
			return other
	return null


## Cuántos salvajes pelean ahora con este Pokémon.
func attackers_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
		if (node as PokemonActor).fight_target == self:
			count += 1
	return count


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


## Legendario cauteloso: pasea; si te ve (cono frontal) o te oye (cerca o corriendo),
## muestra "?" y escapa: vuela si es de tipo Volador o tiene forma de ave, si no corre.
func _think_legendary() -> Array:
	match state:
		State.NOTICE:
			_sprite.look_at_point(player.global_position)
			if _state_time >= LEGEND_NOTICE_TIME:
				_choose_escape_target()
				if can_fly():
					_fly_start = global_position
					_enter(State.FLY)
				else:
					_enter(State.ESCAPE)
			return [global_position, 0.0]
		State.ESCAPE:
			_question.visible = _state_time < 0.6
			if global_position.distance_to(_escape_target) < 2.0 or _state_time > 12.0:
				home = global_position
				_ignore_player = 4.0
				_enter(State.IDLE)
				return [global_position, 0.0]
			return [_escape_target, run_speed() * 1.3]
	_question.visible = false
	if player != null and _ignore_player <= 0.0 and notices_player():
		_enter(State.NOTICE)
		_question.visible = true
		return [global_position, 0.0]
	if state == State.WANDER:
		if _agent.is_navigation_finished() or _state_time > 8.0:
			_enter(State.IDLE)
			return [global_position, 0.0]
		return [_agent.target_position, walk_speed() * 0.5]
	if _state_time >= _idle_duration:
		_enter(State.WANDER)
	return [global_position, 0.0]


## ¿Lo ve (en su cono de visión) o lo oye (muy cerca, o corriendo cerca)?
func notices_player() -> bool:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	var hearing := LEGEND_HEARING
	if player is Player and (player as Player).get_ground_speed() > (player as Player).config.walk_speed + 0.5:
		hearing = LEGEND_HEARING_RUNNING
	if distance <= hearing:
		return true
	if distance > LEGEND_SIGHT or distance < 0.01:
		return false
	return _sprite.facing_world.dot(to_player / distance) >= LEGEND_SIGHT_CONE


## Vuela si es de tipo Volador, o si es un dragón grande (Rayquaza, Latias…).
func can_fly() -> bool:
	var big_dragon := species.types.has(PokemonTypes.Type.DRAGON) and species.height_m > 3.0
	return species.types.has(PokemonTypes.Type.FLYING) or big_dragon


## Un lugar seguro lejos del jugador: de varios candidatos alejándose de él, el punto
## transitable (sobre la malla de navegación, en tierra firme) que quede más lejos.
func _choose_escape_target() -> void:
	var away := global_position - player.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var map := get_world_3d().navigation_map
	var best := global_position + away * LEGEND_ESCAPE_DISTANCE
	var best_distance := -1.0
	for attempt in 16:
		var dir := away.rotated(Vector3.UP, _rng.randf_range(-1.4, 1.4))
		var candidate := global_position + dir * LEGEND_ESCAPE_DISTANCE * _rng.randf_range(0.8, 1.2)
		if world != null:
			if world.water_depth_at(candidate.x, candidate.z) > -0.3:
				continue
			candidate.y = world.surface_height_at(candidate.x, candidate.z)
		if not can_fly():
			# Solo destinos alcanzables: el camino calculado debe llegar hasta ahí
			# (en la cumbre la navegación puede tener zonas aisladas).
			candidate = NavigationServer3D.map_get_closest_point(map, candidate)
			var path := NavigationServer3D.map_get_path(map, global_position, candidate, true)
			if path.is_empty() or path[path.size() - 1].distance_to(candidate) > 1.5:
				continue
			# Nunca escapar pasando junto al jugador.
			var passes_player := false
			for point in path:
				if point.distance_to(player.global_position) < ESCAPE_PLAYER_CLEARANCE:
					passes_player = true
					break
			if passes_player:
				continue
		var distance := candidate.distance_to(player.global_position)
		if distance > best_distance:
			best_distance = distance
			best = candidate
	_escape_target = best


## Vuelo de reubicación: sube en arco y aterriza en el lugar seguro.
func _fly(delta: float) -> void:
	_question.visible = _state_time < 0.6
	var total := Vector2(_escape_target.x - _fly_start.x, _escape_target.z - _fly_start.z).length()
	var t := clampf(_state_time * FLY_SPEED / maxf(total, 1.0), 0.0, 1.0)
	var flat := _fly_start.lerp(_escape_target, t)
	global_position = Vector3(flat.x, flat.y + sin(t * PI) * FLY_HEIGHT, flat.z)
	_sprite.animate((_escape_target - _fly_start).normalized() * FLY_SPEED, delta, true)
	if t >= 1.0:
		home = global_position
		_ignore_player = 4.0
		_enter(State.IDLE)


## Signo de interrogación pixel art (7×11) sobre la cabeza.
func _make_question_mark() -> Sprite3D:
	var rows := [".WWWWW.", "WW...WW", "WW...WW", ".....WW", "....WW.", "...WW..", "...WW..", ".......", "...WW..", "...WW.."]
	var image := Image.create_empty(7, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 7:
			if rows[y][x] == "W":
				image.set_pixel(x, y, Color(1.0, 0.95, 0.3))
	var sprite := Sprite3D.new()
	sprite.name = "QuestionMark"
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.pixel_size = PIXEL_SIZE * 1.5
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.layers = WorldBuilder.VISUAL_LAYER_SPRITES
	sprite.position.y = species.overworld_cell * world_pixel_size() + 0.4
	sprite.visible = false
	return sprite


func _check_contact() -> void:
	# Los legendarios nunca inician un combate por contacto.
	if legendary:
		return
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


# --- Captura --------------------------------------------------------------------

## Dentro de la Pokéball: invisible y en pausa (conserva su estado, p. ej. aturdido).
func set_inside_ball(inside: bool) -> void:
	visible = not inside
	process_mode = Node.PROCESS_MODE_DISABLED if inside else Node.PROCESS_MODE_INHERIT
	collision_layer = 0 if inside else (0 if swimming or perched else 4)


## Capturado: sale del mundo.
func captured() -> void:
	vanished.emit(self)
	queue_free()


## Escapó de la Pokéball: si estaba aturdido sigue así; si no, se enoja o huye.
func escape_from_ball(thrower: Node3D) -> void:
	_unseen_time = 0.0
	if state == State.STUNNED or thrower == null:
		return
	if legendary:
		_choose_escape_target()
		_fly_start = global_position
		_enter(State.FLY if can_fly() else State.ESCAPE)
		return
	match species.temperament:
		SpeciesData.Temperament.AGGRESSIVE, SpeciesData.Temperament.TERRITORIAL:
			start_fight(thrower)
		_:
			_enter(State.FLEE)


## Hacia dónde mira en el mundo (para el sigilo de la captura).
func facing_world() -> Vector3:
	return _sprite.facing_world


## Dirección visible (para pruebas).
func get_visible_facing() -> DirectionalSprite.Facing:
	return _sprite.visible_facing()
