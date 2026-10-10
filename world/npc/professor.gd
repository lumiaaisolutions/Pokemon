class_name Professor
extends Node3D
## El profesor y su asistente (acordado con Fernando el 2026-10-10).
## - Sprite según su nombre: si no hay sprite propio en BW2, un científico con bata
##   (científica para las profesoras).
## - Está en su laboratorio de 8:00 a 19:00; de noche, en su casa (no se ve).
## - 1 o 2 días por semana sale a investigar a un lugar del mapa (ruinas, cueva, gruta,
##   árbol milenario…). Si lo encuentras allá, te da un premio especial (una vez por viaje).
## - La asistente siempre está en el laboratorio: dice dónde está el profesor (y lo marca
##   en el mapa), recibe tus registros y te entrega los premios de investigación.

const RESEARCH_KINDS := ["ruins", "cave", "grotto", "giant_tree", "floating_ruins", "lab_ruins", "sanctuary", "shipwreck", "lighthouse"]
const FEMALE := ["Encina", "Magnolia", "Sada"]
const TRIP_PRIZES := [["ultra-ball", 5], ["rare-candy", 2], ["star-piece", 2], ["lucky-egg", 1], ["mystic-fragment", 3]]

@export var world_path: NodePath = NodePath("../World")
@export var player_path: NodePath = NodePath("../Player")

var _world: WorldBuilder
var _player: Player
var _node: Node3D
var _point: Dictionary = {}
var _check := 0.0


func _ready() -> void:
	add_to_group(&"professor")
	_world = get_node(world_path) as WorldBuilder
	_player = get_node(player_path) as Player


## Profesores con sprite original de su juego (pedido de Fernando, 2026-10-10): Oak y
## Rowan de Platino, Elm de HGSS. Los demás, el científico o la científica de BW2.
const OWN_SPRITES := {"Oak": "prof_oak", "Elm": "prof_elm", "Rowan": "prof_rowan"}
## Retrato oficial (diálogo) por nombre.
const PORTRAITS := {"Oak": "oak", "Elm": "elm", "Birch": "birch", "Rowan": "rowan", "Encina": "juniper", "Sycamore": "sycamore",
		"Kukui": "kukui", "Magnolia": "magnolia", "Sada": "sada", "Turo": "turo"}


static func look() -> String:
	if OWN_SPRITES.has(GameState.professor):
		return OWN_SPRITES[GameState.professor]
	return "cientifica" if GameState.professor in FEMALE else "cientifico"


static func portrait() -> Texture2D:
	var path := "res://art/portraits/%s.png" % PORTRAITS.get(GameState.professor, "")
	return load(path) as Texture2D if ResourceLoader.exists(path) else NpcLooks.portrait(look())


static func title() -> String:
	return "Prof. %s" % GameState.professor


## ¿Sale de viaje este día? (1 o 2 días de cada semana, fijos por semilla).
static func traveling(day: int = -1) -> bool:
	if day < 0:
		day = GameState.game_day()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("prof_week:%d:%d" % [day / 7, GameState.world_seed])
	var trips := 1 + rng.randi() % 2
	var days: Array[int] = []
	while days.size() < trips:
		var d := rng.randi() % 7
		if not days.has(d):
			days.append(d)
	return days.has(day % 7)


static func working(hour: float) -> bool:
	return hour >= 8.0 and hour < 19.0


## Lugar del viaje de hoy (o {} si no viaja).
func trip_place(day: int = -1) -> Dictionary:
	if day < 0:
		day = GameState.game_day()
	if not traveling(day):
		return {}
	var options: Array = _world.layout.places.filter(func(p: Dictionary) -> bool: return p["kind"] in RESEARCH_KINDS)
	if options.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("prof_trip:%d:%d" % [day, GameState.world_seed])
	return options[rng.randi() % options.size()]


## ¿Está en el laboratorio ahora?
func in_lab() -> bool:
	return working(GameState.clock_hour()) and trip_place().is_empty()


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	var place := trip_place()
	var show := not place.is_empty() and working(GameState.clock_hour()) and _player.global_position.x < WorldBuilder.INTERIOR_X
	var at := Vector2(float(place.get("x", 0.0)) + 6.0, float(place.get("z", 0.0)) + 6.0)
	if show and at.distance_to(Vector2(_player.global_position.x, _player.global_position.z)) > 150.0:
		show = false
	if show and _node == null:
		_spawn(at)
	elif not show and _node != null:
		_world.structures.remove_point(_point)
		_node.queue_free()
		_node = null


