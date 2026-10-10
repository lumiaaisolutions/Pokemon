extends Node3D
## Escena principal: al iniciar, un Pokémon básico al azar acompaña al jugador
## (hasta que exista la selección de inicial de la Fase 5).

const ACTOR_SCENE := preload("res://world/actors/pokemon_actor.tscn")
const STARTER_POOL := preload("res://creatures/data/basic_pool.tres")

var companion: PokemonActor

@onready var _player: Player = $Player
@onready var _navigation: WorldNavigation = $Navigation


## Ceremonia del inicial al empezar (las pruebas la apagan y usan un compañero al azar).
@export var starter_ceremony := true


func _ready() -> void:
	$Spawner.wild_contact.connect(_on_wild_contact)
	GameState.wild_defeated.connect(_on_wild_defeated)
	GameState.dex_changed.connect(_on_dex_changed)
	_player.blacked_out.connect(_on_blacked_out)
	_player.downed.connect(_on_player_downed)
	_player.revived.connect(_on_player_revived)
	($Hud as Hud).main = self
	# Clima por bioma y eventos del mundo.
	var weather := Weather.new()
	weather.name = "Weather"
	weather.world_path = NodePath("../World")
	weather.player_path = NodePath("../Player")
	add_child(weather)
	var events := WorldEvents.new()
	events.name = "Events"
	events.world_path = NodePath("../World")
	events.player_path = NodePath("../Player")
	events.spawner_path = NodePath("../Spawner")
	add_child(events)
	# Combate en arena (Fase 3) y música según el lugar.
	var battle := BattleManager.new()
	battle.name = "Battle"
	add_child(battle)
	battle.ended.connect(_on_battle_ended)
	var music := MusicDirector.new()
	music.name = "Music"
	add_child(music)
	var photo := PhotoMode.new()
	photo.name = "Photo"
	add_child(photo)
	# Habitantes de los pueblos con rutina (Fase 2.7).
	var npcs := TownNPCs.new()
	npcs.name = "TownNPCs"
	npcs.world_path = NodePath("../World")
	npcs.player_path = NodePath("../Player")
	add_child(npcs)
	# Puntos de interés del campo (campamentos, pozos, ruinas, árboles, cuevas, miradores).
	var pois := PointsOfInterest.new()
	pois.name = "PointsOfInterest"
	add_child(pois)
	# Rival (Hugh): te busca tras cada medalla y de vez en cuando en el mundo.
	var rival := Rival.new()
	rival.name = "Rival"
	add_child(rival)
	# Profesor (laboratorio y viajes) y su asistente.
	var professor := Professor.new()
	professor.name = "Professor"
	add_child(professor)
	# Taquilla de viajes a otras regiones (barco o avión) en el pueblo inicial.
	var terminal := TravelTerminal.new()
	terminal.name = "TravelTerminal"
	add_child(terminal)
	# Líderes de gimnasio con su vida: gimnasio, entrenamiento, casa y viajes.
	var leaders := GymLeaders.new()
	leaders.name = "GymLeaders"
	add_child(leaders)
	# Héroes no elegidos: entrenadores únicos que viajan por la región.
	var heroes := Heroes.new()
	heroes.name = "Heroes"
	add_child(heroes)
	# Entrenadores en los caminos (Fase 5.6).
	var trainers := RouteTrainers.new()
	trainers.name = "RouteTrainers"
	add_child(trainers)
	# Menú (Esc / Options) en su propia capa, sobre el HUD.
	var menu_layer := CanvasLayer.new()
	menu_layer.name = "MenuLayer"
	menu_layer.layer = 20
	add_child(menu_layer)
	var menu := GameMenu.new()
	menu.name = "GameMenu"
	menu.main = self
	menu_layer.add_child(menu)
	GameOptions.load_options()
	if SaveSystem.pending_position != Vector3.INF:
		# Partida cargada: el jugador vuelve a donde guardó.
		_player.global_position = SaveSystem.pending_position + Vector3.UP * 0.5
		SaveSystem.pending_position = Vector3.INF
	else:
		# Partida nueva: en la plaza del pueblo inicial.
		_player.global_position = ($World as WorldBuilder).start_position()
		GameState.respawn_point = _player.global_position
	($CameraRig as CameraRig).snap()
	_warm_up_shaders()
	# Primera llegada a una región nueva (tras el viaje).
	if Regions.index() > 0 and not GameState.world_flags.get("arrived", false):
		GameState.world_flags["arrived"] = true
		GameState.respawn_point = _player.global_position
		var welcome := "¡Bienvenido a la %s! El Prof. %s te espera en su laboratorio." % [Regions.region_name(), GameState.professor]
		get_tree().create_timer(1.5).timeout.connect(func() -> void: GameState.notice.emit(welcome))
	if starter_ceremony and GameState.party.is_empty():
		_start_ceremony.call_deferred()
	else:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		if GameState.party.is_empty():
			var starter: SpeciesData = STARTER_POOL.pick_distinct(rng, 1)[0]
			GameState.party.append({"species": starter.identifier, "shiny": false, "hp_ratio": 1.0})
			GameState.companion_index = 0
		var entry: Dictionary = GameState.party[GameState.companion_index]
		_create_companion(MenuStyle.species(entry["species"]), entry.get("shiny", false), _player.position + Vector3(1.5, 0.3, 1.5))


