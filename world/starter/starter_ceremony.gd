class_name StarterCeremony
extends Node3D
## Elección del inicial en la plaza del pueblo (acordado con Fernando el 2026-10-10,
## ronda de la noche): los 4 candidatos presentados en la cinemática (IntroCinematic)
## llegan con el profesor a la plaza. Mientras no eliges: pared invisible alrededor de la
## plaza (el profesor te detiene y te regresa) y los vecinos se apartan de la zona. El
## profesor comenta tipo y carácter de cada candidato al acercarte, indica paso a paso
## cómo apuntar y lanzar, y al elegir felicita, da Poké Balls y se va a su rutina (el
## nodo Professor normal de main.gd sigue solo desde ahí). El primero al que le lanzas
## una Pokéball queda capturado (sin fallar) y es tu compañero; los demás se van.

## Elegido: species y si es shiny, con la posición donde quedó la Pokéball.
signal chosen(species: SpeciesData, shiny: bool, at: Vector3)

const ACTOR_SCENE := preload("res://world/actors/pokemon_actor.tscn")
const ARC_RADIUS := 6.5
const ARC_DEGREES := 100.0
const SHINY_CHANCE := 0.01
## Radio de la pared invisible alrededor del centro de la plaza (donde empieza la
## ceremonia): deja moverse entre los 4 candidatos sin poder salir de la plaza.
const PLAZA_RADIUS := 16.0
## Cuántas Poké Balls regala el profesor al elegir compañero.
const GIFT_BALLS := 5
## Segundos entre avisos de la pared invisible (no repetir el diálogo a cada paso).
const WALL_COOLDOWN := 4.0
## Distancia para que el profesor comente un candidato al acercarte.
const COMMENT_RADIUS := 3.0

var player: Player
var world: WorldBuilder
var hud: Hud
var _candidates: Array[PokemonActor] = []
var _rng := RandomNumberGenerator.new()
var _done := false
var _center := Vector2.ZERO
var _wall_cooldown := 0.0
var _prof_node: Node3D


## candidates: los 4 básicos decididos por la cinemática (uno por lugar visitado).
func start(candidates: Array[SpeciesData]) -> void:
	_rng.randomize()
	_center = Vector2(player.global_position.x, player.global_position.z)
	var npcs := get_tree().get_first_node_in_group(&"town_npcs") as TownNPCs
	if npcs != null:
		npcs.set_exclusion_zone(player.global_position, PLAZA_RADIUS)
	_spawn_professor()
	_place_candidates(candidates)
	_react_nearby(player.global_position, ["¡Está eligiendo su inicial!", "¡Va a elegir compañero!"])
	var dialog := _dialog()
	if dialog != null:
		dialog.open(Professor.title(), [
			"¡Aquí los tienes! Conocí a estos cuatro en mi viaje por la región.",
			"Acércate a cada uno; te contaré de él. Cuando decidas, lánzale una Pokéball.",
		], Professor.portrait())
		await dialog.closed
	hud.show_tip("inicial", "Elige a tu compañero", [
		["aim", "Mantén para apuntar"],
		[null, "Acércate a cada candidato: el profesor te hablará de él. Lánzale una Pokéball al que quieras."]])


func _process(delta: float) -> void:
	if _done or player == null:
		return
	_wall_cooldown = maxf(_wall_cooldown - delta, 0.0)
	var offset := Vector2(player.global_position.x, player.global_position.z) - _center
	if offset.length() > PLAZA_RADIUS:
		var inside := offset.normalized() * PLAZA_RADIUS
		player.global_position.x = _center.x + inside.x
		player.global_position.z = _center.y + inside.y
		player.velocity = Vector3.ZERO
		if _wall_cooldown <= 0.0:
			_wall_cooldown = WALL_COOLDOWN
			var dialog := _dialog()
			if dialog != null:
				dialog.say(Professor.title(), "¡Espera, primero elige a tu compañero!")
	for actor in _candidates:
		if not is_instance_valid(actor) or actor.get_meta("commented", false):
			continue
		if player.global_position.distance_to(actor.global_position) < COMMENT_RADIUS:
			actor.set_meta("commented", true)
			_comment(actor)


## El profesor comenta tipo y carácter del candidato al que te acercaste.
func _comment(actor: PokemonActor) -> void:
	var dialog := _dialog()
	if dialog == null:
		return
	var species := actor.species
	var type_name: String = MenuStyle.TYPE_NAMES[species.types[0]]
	dialog.say(Professor.title(), "%s es de tipo %s: %s." % [species.display_name, type_name, PokemonActor.tactic_label(species)])


