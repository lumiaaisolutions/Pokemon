extends Node
## Prueba del menú y sus sistemas: mochila y Pokéballs (cambio, multiplicadores, aviso
## sin balls), objetos (poción, baya, repelente, fabricación), Pokédex (visto,
## capturado, investigación y premios), áreas propias por especie, guardado y carga,
## pestañas del menú y cambio de acompañante.
## Uso: godot --headless --path . tests/test_menu.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")

var _failures: Array[String] = []
var _main: Node3D
var _player: Player


func _ready() -> void:
	GameState.party.clear()
	GameState.dex.clear()
	GameState.bag = Items.starting_bag()
	GameState.rewards_claimed.clear()
	_main = MAIN_SCENE.instantiate() as Node3D
	_main.set("starter_ceremony", false)
	add_child(_main)
	_player = _main.get_node("Player") as Player
	await _run()
	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_menu: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run() -> void:
	var navigation := _main.get_node("Navigation") as WorldNavigation
	while not navigation.is_baked:
		await get_tree().physics_frame
	(_main.get_node("Spawner") as Node).set_process(false)
	await _frames(10)

	# Mochila y balls.
	_check(GameState.item_count("poke-ball") == 20 and GameState.item_count("great-ball") == 5, "la mochila inicial trae Poké y Super Balls")
	GameState.selected_ball = "poke-ball"
	GameState.cycle_ball(1)
	_check(GameState.selected_ball == "great-ball", "R / cruceta ↑ cambia a la siguiente ball (%s)" % GameState.selected_ball)
	GameState.cycle_ball(-1)
	_check(GameState.selected_ball == "poke-ball", "F / cruceta ↓ regresa a la anterior")
	var actor := (_main.get_node("Spawner") as WildSpawner).spawn_species(_species("magikarp"), _ground(8.0), false, false)
	await _frames(3)
	_check(is_equal_approx(CaptureRules.ball_multiplier("great-ball", actor, _player), 1.5), "la Super Ball multiplica ×1.5")
	_check(CaptureRules.ball_multiplier("net-ball", actor, _player) >= 3.5, "la Malla Ball rinde ×3.5 con tipo Agua")
	_check(CaptureRules.ball_multiplier("nest-ball", actor, _player) >= 3.0, "la Nido Ball rinde con Pokémon poco desarrollados")
	actor.queue_free()
	# Sin balls: no lanza y avisa.
	var notices: Array[String] = []
	_player.notice.connect(func(text: String) -> void: notices.append(text))
	GameState.bag.erase("ultra-ball")
	GameState.selected_ball = "ultra-ball"
	var aim := _player.get_node("ThrowAim") as ThrowAim
	_check(aim.throw_ball() == null, "sin balls del tipo elegido no lanza")
	_check(not notices.is_empty() and notices[-1].contains("No te quedan"), "sin balls debe avisar")
	GameState.selected_ball = "poke-ball"

	# Objetos.
	var companion := _main.get("companion") as PokemonActor
	companion.hp = companion.hp_max * 0.3
	(_main as Node).call("sync_companion_to_party")
	_check(ItemEffects.use("potion", _main).contains("recuperó") and float(GameState.party[0]["hp_ratio"]) > 0.6, "la Poción cura al compañero")
	_player.take_damage(6.0)
	var before := _player.health
	ItemEffects.use("oran-berry", _main)
	_check(_player.health > before, "la Baya Aranja recupera corazones")
	ItemEffects.use("repel", _main)
	_check(GameState.boost_active("repel"), "el repelente queda activo")
	GameState.repel_until = 0.0
	GameState.add_item("red-apricorn", 1)
	GameState.add_item("hard-stone", 1)
	var balls := GameState.item_count("poke-ball")
	_check(ItemEffects.craft(Items.recipes()[0]).contains("Fabricaste") and GameState.item_count("poke-ball") == balls + 2, "fabricar Poké Balls con bonguri y piedra")

	# Pokédex e investigación.
	GameState.mark_seen("eevee")
	_check(GameState.is_seen("eevee") and not GameState.is_caught("eevee"), "Eevee queda visto")
	_check(Research.level("eevee") == 1, "verlo una vez da nivel 1 de investigación")
	var money_items := GameState.item_count("great-ball")
	GameState.add_caught(_species("eevee"), false, 1.0, 1, 1.1)
	_check(GameState.is_caught("eevee") and int(GameState.dex["eevee"]["female"]) == 1, "capturarla la registra como hembra")
	_check(GameState.item_count("great-ball") > money_items or GameState.rewards_claimed.has("dex_1"), "el profesor premia la primera especie capturada")
	_check(float(GameState.dex["eevee"]["biggest"]) > 0.0, "se registra el récord de tamaño")

	# Áreas propias: dentro de su área la especie pesa mucho más.
	var spawner := _main.get_node("Spawner") as WildSpawner
	var areas := spawner.home_areas("pidgey")
	_check(not areas.is_empty(), "Pidgey debe tener áreas propias")
	if not areas.is_empty():
		var inside := Vector3(areas[0].x, 0.0, areas[0].y)
		_check(spawner.home_factor("pidgey", inside) > spawner.home_factor("pidgey", inside + Vector3(500, 0, 500)), "en su área es más común que fuera")

	# Guardar y cargar.
	GameState.money = 4321
	_check(SaveSystem.save_slot(3, _main), "guardar en la ranura 3")
	GameState.money = 1
	_check(SaveSystem.load_slot(3) and GameState.money == 4321 and GameState.is_caught("eevee"), "cargar la ranura 3 recupera dinero y Pokédex")
	SaveSystem.pending_position = Vector3.INF
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.slot_path(3)))

	# Menú: abre, pausa y construye todas las pestañas sin errores.
	var menu := _main.get_node("MenuLayer/GameMenu") as GameMenu
	menu.open()
	_check(menu.visible and get_tree().paused, "el menú se abre y pausa el juego")
	for i in GameMenu.TABS.size():
		menu.show_tab(i)
		await get_tree().process_frame
	menu.close()
	_check(not get_tree().paused, "al cerrar el menú el juego sigue")

	# Cambiar de acompañante.
	var first := (_main.get("companion") as PokemonActor).species
	(_main as Node).call("swap_companion", GameState.party.size() - 1)
	await _frames(5)
	_check((_main.get("companion") as PokemonActor).species.identifier == "eevee" and first.identifier != "eevee", "Eevee pasa a ser la acompañante")


func _species(identifier: String) -> SpeciesData:
	return load("res://creatures/data/species/%s.tres" % identifier) as SpeciesData


func _ground(distance: float) -> Vector3:
	var world := _main.get_node("World") as WorldBuilder
	var x := _player.global_position.x
	var z := _player.global_position.z - distance
	return Vector3(x, world.surface_height_at(x, z), z)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