var _autosave_timer := SaveSystem.AUTOSAVE_SECONDS


func _process(delta: float) -> void:
	GameState.play_time += delta
	_update_wheel()
	_update_bond(delta)
	_command_moves()
	_autosave_timer -= delta
	if _autosave_timer <= 0.0 and not GameState.party.is_empty() and _player.mode == Player.Mode.WALK:
		_autosave_timer = SaveSystem.AUTOSAVE_SECONDS
		if SaveSystem.save_slot(0, self):
			($Hud as Hud).show_toast("Autoguardado")


## Guarda la vida del compañero en su ficha del equipo (al abrir el menú o guardar).
func sync_companion_to_party() -> void:
	if companion == null or GameState.party.is_empty():
		return
	var index := clampi(GameState.companion_index, 0, GameState.party.size() - 1)
	GameState.party[index]["hp_ratio"] = companion.hp / companion.hp_max


## Vuelve a crear al acompañante actual (tras evolucionar), en el mismo lugar y estado.
func refresh_companion() -> void:
	if companion == null or GameState.party.is_empty():
		return
	var at := companion.global_position
	var was_out := companion_state == CompanionState.OUT
	if _player.mount == companion:
		_player.end_ride()
	if _player.riding == companion:
		_player.riding = null
	companion.queue_free()
	companion = null
	var entry: Dictionary = GameState.party[GameState.companion_index]
	_create_companion(MenuStyle.species(entry["species"]), entry.get("shiny", false), at)
	if not was_out:
		companion.visible = false
		companion.process_mode = Node.PROCESS_MODE_DISABLED
		companion_state = CompanionState.IN_BALL


## Cambia de acompañante por otro del equipo (desde el menú).
func swap_companion(index: int) -> void:
	if index == GameState.companion_index or index < 0 or index >= GameState.party.size():
		return
	sync_companion_to_party()
	var at := _player.global_position + _side_offset()
	var was_out := companion_state == CompanionState.OUT
	if companion != null:
		if _player.mount == companion:
			_player.end_ride()
		if _player.riding == companion:
			_player.riding = null
		companion.queue_free()
		companion = null
	GameState.companion_index = index
	var entry: Dictionary = GameState.party[index]
	_create_companion(MenuStyle.species(entry["species"]), entry.get("shiny", false), at)
	if not was_out:
		companion.visible = false
		companion.process_mode = Node.PROCESS_MODE_DISABLED
		companion_state = CompanionState.IN_BALL
	($Hud as Hud).show_toast("¡%s te acompaña ahora!" % companion.species.display_name)


func _create_companion(species: SpeciesData, shiny: bool, at: Vector3) -> void:
	companion = ACTOR_SCENE.instantiate() as PokemonActor
	companion.species = species
	companion.shiny = shiny
	companion.role = PokemonActor.Role.COMPANION
	if not GameState.party.is_empty():
		var member: Dictionary = GameState.party[clampi(GameState.companion_index, 0, GameState.party.size() - 1)]
		companion.gender = int(member.get("gender", -1))
		companion.size_factor = float(member.get("size", 1.0))
		Moves.ensure_entry(member)
		companion.party_entry = member
	companion.player = _player
	companion.world = $World
	companion.position = at
	add_child(companion)
	companion.stunned.connect(_on_companion_stunned)
	companion_state = CompanionState.OUT
	# Vida guardada en su ficha del equipo.
	if not GameState.party.is_empty():
		var ratio := float(GameState.party[clampi(GameState.companion_index, 0, GameState.party.size() - 1)].get("hp_ratio", 1.0))
		if ratio < 0.999 and ratio > 0.0:
			companion.recover.call_deferred(ratio)


