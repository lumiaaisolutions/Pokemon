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
	# Combate en arena apagado: esta prueba revisa las peleas en el mundo (ver test_battle).
	BattleManager.enabled = false
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
	# Una especie común de la Pokédex de esta región (cambia por región, ver Regions).
	var common := ""
	for id: String in ["pidgey", "rattata", "sentret", "zigzagoon", "bidoof", "starly", "patrat", "lillipup", "fletchling", "bunnelby", "caterpie", "weedle"]:
		if not spawner.home_areas(id).is_empty() and not spawner.is_nomad(id):
			common = id
			break
	var areas := spawner.home_areas(common)
	_check(not areas.is_empty(), "una especie común de la región debe tener áreas propias (%s)" % common)
	if not areas.is_empty():
		var inside := Vector3(areas[0].x, 0.0, areas[0].y)
		_check(spawner.home_factor(common, inside) > spawner.home_factor(common, inside + Vector3(500, 0, 500)), "en su área es más común que fuera")

	# Guardar y cargar.
	GameState.money = 4321
	_check(SaveSystem.save_slot(3, _main), "guardar en la ranura 3")
	GameState.money = 1
	_check(SaveSystem.load_slot(3) and GameState.money == 4321 and GameState.is_caught("eevee"), "cargar la ranura 3 recupera dinero y Pokédex")
	SaveSystem.pending_position = Vector3.INF
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.slot_path(3)))

	# Menú: abre, pausa y construye todas las pestañas sin errores, en 2 tamaños de
	# ventana (responsivo: 1280×720 y 1920×1080).
	var menu := _main.get_node("MenuLayer/GameMenu") as GameMenu
	menu.open()
	_check(menu.visible and get_tree().paused, "el menú se abre y pausa el juego")
	var original_size := get_window().size
	for test_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = test_size
		for i in GameMenu.TABS.size():
			menu.show_tab(i)
			await get_tree().process_frame
	get_window().size = original_size

	# Rotom Móvil: las apps abren con tarjetas y "Volver" regresa a la cuadrícula.
	menu.show_tab(GameMenu.TABS.find("Rotom"))
	await get_tree().process_frame
	var tiles := get_tree().get_nodes_in_group(&"rotom_app_tile")
	_check(tiles.size() == RotomTab.APPS.size(), "el Rotom Móvil debe tener %d apps (hay %d)" % [RotomTab.APPS.size(), tiles.size()])
	for tile in tiles:
		(tile as BaseButton).pressed.emit()
		await get_tree().process_frame
		var back_buttons := get_tree().get_nodes_in_group(&"rotom_back_button")
		var app_screen := (back_buttons[0] as Control).get_parent().get_parent() as Control if not back_buttons.is_empty() else null
		_check(app_screen != null and app_screen.visible, "una app del Rotom abre su pantalla completa")
		(back_buttons[0] as BaseButton).pressed.emit()
		await get_tree().process_frame

	# Brújula de objetivos: marcar un objetivo (Territorio Alfa, siempre hay alguno) fija
	# el waypoint que sigue la flecha del minimapa.
	var compass_tile := tiles.filter(func(t: Button) -> bool: return t.tooltip_text == "Marca un lugar en el mapa")
	if not compass_tile.is_empty():
		(compass_tile[0] as BaseButton).pressed.emit()
		await get_tree().process_frame
		var targets := get_tree().get_nodes_in_group(&"rotom_compass_target")
		_check(not targets.is_empty(), "la brújula ofrece al menos un objetivo para marcar (Territorio Alfa)")
		if not targets.is_empty():
			(targets[0] as BaseButton).pressed.emit()
			var map_ui := _main.get_node("MapUi") as MapUi
			_check(GameState.world_flags.has("waypoint_label") and map_ui.waypoint() != Vector3.INF, "marcar un objetivo en la brújula fija el waypoint del mapa")
	menu.show_tab(GameMenu.HUB)
	menu.close()
	_check(not get_tree().paused, "al cerrar el menú el juego sigue")

	# Rotom Móvil: hay actividades; cumplir una da premio y progreso; vencer otra baja
	# la reputación y deja noticia.
	await _frames(5)
	var active := GameState.activities.filter(func(a: Dictionary) -> bool: return not a.get("done", false) and not a.get("failed", false))
	_check(active.size() == ActivityManager.MAX_ACTIVE, "el Rotom Móvil debe tener %d actividades (hay %d)" % [ActivityManager.MAX_ACTIVE, active.size()])
	_check(GameState.professor != "" and GameState.rival != "" and GameState.villain_team != "", "el elenco de la partida sale al azar")
	var gather := {"id": 999, "path": "academia", "kind": "gather", "progress": 0, "target": 2, "deadline_day": GameState.game_day() + 2, "money": 100, "item": "potion", "item_amount": 1, "title": "Prueba"}
	GameState.activities.append(gather)
	var money_before := GameState.money
	GameState.gathered.emit("oran-berry", 2)
	_check(gather.get("done", false) and GameState.money == money_before + 100 and int(GameState.path_progress.get("academia", 0)) >= 1, "cumplir una actividad da su premio y avanza el camino")
	var late := {"id": 998, "path": "concursos", "kind": "see", "progress": 0, "target": 50, "deadline_day": GameState.game_day(), "money": 100, "item": "potion", "item_amount": 1, "title": "Vencida"}
	GameState.activities.append(late)
	var rep_before := int(GameState.reputation.get("Concursos", 50))
	GameState.play_time += GameState.DAY_SECONDS
	await _frames(3)
	_check(late.get("failed", false) and int(GameState.reputation.get("Concursos", 50)) < rep_before, "si vence el plazo falla y baja la reputación")
	_check(not GameState.news.is_empty(), "las consecuencias salen en las noticias")
	# La hora se guarda desde la revisión de Fernando (2026-10-11 mañana): "guardar la
	# hora al agregar cada noticia y mostrarla en la app de Noticias" (no se compara con
	# la hora actual: el reloj ya siguió avanzando en los cuadros de espera de arriba).
	var news_hour: float = float(GameState.news[0].get("hour", -1.0))
	_check(news_hour >= 0.0 and news_hour < 24.0, "cada noticia guarda la hora en que pasó (%.2f)" % news_hour)

	# Recolección: recoger un punto da objetos y lo oculta hasta el día siguiente.
	var gathering := _main.get_node("Gathering") as GatherManager
	_check(gathering.nodes().size() > 30, "debe haber puntos de recolección en el mundo (%d)" % gathering.nodes().size())
	var node := gathering.nodes()[0]
	var result := gathering.collect(node)
	_check(not result.is_empty() and not (node.get_node("Fruit") as Node3D).visible, "recoger da objetos y sus frutos desaparecen")

	# Día y noche: a las 22:00 es de noche y está oscuro.
	GameState.play_time = (22.0 - GameState.START_HOUR) * 60.0
	await _frames(3)
	_check(GameState.is_night() and GameState.dark, "a las 22:00 es de noche")
	GameState.play_time = 0.0
	await _frames(3)

	# Movimientos sin niveles.
	var greninja := {"species": "greninja"}
	Moves.ensure_entry(greninja)
	_check((greninja["moves"] as Array).size() == 4 and (greninja["moves"] as Array).any(func(id: String) -> bool: return Moves.is_damaging(id)), "empieza con 4 movimientos de su lista y al menos uno de daño")
	var first_move: String = greninja["moves"][0]
	for i in Moves.RANK_USES[1]:
		Moves.register_use(greninja, first_move)
	_check(Moves.rank(greninja, first_move) == 2, "con %d usos el movimiento sube a rango 2" % Moves.RANK_USES[1])
	_check((greninja["unlocked"] as Array).size() > 4, "usar movimientos desbloquea nuevos de su lista")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var strong := Moves.damage(_species("greninja"), _species("bulbasaur"), "water-gun", 1, Moves.Style.STRONG, rng)
	rng.seed = 1
	var agile := Moves.damage(_species("greninja"), _species("bulbasaur"), "water-gun", 1, Moves.Style.AGILE, rng)
	_check(strong > agile, "el estilo Fuerte pega más que el Ágil")
	_check(Moves.cooldown("water-gun", 1, Moves.Style.STRONG) > Moves.cooldown("water-gun", 1, Moves.Style.AGILE), "el estilo Fuerte espera más que el Ágil")
	_check(Moves.effect("wish") == "heal_trainer" and Moves.effect("recover") == "heal_self", "Deseo cura al entrenador; Recuperación al Pokémon")
	# Tu Pokémon te cura con un movimiento de curación.
	var healer := _main.get("companion") as PokemonActor
	_player.take_damage(6.0)
	var hurt := _player.health
	healer.use_move("wish", null)
	_check(_player.health > hurt, "con Deseo tu compañero te cura")

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
