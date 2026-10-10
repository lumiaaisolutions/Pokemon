extends Node3D
## Escena principal: al iniciar, un Pokémon básico al azar acompaña al jugador
## (hasta que exista la selección de inicial de la Fase 5).

const ACTOR_SCENE := preload("res://world/actors/pokemon_actor.tscn")
const STARTER_POOL := preload("res://creatures/data/basic_pool.tres")

var companion: PokemonActor

@onready var _player: Player = $Player
@onready var _navigation: WorldNavigation = $Navigation


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	companion = ACTOR_SCENE.instantiate() as PokemonActor
	companion.species = STARTER_POOL.pick_distinct(rng, 1)[0]
	companion.role = PokemonActor.Role.COMPANION
	companion.player = _player
	companion.world = $World
	companion.position = _player.position + Vector3(1.5, 0.3, 1.5)
	add_child(companion)
	$Spawner.wild_contact.connect(_on_wild_contact)
	_player.blacked_out.connect(_on_blacked_out)
	companion.stunned.connect(_on_companion_stunned)
	_player.downed.connect(_on_player_downed)
	_player.revived.connect(_on_player_revived)
	($Hud as Hud).main = self
	GameState.respawn_point = _player.global_position
	_warm_up_shaders()


## Estado del compañero para el HUD.
enum CompanionState { OUT, IN_BALL, FAINTED }

var companion_state: CompanionState = CompanionState.OUT
var _busy := false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("companion") and not _busy and _player.mode != Player.Mode.DOWNED:
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
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(2.0, 0.4, 0.4), 0.12)
	tween.tween_property(sprite, "scale", Vector3.ONE * 0.05, 0.25)
	await tween.finished
	companion.visible = false
	companion.process_mode = Node.PROCESS_MODE_DISABLED
	sprite.scale = Vector3.ONE
	sprite.modulate = Color.WHITE
	companion.set_physics_process(true)
	companion_state = CompanionState.IN_BALL
	($Hud as Hud).show_toast("%s, ¡regresa!" % companion.species.display_name)
	_busy = false


## Lo saca de su Pokéball junto a Nate: destello blanco y crece.
func _send_out_companion() -> void:
	_busy = true
	companion.process_mode = Node.PROCESS_MODE_INHERIT
	companion.visible = true
	companion.global_position = _player.global_position + _side_offset()
	companion.velocity = Vector3.ZERO
	var sprite := companion.get_node("Sprite") as Node3D
	sprite.scale = Vector3.ONE * 0.05
	sprite.modulate = Color(2.0, 2.0, 2.0)
	PixelBurst.spawn(self, companion.global_position + Vector3.UP * 0.4, PixelBurst.Kind.SMOKE, 0.6)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	await tween.finished
	companion_state = CompanionState.OUT
	($Hud as Hud).show_toast("¡Adelante, %s!" % companion.species.display_name)
	_busy = false


func _side_offset() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_basis.x if camera != null else Vector3.RIGHT
	right.y = 0.0
	return right.normalized() * 1.6 + Vector3.UP * 0.3


## Nate cayó: su compañero sale (si estaba guardado) y el jugador lo controla
## para protegerlo mientras se recupera; la cámara lo sigue.
func _on_player_downed() -> void:
	if companion_state == CompanionState.IN_BALL:
		await _send_out_companion()
	if companion_state != CompanionState.OUT or _player.mode != Player.Mode.DOWNED:
		return
	companion.set_controlled(true)
	($CameraRig as CameraRig).set_target(companion)


## Nate se levantó: el compañero vuelve a seguirlo solo.
func _on_player_revived() -> void:
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
	companion.process_mode = Node.PROCESS_MODE_INHERIT
	companion.visible = true
	companion.global_position = _player.global_position + _side_offset()
	companion.recover(ratio)
	companion_state = CompanionState.OUT


## Desmayo definitivo: pantalla negra, pierde dinero y reaparece en el Centro
## Pokémon con todo curado.
func _on_blacked_out() -> void:
	var lost := GameState.apply_blackout_penalty()
	var name := companion.species.display_name
	var player_name := GameState.player_name
	var message := ("¡%s se desmayó!" % player_name) if companion_state != CompanionState.FAINTED else "¡%s no puede continuar!" % name
	($Hud as Hud).show_blackout("%s\nCorriste al Centro Pokémon...\nPerdiste $%d en el camino.\n\n%s y %s están curados." % [message, lost, name, player_name], 2.6)
	await get_tree().create_timer(0.7).timeout
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