## Los 5 huevos eclosionan; sin salvajes cerca mientras eliges.
func _start_ceremony() -> void:
	($Spawner as Node).set_process(false)
	var ceremony := StarterCeremony.new()
	ceremony.name = "StarterCeremony"
	ceremony.player = _player
	ceremony.world = $World
	ceremony.hud = $Hud
	add_child(ceremony)
	ceremony.chosen.connect(func(species: SpeciesData, shiny: bool, at: Vector3) -> void:
		_create_companion(species, shiny, at + Vector3.UP * 0.3)
		PixelBurst.spawn(self, at + Vector3.UP * 0.5, PixelBurst.Kind.HEAL, 1.5)
		($Hud as Hud).show_toast("¡%s será tu compañero de viaje!" % species.display_name)
		($Spawner as Node).set_process(true)
		ceremony.queue_free())
	await ceremony.start()


## Estado del compañero para el HUD.
enum CompanionState { OUT, IN_BALL, FAINTED }

var companion_state: CompanionState = CompanionState.OUT
var _busy := false


## Agua: si el compañero es de tipo Agua, el jugador surfea sobre él; si no, el
## compañero vuelve a su Pokéball mientras el jugador nada y sale al volver a tierra.
var _recalled_for_water := false


func _physics_process(_delta: float) -> void:
	if companion == null:
		return
	var in_water := _player.mode == Player.Mode.SWIM or _player.mode == Player.Mode.DIVE
	if _player.ride == Player.Ride.MOUNT or _player.ride == Player.Ride.FLY:
		return
	if in_water and companion_state == CompanionState.OUT and not _busy and not companion.controlled:
		if companion.can_surf():
			if _player.riding == null:
				_player.riding = companion
				companion.set_ridden(_player)
				($Hud as Hud).show_toast("¡Surfeas sobre %s!" % companion.species.display_name)
		elif _player.riding == null:
			_recalled_for_water = true
			_recall_companion()
	elif not in_water:
		if _player.riding != null:
			_player.riding = null
			companion.set_ridden(null)
			companion.global_position = _player.global_position + _side_offset()
		if _recalled_for_water and companion_state == CompanionState.IN_BALL and not _busy and _player.mode == Player.Mode.WALK:
			_recalled_for_water = false
			_send_out_companion()


## Órdenes al compañero mientras exploras: 1-4 (R1 + □ △ ○ ✕) usan sus movimientos.
func _command_moves() -> void:
	if companion == null or companion_state != CompanionState.OUT or companion.controlled or _player.mode == Player.Mode.DOWNED:
		return
	for slot in 4:
		if MoveInput.just_pressed(slot):
			var message := companion.command_move(slot, MoveInput.style())
			if message != "":
				($Hud as Hud).show_toast(message)


## Vínculo: sube con el tiempo que el compañero pasa fuera contigo (Lujo Ball ×2).
const BOND_MINUTES_PER_LEVEL := 20.0


func _update_bond(delta: float) -> void:
	if companion == null or companion_state != CompanionState.OUT or GameState.party.is_empty():
		return
	var entry: Dictionary = GameState.party[GameState.companion_index]
	var factor := 2.0 if entry.get("ball", "") == "luxury-ball" else 1.0
	entry["bond_xp"] = float(entry.get("bond_xp", 0.0)) + delta / 60.0 * factor
	var bond := clampi(1 + int(float(entry["bond_xp"]) / BOND_MINUTES_PER_LEVEL), 1, 10)
	if bond > int(entry.get("bond", 1)):
		entry["bond"] = bond
		($Hud as Hud).show_toast("¡Tu vínculo con %s subió a %d!%s" % [companion.species.display_name, bond,
				" Ahora aguanta un golpe fatal por pelea." if bond == 5 else (" Ahora da golpes críticos." if bond == 8 else "")])


## Cada salvaje que debilita tu compañero le da 1 Punto de Entrenamiento por repartir.
func _on_wild_defeated(_identifier: String) -> void:
	if GameState.party.is_empty():
		return
	var entry: Dictionary = GameState.party[GameState.companion_index]
	var used := TeamTab._total(entry.get("training", {})) + int(entry.get("training_free", 0))
	if used < TeamTab.MAX_TOTAL:
		entry["training_free"] = int(entry.get("training_free", 0)) + 1