func _spawn(at: Vector2) -> void:
	_node = Node3D.new()
	_node.name = "ProfessorTrip"
	add_child(_node)
	_node.global_position = Vector3(at.x, _world.surface_height_at(at.x, at.y), at.y)
	var sprite := DirectionalSprite.new()
	sprite.name = "Sprite"
	_node.add_child(sprite)
	sprite.setup(NpcLooks.sheet(look()), 3, 8, 0.057)
	var label := Label3D.new()
	label.text = title()
	label.font_size = 34
	label.pixel_size = 0.01
	label.outline_size = 8
	label.modulate = Color(0.7, 0.95, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.2
	_node.add_child(label)
	_point = _world.structures.add_point(_node.global_position + Vector3.UP * 0.5, "Hablar con el " + title(), talk_on_trip, 2.4)


func _physics_process(delta: float) -> void:
	if _node == null:
		return
	var sprite := _node.get_node("Sprite") as DirectionalSprite
	if _player.global_position.distance_to(_node.global_position) < 6.0:
		sprite.look_at_point(_player.global_position)
	sprite.animate(Vector3.ZERO, delta)


func _dialog() -> DialogBox:
	return get_tree().get_first_node_in_group(&"dialog_box") as DialogBox


## En su viaje: cuenta qué investiga y da un premio especial (una vez por viaje).
func talk_on_trip() -> void:
	var place := trip_place()
	var lines: Array = ["¡Vaya, qué sorpresa encontrarte aquí!", "Estoy estudiando a los Pokémon de %s." % Structures.place_title(place)]
	var key := "prof_trip_prize:%d" % GameState.game_day()
	var prize: Array = []
	if not GameState.world_flags.has(key):
		GameState.world_flags[key] = true
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key + str(GameState.world_seed))
		prize = TRIP_PRIZES[rng.randi() % TRIP_PRIZES.size()]
		lines.append("Toma, por venir hasta acá: %s × %d." % [Items.display_name(prize[0]), int(prize[1])])
	else:
		lines.append("Sigue registrando especies. ¡Cada dato cuenta!")
	var dialog := _dialog()
	if dialog == null:
		return
	dialog.open(title(), lines, portrait())
	if not prize.is_empty():
		dialog.closed.connect(func() -> void:
			GameState.add_item(prize[0], int(prize[1]))
			AudioBus.play_jingle("me_item")
			GameState.notice.emit("Recibiste %s × %d." % [Items.display_name(prize[0]), int(prize[1])]), CONNECT_ONE_SHOT)


## La asistente del laboratorio: dónde está el profesor y los premios de investigación.
func talk_assistant(services: TownServices) -> void:
	var lines: Array = []
	var hour := GameState.clock_hour()
	var place := trip_place()
	if not place.is_empty():
		lines.append("El %s salió a investigar a %s." % [title(), Structures.place_title(place)])
		lines.append("Te lo marqué en el mapa. Si lo encuentras allá, ¡seguro te da algo especial!")
		var map_ui := get_parent().get_node_or_null("MapUi") as MapUi
		if map_ui != null:
			map_ui.set_waypoint(Vector3(float(place["x"]), 0, float(place["z"])))
	elif not working(hour):
		lines.append("El %s ya se fue a su casa. Vuelve de 8:00 a 19:00." % title())
	else:
		lines.append("El %s está aquí, en el fondo del laboratorio." % title())
	var rewards := Research.claim_rewards()
	if rewards.is_empty():
		lines.append("Yo recibo tus registros de la Pokédex. ¡Sigue investigando!")
	else:
		lines.append("¡Recibí tus registros! Tienes premios de investigación.")
	var dialog := _dialog()
	if dialog != null:
		dialog.open("Asistente", lines, NpcLooks.portrait("doctor"))
	for message in rewards:
		GameState.notice.emit(message)