## Un candidato fue capturado: es el elegido. Felicita, da Poké Balls y se va.
## (actor se libera solo al capturarse, apenas este método cede el control en el primer
## await: se guardan species/shiny/posición antes, nunca se vuelve a tocar actor).
func _on_vanished(actor: PokemonActor) -> void:
	if _done or not GameState.party.any(func(p: Dictionary) -> bool: return p["species"] == actor.species.identifier):
		return
	_done = true
	var species := actor.species
	var shiny := actor.shiny
	var at := actor.global_position
	for other in _candidates:
		if other != actor and is_instance_valid(other):
			_flee(other)
	_react_nearby(at, ["¡Empieza su aventura!", "¡Ya tiene compañero!"])
	var npcs := get_tree().get_first_node_in_group(&"town_npcs") as TownNPCs
	if npcs != null:
		npcs.clear_exclusion_zone()
	GameState.add_item("poke-ball", GIFT_BALLS)
	var dialog := _dialog()
	if dialog != null:
		dialog.open(Professor.title(), [
			"¡Felicidades! %s será un gran compañero de viaje." % species.display_name,
			"Toma, %d Poké Balls para tu viaje. ¡Buena suerte!" % GIFT_BALLS,
		], Professor.portrait())
		await dialog.closed
	await _leave_professor()
	chosen.emit(species, shiny, at)


## El profesor se despide (y vuelve a su rutina normal: el Professor de main.gd sigue
## sin que haga falta nada más).
func _leave_professor() -> void:
	if _prof_node == null or not is_instance_valid(_prof_node):
		return
	var tween := create_tween()
	tween.tween_property(_prof_node, "scale", Vector3.ZERO, 0.6)
	await tween.finished
	if is_instance_valid(_prof_node):
		_prof_node.queue_free()
	_prof_node = null


## Si hay vecinos cerca, comentan la ceremonia (burbujas).
func _react_nearby(pos: Vector3, lines: Array) -> void:
	var npcs := get_tree().get_first_node_in_group(&"town_npcs") as TownNPCs
	if npcs != null:
		npcs.react(pos, lines)


## Los no elegidos se van al bosque con una nube de hojas.
func _flee(actor: PokemonActor) -> void:
	PixelBurst.spawn(get_parent(), actor.global_position + Vector3.UP * 0.4, PixelBurst.Kind.LEAVES, actor.species.size_scale)
	actor.ceremony = false
	actor.queue_free()


func _dialog() -> DialogBox:
	return get_tree().get_first_node_in_group(&"dialog_box") as DialogBox


## Arco frente a la cámara, igual para el profesor (en la plaza) y los candidatos.
func _place_candidates(candidates: Array[SpeciesData]) -> void:
	var forward := _camera_forward()
	for i in candidates.size():
		var angle := deg_to_rad(lerpf(-ARC_DEGREES * 0.5, ARC_DEGREES * 0.5, float(i) / maxf(1.0, float(candidates.size() - 1))))
		var dir := forward.rotated(Vector3.UP, angle)
		var p := player.global_position + dir * ARC_RADIUS
		p.y = world.surface_height_at(p.x, p.z)
		_spawn_candidate(candidates[i], p)


func _camera_forward() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.FORWARD
	var forward := -camera.global_basis.z
	forward.y = 0.0
	return forward.normalized()


## El profesor, ya en la plaza junto al jugador (llegó con los 4 en la cinemática): un
## poco al lado y adelante, no justo en medio de la fila de candidatos ni tapado por Nate.
func _spawn_professor() -> void:
	var node := Node3D.new()
	node.name = "Professor"
	add_child(node)
	var forward := _camera_forward()
	var side := forward.rotated(Vector3.UP, deg_to_rad(90.0))
	var pos := player.global_position + forward * 1.8 + side * 2.2
	pos.y = world.surface_height_at(pos.x, pos.z)
	node.global_position = pos
	var sprite := DirectionalSprite.new()
	sprite.name = "Sprite"
	node.add_child(sprite)
	sprite.setup(NpcLooks.sheet(Professor.look()), 3, 8, 0.057)
	sprite.look_at_point(player.global_position)
	_prof_node = node


## Aparece con un destello (llegó caminando con el profesor) y queda quieto mirando al
## jugador hasta que lo eligen (PokemonActor.ceremony).
func _spawn_candidate(species: SpeciesData, at: Vector3) -> void:
	var actor := ACTOR_SCENE.instantiate() as PokemonActor
	actor.species = species
	actor.shiny = _rng.randf() < SHINY_CHANCE
	actor.player = player
	actor.world = world
	actor.ceremony = true
	get_parent().add_child(actor)
	actor.global_position = at
	actor.vanished.connect(_on_vanished)
	var label := Label3D.new()
	label.text = species.display_name + (" ✦" if actor.shiny else "")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.outline_size = 12
	label.pixel_size = 0.006
	label.no_depth_test = true
	label.position.y = species.overworld_cell * actor.world_pixel_size() + 0.5
	actor.add_child(label)
	_candidates.append(actor)
	PixelBurst.spawn(get_parent(), at + Vector3.UP * 0.4, PixelBurst.Kind.HEAL, 0.8)
	actor.scale = Vector3.ZERO
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(actor, "scale", Vector3.ONE, 0.4)