## Investigación de la especie en niveles 3, 6 y 9: desbloquea su siguiente movimiento.
func _on_dex_changed(identifier: String) -> void:
	for entry: Dictionary in GameState.party:
		if entry["species"] != identifier:
			continue
		var level := Research.level(identifier)
		var done := int(entry.get("research_unlocks", 0))
		while done < 3 and level >= (done + 1) * 3:
			done += 1
			var learned := Moves.unlock_next(entry)
			if learned != "":
				AudioBus.play_jingle("me_waza")
				($Hud as Hud).show_toast("¡La investigación desbloqueó %s para %s!" % [Moves.get_move(learned)["name"], MenuStyle.species(identifier).display_name])
		entry["research_unlocks"] = done
	# Misiones de megapiedras (se abren con el equipo y se cumplen al capturar o investigar).
	for message in MegaMissions.update():
		($Hud as Hud).show_toast(message)


## Botón del compañero: tocar lo guarda o lo saca; mantener (más de WHEEL_HOLD s) abre
## la rueda de cambio rápido con el equipo.
const WHEEL_HOLD := 0.35
var _companion_pressed_at := -1
var _wheel: CompanionWheel


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ride") and _player.mode == Player.Mode.WALK:
		toggle_ride()
		return
	if event.is_action_pressed("companion") and companion != null and not _busy and _player.mode == Player.Mode.WALK:
		_companion_pressed_at = Time.get_ticks_msec()
	elif event.is_action_released("companion") and _companion_pressed_at >= 0:
		_companion_pressed_at = -1
		if _wheel != null and _wheel.visible:
			var index := _wheel.close()
			if index >= 0 and index != GameState.companion_index:
				var battle := get_node_or_null("Battle") as BattleManager
				if battle != null and battle.active:
					battle.switch_to(index)
				else:
					swap_companion(index)
			return
		if companion == null or _busy:
			return
		# En combate, tocar Q no guarda al Pokémon (mantener abre la rueda).
		var in_battle := get_node_or_null("Battle") as BattleManager
		if in_battle != null and in_battle.active:
			return
		if companion_state == CompanionState.OUT:
			_recall_companion()
		elif companion_state == CompanionState.IN_BALL:
			_send_out_companion()


## Montar / bajarse (V o ←): montura si el compañero es grande (y vuela si es volador;
## despega con saltar), o la bicicleta si la tienes.
func toggle_ride() -> String:
	var message := ""
	if _player.ride != Player.Ride.NONE:
		if _player.ride == Player.Ride.FLY and _player.height_above_ground() > Player.LAND_HEIGHT:
			message = "Baja primero (%s) para aterrizar." % InputHints.hint("dive")
		else:
			var was_bike := _player.ride == Player.Ride.BIKE
			_player.end_ride()
			message = "Te bajaste de la bicicleta." if was_bike else "Te bajaste de %s." % companion.species.display_name
	elif companion != null and companion_state == CompanionState.OUT and not companion.controlled and not _busy and Player.can_mount(companion) \
			and GameState.world_flags.get("ride_license", false):
		_player.start_mount(companion)
		var flies: bool = Player.can_carry_flying(companion) and GameState.world_flags.get("fly_license", false)
		message = "¡Montas a %s!%s%s" % [companion.species.display_name,
				(" Salta (%s) para volar." % InputHints.hint("jump")) if flies else "",
				" Puede subir paredes empinadas." if Player.can_climb(companion) else ""]
		Achievements.add("rides")
	elif companion != null and companion_state == CompanionState.OUT and Player.can_mount(companion) and not GameState.world_flags.get("ride_license", false):
		message = "Aún no tienes la Licencia de Montura: pídesela al Prof. %s (1 medalla o 2 actividades del Rotom)." % GameState.professor
	elif GameState.item_count("bicycle") > 0:
		message = _player.toggle_bicycle()
	elif companion != null and companion_state == CompanionState.OUT:
		message = "%s es muy pequeño para montarlo." % companion.species.display_name
	else:
		message = "Saca a tu compañero para montarlo."
	if message != "":
		($Hud as Hud).show_toast(message)
	return message


func _update_wheel() -> void:
	if _companion_pressed_at < 0 or GameState.party.size() < 2:
		return
	if (Time.get_ticks_msec() - _companion_pressed_at) / 1000.0 < WHEEL_HOLD:
		return
	if _wheel == null:
		_wheel = CompanionWheel.new()
		get_node("MenuLayer").add_child(_wheel)
	if not _wheel.visible:
		_wheel.open()


