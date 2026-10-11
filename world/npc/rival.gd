class_name Rival
extends Node3D
## El rival (acordado con Fernando el 2026-10-10): Hugh, con su sprite de B2W2. Te busca
## tras cada medalla (aparece frente a ti al salir del gimnasio) y, además, de vez en
## cuando en el mundo (cada 2 o 3 días). Su equipo es el de B2W2 con el inicial que le gana
## al tuyo, crece con tus medallas (como los héroes) y pelea con la IA lista.

const TEAM := ["unfezant", "bouffalant", "simipour", "flareon", "eelektross"]
## Inicial que le gana al del jugador (por el primer tipo del inicial del jugador).
const COUNTER := {PokemonTypes.Type.GRASS: "emboar", PokemonTypes.Type.FIRE: "samurott", PokemonTypes.Type.WATER: "serperior"}

@export var player_path: NodePath = NodePath("../Player")

var _player: Player
var _main: Node
var _node: Node3D
var _state := ""
var _check := 2.0


func _ready() -> void:
	_main = get_parent()
	_player = get_node(player_path) as Player
	if not GameState.world_flags.has("rival_badges"):
		GameState.world_flags["rival_badges"] = _badges()
	if not GameState.world_flags.has("rival_next_day"):
		GameState.world_flags["rival_next_day"] = GameState.game_day() + 2


func _badges() -> int:
	return Regions.total_badges()


## Equipo de hoy: su inicial al frente y el resto de B2W2, creciendo con tus medallas.
static func team_ids() -> Array:
	var starter := "samurott"
	if not GameState.party.is_empty():
		var first := MenuStyle.species(GameState.party[0]["species"])
		if first != null and not first.types.is_empty():
			starter = COUNTER.get(first.types[0], ["emboar", "samurott", "serperior"][absi(hash(GameState.world_seed)) % 3])
	return [starter] + TEAM


func _process(delta: float) -> void:
	if _player == null or _state != "":
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 1.0
	if _player.global_position.x > WorldBuilder.INTERIOR_X or _player.mode != Player.Mode.WALK:
		return
	var battle := _main.get_node_or_null("Battle") as BattleManager
	if battle == null or battle.active or not battle.ready_to_fight():
		return
	# Tras una medalla nueva, o cada 2 o 3 días en el mundo.
	var badges := _badges()
	var reason := ""
	if badges > int(GameState.world_flags.get("rival_badges", 0)):
		reason = "medalla"
	elif GameState.game_day() >= int(GameState.world_flags.get("rival_next_day", 2)) and GameState.clock_hour() >= 9.0 and GameState.clock_hour() < 19.0:
		reason = "camino"
	if reason != "":
		_appear(reason)


func _appear(reason: String) -> void:
	_state = "approach"
	GameState.world_flags["rival_badges"] = _badges()
	GameState.world_flags["rival_next_day"] = GameState.game_day() + 2 + randi() % 2
	var camera := get_viewport().get_camera_3d()
	var forward := -camera.global_basis.z if camera != null else Vector3.FORWARD
	forward.y = 0.0
	forward = forward.normalized()
	_node = Node3D.new()
	_node.name = "RivalHugh"
	add_child(_node)
	var world := _main.get_node("World") as WorldBuilder
	var at := _player.global_position + forward * 12.0
	_node.global_position = Vector3(at.x, world.surface_height_at(at.x, at.z), at.z)
	var sprite := DirectionalSprite.new()
	sprite.name = "Sprite"
	sprite.step_cycle = PackedInt32Array([0, 1, 0, 2])
	sprite.walk_fps = 8.0
	_node.add_child(sprite)
	sprite.setup(NpcLooks.sheet("hugh"), 3, 8, 0.057)
	_node.set_meta("reason", reason)
	# Combate obligatorio (decisión de Fernando): te detiene y saca a tu compañero.
	var battle := _main.get_node_or_null("Battle") as BattleManager
	if battle != null:
		battle.spotted(_node)
	AudioBus.play_sfx("spotted")
	AudioBus.play_jingle("bw1_spotted")


func _physics_process(delta: float) -> void:
	if _node == null or _state != "approach":
		return
	var sprite := _node.get_node("Sprite") as DirectionalSprite
	var to := _player.global_position - _node.global_position
	to.y = 0.0
	if to.length() > 2.6:
		var velocity := to.normalized() * 4.5
		_node.global_position += velocity * delta
		_node.global_position.y = TownNPCs.swim_height(_main.get_node("World") as WorldBuilder, _node)
		sprite.animate(velocity, delta)
		return
	sprite.look_at_point(_player.global_position)
	sprite.animate(Vector3.ZERO, delta)
	_state = "talk"
	var lines: Array = ["¡%s! ¡Te estaba buscando!" % GameState.player_name]
	lines.append("¿Conseguiste otra medalla? ¡Pues yo también me hice más fuerte!" if _node.get_meta("reason") == "medalla" else "Mi equipo y yo entrenamos sin parar. ¡Vamos a ver quién es mejor!")
	var dialog := get_tree().get_first_node_in_group(&"dialog_box") as DialogBox
	if dialog == null:
		_fight()
		return
	dialog.open(GameState.rival, lines, NpcLooks.portrait("hugh"))
	dialog.closed.connect(_fight, CONNECT_ONE_SHOT)


func _fight() -> void:
	var battle := _main.get_node_or_null("Battle") as BattleManager
	var badges := _badges()
	var team: Array[SpeciesData] = []
	var size := clampi(2 + int(ceil(badges / 2.0)), 2, 6)
	var stage := 1 if badges < 2 else (2 if badges < 5 else 3)
	for id: String in team_ids().slice(0, size):
		team.append(MenuStyle.species(Heroes._stage_form(id, stage)))
	var info := {"id": "rival", "name": "%s (rival)" % GameState.rival, "team": team, "money": 1200 + 500 * badges,
			"item": ["super-potion", "great-ball", "ultra-ball", "rare-candy"][badges % 4], "smart": true, "heals": 1,
			"at": _node.global_position + (_player.global_position - _node.global_position).normalized() * 2.5 if _node != null else _player.global_position + Vector3(0, 0, -5),
			"node": _node}
	info["on_end"] = func(result: String) -> void: _leave(result)
	# Espera un momento a que se pueda pelear (tu compañero saliendo de su Ball).
	for attempt in 12:
		if battle == null or battle.start_trainer(info):
			return
		if attempt == 0:
			battle.spotted(_node)
		await get_tree().create_timer(0.25).timeout
		if _node == null:
			return
	var dialog := get_tree().get_first_node_in_group(&"dialog_box") as DialogBox
	if dialog != null:
		dialog.say(GameState.rival, "¿No tienes Pokémon en condiciones? Cúralos y peleamos la próxima vez.")
	if battle != null:
		battle.release_spotted()
	_leave("")


func _leave(result: String) -> void:
	_state = "leave"
	var dialog := get_tree().get_first_node_in_group(&"dialog_box") as DialogBox
	if dialog != null and result != "":
		dialog.say(GameState.rival, "¡Me ganaste! La próxima vez no será tan fácil." if result == "trainer_win" else "¡Ja! Sigue entrenando, ¡nos vemos!")
	if _node != null:
		var node := _node
		_node = null
		PixelBurst.spawn(get_parent(), node.global_position + Vector3.UP * 0.5, PixelBurst.Kind.DUST, 0.6)
		node.queue_free()
	_state = ""


## Hay un encuentro con el rival en curso (pruebas).
func busy() -> bool:
	return _state != ""
