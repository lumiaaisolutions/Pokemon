extends Node
## Prueba del campamento, comida y hambre (acordado con Fernando el 2026-10-10): el
## hambre baja con el tiempo y quita vida al vaciarse; comer (crudo, de tienda o
## cocinado) la sube; la tienda de campaña se arma fuera de los pueblos (no dentro) y
## persiste al recargar la partida; dormir solo de noche hasta las 7:00 cura al equipo
## y NO el hambre; cocinar consume ingredientes y llena mucho; pescar da pescado crudo;
## el restaurante llena más hambre que el puesto de comida.
## Uso: godot --headless --path . tests/test_camping.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")

var _failures: Array[String] = []
var _main: Node3D
var _player: Player
var _world: WorldBuilder
var _camp: CampManager


func _ready() -> void:
	BattleManager.enabled = false
	GameState.party.clear()
	GameState.box.clear()
	GameState.bag = Items.starting_bag()
	GameState.world_flags = {}
	GameState.money = 50000
	GameState.hunger = GameState.HUNGER_MAX
	await _load_main()
	await _run()
	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_camping: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _load_main() -> void:
	if _main != null:
		_main.queue_free()
		await _frames(3)
	_main = MAIN_SCENE.instantiate() as Node3D
	_main.set("starter_ceremony", false)
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_world = _main.get_node("World") as WorldBuilder
	_camp = _main.get_node("CampManager") as CampManager
	var navigation := _main.get_node("Navigation") as WorldNavigation
	while not navigation.is_baked:
		await get_tree().physics_frame
	for node_name in ["Spawner", "Legendaries", "Ambushes", "Events"]:
		(_main.get_node(node_name) as Node).set_process(false)
	await _frames(10)