## Lo regresa a su Pokéball: destello rojo, se encoge hacia Nate y desaparece.
func _recall_companion() -> void:
	if _player.mount == companion:
		_player.end_ride()
	_busy = true
	companion.set_controlled(false)
	companion.fight_target = null
	companion.set_physics_process(false)
	var sprite := companion.get_node("Sprite") as Node3D
	var fx := RecallBeam.new()
	add_child(fx)
	fx.ball.global_position = _hand_position()
	# La ball en la mano dispara el rayo rojo; el Pokémon se pone rojo, se encoge y
	# viaja por el rayo hasta la ball.
	var start := companion.global_position
	var center := Vector3.UP * companion.species.overworld_cell * companion.world_pixel_size() * 0.4
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(2.2, 0.35, 0.35), 0.12)
	tween.parallel().tween_method(func(_t: float) -> void: fx.set_beam(fx.ball.global_position, companion.global_position + center), 0.0, 1.0, 0.12)
	tween.tween_method(func(t: float) -> void:
		companion.global_position = start.lerp(fx.ball.global_position - center * 0.2, t * t)
		sprite.scale = Vector3.ONE * lerpf(1.0, 0.05, t)
		fx.set_beam(fx.ball.global_position, companion.global_position + center * (1.0 - t)), 0.0, 1.0, 0.35)
	await tween.finished
	fx.hide_beam()
	PixelBurst.spawn(self, fx.ball.global_position, PixelBurst.Kind.HEAL, 0.4)
	companion.visible = false
	companion.process_mode = Node.PROCESS_MODE_DISABLED
	sprite.scale = Vector3.ONE
	sprite.modulate = Color.WHITE
	companion.set_physics_process(true)
	companion_state = CompanionState.IN_BALL
	($Hud as Hud).show_toast("%s, ¡regresa!" % companion.species.display_name)
	await get_tree().create_timer(0.25).timeout
	fx.queue_free()
	_busy = false


## Lo saca de su Pokéball: la ball vuela en arco, se abre con un destello y el rayo
## rojo forma al Pokémon, que crece desde la ball.
func _send_out_companion() -> void:
	_busy = true
	var fx := RecallBeam.new()
	add_child(fx)
	var from := _hand_position()
	var to := _player.global_position + _side_offset()
	to.y = ($World as WorldBuilder).surface_height_at(to.x, to.z) + 0.15
	# La ball se abre en la mano con un destello y el relámpago rojo va hasta donde
	# aparece el Pokémon, que se forma rojo y crece.
	fx.ball.global_position = from
	fx.flash(from, 0.8)
	PixelBurst.spawn(self, to + Vector3.UP * 0.2, PixelBurst.Kind.SMOKE, 0.4)
	companion.process_mode = Node.PROCESS_MODE_INHERIT
	companion.visible = true
	companion.global_position = to + Vector3.UP * 0.15
	companion.velocity = Vector3.ZERO
	var sprite := companion.get_node("Sprite") as Node3D
	sprite.scale = Vector3.ONE * 0.05
	sprite.modulate = Color(2.2, 0.4, 0.4)
	var height := companion.species.overworld_cell * companion.world_pixel_size()
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		fx.set_beam(from, to + Vector3.UP * height * 0.45 * t)
		sprite.scale = Vector3.ONE * lerpf(0.05, 1.0, t), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		fx.hide_beam()
		fx.flash(to + Vector3.UP * height * 0.45, 1.2))
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	await tween.finished
	await get_tree().create_timer(0.2).timeout
	fx.queue_free()
	companion_state = CompanionState.OUT
	($Hud as Hud).show_toast("¡Adelante, %s!" % companion.species.display_name)
	_busy = false


## Mano del jugador: a un costado, a la altura del pecho.
func _hand_position() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_basis.x if camera != null else Vector3.RIGHT
	right.y = 0.0
	return _player.global_position + Vector3.UP * 1.0 + right.normalized() * 0.35


func _side_offset() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_basis.x if camera != null else Vector3.RIGHT
	right.y = 0.0
	return right.normalized() * 1.6 + Vector3.UP * 0.3


## Nate cayó: su compañero sale (si estaba guardado) y el jugador lo controla
## para protegerlo mientras se recupera; la cámara lo sigue.
func _on_player_downed() -> void:
	if companion == null:
		return
	if companion_state == CompanionState.IN_BALL:
		await _send_out_companion()
	if companion_state != CompanionState.OUT or _player.mode != Player.Mode.DOWNED:
		return
	companion.set_controlled(true)
	($CameraRig as CameraRig).set_target(companion)


