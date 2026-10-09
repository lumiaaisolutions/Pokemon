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
	GameState.respawn_point = _player.global_position
	_warm_up_shaders()


## Segundos que tarda el compañero en volver de su Pokéball tras debilitarse.
const COMPANION_RECALL_TIME := 30.0


## El compañero cayó: si protegía a Nate desmayado, es desmayo definitivo; si no,
## vuelve a su Pokéball y regresa en COMPANION_RECALL_TIME con la mitad de la vida.
func _on_companion_stunned(_actor: PokemonActor) -> void:
	if _player.mode == Player.Mode.DOWNED:
		_player.black_out()
		return
	PixelBurst.spawn(self, companion.global_position + Vector3.UP * 0.5, PixelBurst.Kind.SMOKE, 0.8)
	companion.visible = false
	companion.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(COMPANION_RECALL_TIME).timeout
	_return_companion(0.5)


func _return_companion(ratio: float) -> void:
	companion.process_mode = Node.PROCESS_MODE_INHERIT
	companion.visible = true
	companion.global_position = _player.global_position + Vector3(1.5, 0.3, 1.5)
	companion.recover(ratio)


## Desmayo definitivo: pantalla negra, pierde dinero y reaparece con todo lleno.
func _on_blacked_out() -> void:
	var lost := GameState.apply_blackout_penalty()
	($Hud as Hud).show_blackout("¡Nate se desmayó!\nPerdió $%d en el camino..." % lost, 1.5)
	await get_tree().create_timer(0.7).timeout
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
