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
	_player.blacked_out.connect(_on_blacked_out)
	_player.downed.connect(_on_player_downed)
	_player.revived.connect(_on_player_revived)
	($Hud as Hud).main = self
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
		GameState.respawn_point = _player.global_position
	_warm_up_shaders()
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


## Cambia de acompañante por otro del equipo (desde el menú).
func swap_companion(index: int) -> void:
	if index == GameState.companion_index or index < 0 or index >= GameState.party.size():
		return
	sync_companion_to_party()
	var at := _player.global_position + _side_offset()
	var was_out := companion_state == CompanionState.OUT
	if companion != null:
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("companion") and companion != null and not _busy and _player.mode == Player.Mode.WALK:
		if companion_state == CompanionState.OUT:
			_recall_companion()
		elif companion_state == CompanionState.IN_BALL:
			_send_out_companion()


## Lo regresa a su Pokéball: destello rojo, se encoge hacia Nate y desaparece.
func _recall_companion() -> void:
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
	fx.ball.global_position = from
	var flight := create_tween()
	flight.tween_method(func(t: float) -> void:
		fx.ball.global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 1.2, 0.0, 1.0, 0.4)
	await flight.finished
	PixelBurst.spawn(self, to + Vector3.UP * 0.2, PixelBurst.Kind.SMOKE, 0.5)
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
		fx.set_beam(to, to + Vector3.UP * height * t)
		sprite.scale = Vector3.ONE * lerpf(0.05, 1.0, t), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	await tween.finished
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


func _on_wild_contact(actor: PokemonActor) -> void:
	# El combate en tiempo real llega en la Fase 3.
	print("Encuentro con %s salvaje" % actor.species.display_name)