## Nate se levantó: el compañero vuelve a seguirlo solo.
func _on_player_revived() -> void:
	if companion == null:
		return
	companion.set_controlled(false)
	($CameraRig as CameraRig).set_target(_player)
	($Hud as Hud).show_toast("¡%s se recuperó!" % GameState.player_name)


## El compañero se debilitó: siempre lleva a Nate al Centro Pokémon (pantalla
## negra y pierde dinero), esté o no desmayado.
func _on_companion_stunned(_actor: PokemonActor) -> void:
	if companion_state == CompanionState.FAINTED:
		return
	# En combate sale el siguiente Pokémon sano (si queda alguno).
	var battle := get_node_or_null("Battle") as BattleManager
	if battle != null and battle.active and battle.on_companion_fainted():
		return
	companion_state = CompanionState.FAINTED
	companion.set_controlled(false)
	($CameraRig as CameraRig).set_target(_player)
	($Hud as Hud).show_toast("¡%s se debilitó!" % companion.species.display_name)
	await get_tree().create_timer(1.6).timeout
	_player.black_out()


func _return_companion(ratio: float) -> void:
	if companion == null:
		return
	companion.process_mode = Node.PROCESS_MODE_INHERIT
	companion.visible = true
	companion.global_position = _player.global_position + _side_offset()
	companion.recover(ratio)
	companion_state = CompanionState.OUT


## Desmayo definitivo: pantalla negra, pierde dinero y reaparece en el Centro
## Pokémon con todo curado.
func _on_blacked_out() -> void:
	var battle := get_node_or_null("Battle") as BattleManager
	if battle != null:
		battle.finish("lose")
	BattleManager.reset_streak()
	var lost := GameState.apply_blackout_penalty()
	# En el Centro Pokémon se cura todo el equipo.
	for member: Dictionary in GameState.party:
		member["hp_ratio"] = 1.0
	var name := companion.species.display_name if companion != null else "Tu equipo"
	var player_name := GameState.player_name
	var message := ("¡%s se desmayó!" % player_name) if companion_state != CompanionState.FAINTED else "¡%s no puede continuar!" % name
	($Hud as Hud).show_blackout("%s\nCorriste al Centro Pokémon...\nPerdiste $%d en el camino.\n\n%s y %s están curados." % [message, lost, name, player_name], 2.6)
	await get_tree().create_timer(0.7).timeout
	if companion != null:
		companion.set_controlled(false)
	($CameraRig as CameraRig).set_target(_player)
	_player.respawn_at(GameState.respawn_point)
	_return_companion(1.0)


## Dibuja una vez, frente a la cámara, cada efecto que aparece durante el juego
## (nubes de escondite, destello shiny, anillo de persecución, "?" de legendario)
## para que Godot compile sus shaders al cargar y no a mitad del juego.
func _warm_up_shaders() -> void:
	await get_tree().process_frame
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var spot := camera.global_position - camera.global_basis.z * 4.0
	var temporary: Array[Node] = []
	for kind in PixelBurst.Kind.values():
		temporary.append(PixelBurst.spawn(self, spot, kind))
	var probe := ACTOR_SCENE.instantiate() as PokemonActor
	probe.species = STARTER_POOL.species[0]
	probe.role = PokemonActor.Role.WILD
	probe.shiny = true
	probe.legendary = true
	probe.world = $World
	probe.position = spot
	add_child(probe)
	(probe.get_node("ChaseRing") as Decal).visible = true
	(probe.get_node("QuestionMark") as Sprite3D).visible = true
	probe.set_physics_process(false)
	temporary.append(probe)
	for i in 3:
		await get_tree().process_frame
	for node in temporary:
		if is_instance_valid(node):
			node.queue_free()


## Un salvaje te alcanzó: empieza el combate en arena (si se puede).
func _on_wild_contact(actor: PokemonActor) -> void:
	var battle := get_node_or_null("Battle") as BattleManager
	if battle != null and BattleManager.enabled:
		battle.start(actor)


func _on_battle_ended(result: String) -> void:
	match result:
		"win":
			AudioBus.play_jingle("bw1_victory_wild")
		"trainer_win":
			AudioBus.play_jingle("bw1_victory_trainer")
		"capture":
			AudioBus.play_jingle("bw1_item")