func _run() -> void:
	# 1. El hambre baja con el tiempo y, vacía, quita vida poco a poco.
	GameState.hunger = GameState.HUNGER_MAX
	GameState.drain_hunger(GameState.HUNGER_EMPTY_SECONDS * 0.5)
	_check(absf(GameState.hunger - GameState.HUNGER_MAX * 0.5) < 0.05, "la mitad del tiempo vacía la mitad de la barra de hambre (%.2f)" % GameState.hunger)
	GameState.hunger = 0.0
	_player.health = _player.config.health_max
	_player._starve_tick = 0.0
	for i in 60:
		_player._update_hunger(1.0 / 60.0, false)
	_check(_player.health < _player.config.health_max, "sin hambre, el jugador pierde vida con el tiempo")

	# 2. Comer sube el hambre (crudo muy poco, de tienda un poco más).
	GameState.hunger = 1.0
	var before_raw := GameState.hunger
	ItemEffects.use("oran-berry", _main)
	_check(GameState.hunger > before_raw, "comer una baya cruda sube un poco el hambre")
	var raw_gain := GameState.hunger - before_raw
	GameState.add_item("bread", 1)
	var before_shop := GameState.hunger
	ItemEffects.use("bread", _main)
	_check(GameState.hunger > before_shop, "comer pan de la Tienda Pokémon sube el hambre")
	_check(GameState.hunger - before_shop > raw_gain, "la comida de tienda llena más que la cruda")

	# 3. La tienda de campaña: fuera del pueblo sí, dentro de un pueblo no.
	var inside_result: Dictionary = _camp.pitch_tent(_world.start_position())
	_check(not bool(inside_result["ok"]), "no se puede armar la tienda dentro de un pueblo")
	var outside := _find_open_spot()
	_check(outside != Vector3.INF, "se encontró un lugar fuera de los pueblos para la prueba")
	var tent_result: Dictionary = {}
	var tent_pos := Vector3.INF
	if outside != Vector3.INF:
		tent_result = _camp.pitch_tent(outside)
		_check(bool(tent_result.get("ok", false)), "se puede armar la tienda fuera del pueblo (%s)" % String(tent_result.get("message", "")))
		_check(_camp.tents().size() == 1, "la tienda se registra en el manejador de campamento")
		if not _camp.tents().is_empty():
			tent_pos = _camp.tents()[0]["pos"]

	# 4. Dormir: solo de noche, hasta las 7:00; cura al jugador y al equipo, NO el hambre.
	GameState.play_time = 0.0
	_check(not GameState.is_night(), "a las 8:00 (inicio de la partida) es de día")
	_player.health = 2.0
	_camp.sleep()
	_check(_player.health == 2.0, "de día no se puede dormir en la tienda")
	GameState.play_time = (21.0 - GameState.START_HOUR) * 60.0
	_check(GameState.is_night(), "a las 21:00 es de noche")
	GameState.party = [{"species": "eevee", "shiny": false, "hp_ratio": 0.2}]
	GameState.companion_index = 0
	var hunger_before_sleep := GameState.hunger
	_camp.sleep()
	_check(GameState.clock_hour() >= 6.9 and GameState.clock_hour() <= 7.1, "dormir avanza hasta las 7:00 (%.2f)" % GameState.clock_hour())
	_check(_player.health == _player.config.health_max, "dormir cura al jugador")
	_check(float(GameState.party[0]["hp_ratio"]) >= 0.999, "dormir cura al equipo")
	_check(absf(GameState.hunger - hunger_before_sleep) < 0.01, "dormir NO cambia el hambre (%.2f vs %.2f)" % [GameState.hunger, hunger_before_sleep])

	# 5. La tienda persiste al recargar la partida (se reconstruye en el mismo lugar).
	if tent_pos != Vector3.INF:
		await _load_main()
		_check(_camp.tents().size() == 1, "la tienda persiste al recargar la partida")
		if not _camp.tents().is_empty():
			var reloaded: Vector3 = _camp.tents()[0]["pos"]
			_check(reloaded.distance_to(tent_pos) < 0.5, "la tienda se reconstruye en el mismo lugar (%.1f m)" % reloaded.distance_to(tent_pos))

	# 6. Cocinar consume los ingredientes y llena mucho el hambre.
	GameState.bag["cheri-berry"] = 1
	GameState.bag["pecha-berry"] = 1
	GameState.bag["oran-berry"] = 1
	GameState.hunger = 1.0
	var recipe: Dictionary = Items.cook_recipes()[0]
	var cook_message := ItemEffects.cook(recipe, _main)
	_check(cook_message.contains("Cocinaste"), "cocinar devuelve un mensaje de éxito (%s)" % cook_message)
	_check(GameState.item_count("cheri-berry") == 0 and GameState.item_count("pecha-berry") == 0 and GameState.item_count("oran-berry") == 0,
			"cocinar consume los ingredientes de la receta")
	_check(GameState.hunger > 3.0, "cocinar llena mucho más el hambre que la comida cruda (%.2f)" % GameState.hunger)

	# 7. Pescar (con la Caña) da Pescado Crudo.
	GameState.bag.erase("raw-fish")
	var fish_catches := 0
	for i in 25:
		var fisher := FishingMinigame.new()
		fisher.main = _main
		fisher.player = _player
		fisher.rod_tier = 1
		add_child(fisher)
		var before_fish := GameState.item_count("raw-fish")
		fisher._catch()
		if GameState.item_count("raw-fish") > before_fish:
			fish_catches += 1
		fisher.queue_free()
	_check(fish_catches > 0, "pescar da Pescado Crudo al menos algunas veces (%d de 25 intentos)" % fish_catches)

	# 8. Restaurante y puesto de comida llenan distinto hambre (el restaurante llena más).
	GameState.hunger = 0.0
	var stall := FoodStallUI.new()
	stall._buy(FoodStallUI.MENU[0])
	var stall_fill := GameState.hunger
	GameState.hunger = 0.0
	var restaurant := RestaurantUI.new()
	restaurant._buy(RestaurantUI.MENU[0])
	var restaurant_fill := GameState.hunger
	_check(stall_fill > 0.0, "el puesto de comida llena hambre")
	_check(restaurant_fill > stall_fill, "el restaurante llena más hambre que el puesto (%.2f vs %.2f)" % [restaurant_fill, stall_fill])


## Busca un lugar fuera de los asentamientos, en tierra firme, para armar la tienda.
func _find_open_spot() -> Vector3:
	for radius in [60.0, 90.0, 120.0, 160.0, 200.0]:
		for k in 12:
			var angle := TAU * k / 12.0
			var pos := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
			if _camp.can_place_at(pos):
				return Vector3(pos.x, _world.surface_height_at(pos.x, pos.z), pos.z)
	return Vector3.INF


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
