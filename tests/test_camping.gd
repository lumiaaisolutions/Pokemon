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

	# 9. Para llevar: queda en la Mochila y caduca; echada a perder se tira y quita vínculo.
	GameState.money = 5000
	GameState.bag.erase("stall-fruit")
	GameState.bag.erase("spoiled-food")
	stall._buy(FoodStallUI.MENU[0], false)
	_check(GameState.item_count("stall-fruit") == 1, "el puesto vende para llevar")
	GameState.play_time += GameState.DAY_SECONDS * 1.1
	GameState.check_spoiled()
	_check(GameState.item_count("stall-fruit") == 0 and GameState.item_count("spoiled-food") == 1, "la comida para llevar se echa a perder al día")
	if not GameState.party.is_empty():
		var member: Dictionary = GameState.party[GameState.companion_index]
		member["bond_xp"] = 20.0
		ItemEffects.use("spoiled-food", _main)
		_check(GameState.item_count("spoiled-food") == 0 and float(member["bond_xp"]) < 20.0, "tirar comida echada a perder quita vínculo")
	# Cocinar y guardar: el platillo queda en la Mochila.
	var keep_recipe: Dictionary = Items.cook_recipes()[0]
	for id: String in keep_recipe["needs"]:
		GameState.add_item(id, int(keep_recipe["needs"][id]))
	var dish := String(keep_recipe["result"])
	var before := GameState.item_count(dish)
	ItemEffects.cook(keep_recipe, _main, false)
	_check(GameState.item_count(dish) == before + int(keep_recipe.get("amount", 1)), "cocinar y guardar deja el platillo en la Mochila")

	# 10. Pantano tóxico.
	_test_poison()

	# 11. Campamento animado (dormir, cocinar, recoger, armar), Convivir y mejora
	# (acordado con Fernando el 2026-10-10, ronda 3).
	await _test_camp_cutscenes()


## Pantano tóxico: veneno que baja la vida (hasta 1), inmunes, Antídoto y dormir lo curan.
func _test_poison() -> void:
	var toxic := _main.get_node("ToxicSwamp") as ToxicSwamp
	_player.health = _player.config.health_max
	GameState.poison_until = GameState.play_time + 5.0
	_check(GameState.is_poisoned(), "el jugador queda envenenado")
	toxic._update_player()
	_check(_player.health < _player.config.health_max, "el veneno baja la vida del jugador")
	_player.health = 1.2
	for i in 5:
		toxic._update_player()
	_check(_player.health >= 1.0, "el veneno no deja al jugador sin vida (%.2f)" % _player.health)
	_check(ToxicSwamp.immune(MenuStyle.species("grimer")) and ToxicSwamp.immune(MenuStyle.species("magnemite")), "los tipo Veneno y Acero no se envenenan")
	_check(not ToxicSwamp.immune(MenuStyle.species("bidoof")), "un Bidoof sí se envenena")
	GameState.add_item("antidote", 1)
	var message := ItemEffects.use("antidote", _main)
	_check(not GameState.is_poisoned() and message.contains("curó"), "el Antídoto cura el veneno (%s)" % message)
	GameState.poison_until = GameState.play_time + 5.0
	if not GameState.party.is_empty():
		GameState.party[0]["poison_until"] = GameState.play_time + 5.0
	GameState.sleep_until_morning()
	_check(not GameState.is_poisoned() and (GameState.party.is_empty() or not GameState.party[0].has("poison_until")), "dormir cura el veneno del jugador y del equipo")


## Campamento animado (ronda 3, 2026-10-10): dormir, cocinar, recoger y armar siguen
## funcionando igual que antes (el resultado se aplica de inmediato) aunque ahora tengan
## una escena; dormir se puede saltar con E; Convivir sube el vínculo una vez al día;
## mejorar el campamento sube de nivel y cobra.
func _test_camp_cutscenes() -> void:
	if _camp.tents().is_empty():
		_failures.append("no hay una tienda armada para probar las animaciones del campamento")
		return
	var entry: Dictionary = _camp.tents()[0]

	# Dormir con la escena: igual que sin ella, avanza hasta las 7:00; se puede saltar.
	GameState.play_time = (21.0 - GameState.START_HOUR) * 60.0
	GameState.party = [{"species": "eevee", "shiny": false, "hp_ratio": 0.3}]
	GameState.companion_index = 0
	_camp.sleep(entry)
	_check(GameState.clock_hour() >= 6.9 and GameState.clock_hour() <= 7.1, "dormir con la escena animada también avanza hasta las 7:00")
	_check(_camp._cutscene_skip.is_valid(), "dormir deja una escena que se puede saltar")
	Input.action_press("interact")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("interact")
	_check(not _camp._cutscene_skip.is_valid(), "E salta la escena de dormir")
	_check(not DialogBox.blocking, "al saltar la escena de dormir el jugador se puede mover de nuevo")
	await _frames(3)

	# Cocinar: vapor, burbujas y el platillo sobre el tronco no fallan.
	var camp: Camp = entry["camp"]
	var recipe: Dictionary = Items.cook_recipes()[0]
	var before_cook_fx := PixelBurst.spawned_total
	camp.cook_flourish(_main.get("companion") as PokemonActor, Items.icon(String(recipe["result"])))
	await _frames(3)
	_check(PixelBurst.spawned_total > before_cook_fx, "cocinar anima vapor y burbujas sobre la olla")

	# Convivir: sube el vínculo de todo el equipo, pero solo una vez al día.
	GameState.world_flags.erase("camp_commune_day")
	var bond_before := float(GameState.party[0].get("bond_xp", 0.0))
	_camp.commune(entry)
	var bond_after := float(GameState.party[0].get("bond_xp", 0.0))
	_check(bond_after > bond_before, "convivir junto a la fogata sube el vínculo del equipo")
	_camp.commune(entry)
	_check(float(GameState.party[0].get("bond_xp", 0.0)) == bond_after, "convivir solo sube el vínculo una vez al día")

	# Mejorar el campamento: con materiales recolectados, no dinero (decisión de Fernando,
	# completando la simplificación anotada en docs/decisiones_sin_preguntar.md).
	var level_before := int(entry.get("level", 0))
	var money_before := GameState.money
	var recipe_needed := _camp.upgrade_recipe(entry)
	_camp.upgrade_camp(entry)
	_check(int(entry.get("level", 0)) == level_before, "sin materiales, mejorar el campamento no debe subir de nivel")
	for id: String in recipe_needed:
		GameState.add_item(id, int(recipe_needed[id]))
	_check(_camp.has_materials(recipe_needed), "con los materiales de la receta, debe alcanzar para mejorar")
	_camp.upgrade_camp(entry)
	_check(int(entry.get("level", 0)) == level_before + 1, "con materiales, mejorar el campamento sube de nivel (%d)" % int(entry.get("level", 0)))
	for id: String in recipe_needed:
		_check(GameState.item_count(id) == 0, "mejorar el campamento debe gastar los materiales de la receta (%s)" % id)
	_check(GameState.money == money_before, "mejorar el campamento no debe cobrar dinero")
	# Al nivel 2 además hay un baúl funcional de verdad.
	if _camp.can_upgrade(entry):
		var recipe2 := _camp.upgrade_recipe(entry)
		for id: String in recipe2:
			GameState.add_item(id, int(recipe2[id]))
		_camp.upgrade_camp(entry)
		_check(int(entry.get("level", 0)) == 2, "con más materiales, el campamento llega al nivel máximo (%d)" % int(entry.get("level", 0)))

	# Baúl del campamento (nivel 2, funcional de verdad): guardar y sacar objetos.
	_check(_camp.has_chest(entry), "al nivel 2 el campamento debe tener baúl")
	if _camp.has_chest(entry):
		GameState.add_item("oran-berry", 3)
		var bag_before := GameState.item_count("oran-berry")
		_check(_camp.chest_store(entry, "oran-berry", 2), "debe poder guardarse un objeto en el baúl")
		_check(GameState.item_count("oran-berry") == bag_before - 2, "guardar en el baúl debe sacarlo de la Mochila")
		_check(int(_camp.chest_contents(entry).get("oran-berry", 0)) == 2, "el baúl debe quedarse con lo guardado")
		_check(_camp.chest_take(entry, "oran-berry", 1), "debe poder sacarse un objeto del baúl")
		_check(GameState.item_count("oran-berry") == bag_before - 1, "sacar del baúl debe devolverlo a la Mochila")
		_check(not _camp.chest_take(entry, "oran-berry", 50), "no debe poder sacarse más de lo que hay guardado")

	# Cocción real (tiempo real, con animación, más corta con la fogata mejorada).
	_check(CampManager.cook_seconds(2) < CampManager.cook_seconds(0), "la fogata mejorada debe cocinar más rápido que la básica")
	_check_real_cooking(entry)

	# Visitante nocturno real: un PokemonActor camina de verdad hasta la fogata.
	await _check_night_visitor(entry)

	# Recoger (fogata apagándose con humo) y volver a armar (chispas al encenderla). La
	# animación corre en cuadros reales (Tween), no de física: se espera con create_timer
	# (ver docs/reglas_calidad.md).
	var before_pack_fx := PixelBurst.spawned_total
	_camp.pack_tent(entry)
	await get_tree().create_timer(0.5).timeout
	_check(PixelBurst.spawned_total > before_pack_fx, "recoger la tienda anima humo al apagar la fogata")
	_check(_camp.tents().is_empty(), "recoger la tienda la quita del campamento")
	var spot := _find_open_spot()
	if spot != Vector3.INF:
		var before_pitch_fx := PixelBurst.spawned_total
		var pitch_result: Dictionary = _camp.pitch_tent(spot)
		_check(bool(pitch_result.get("ok", false)), "se puede volver a armar la tienda tras recogerla")
		await get_tree().create_timer(1.6).timeout
		_check(PixelBurst.spawned_total > before_pitch_fx, "armar la tienda anima chispas al encender la fogata")


## Cocción real (tiempo real, con animación, acortada por la fogata mejorada): mientras
## cocina no se aplica el efecto todavía; al terminar, sí (completando la simplificación
## anotada en docs/decisiones_sin_preguntar.md: antes era instantáneo).
func _check_real_cooking(entry: Dictionary) -> void:
	var camp: Camp = entry["camp"]
	var ui := CookingUI.new()
	ui.main = _main
	ui.camp = camp
	add_child(ui)
	ui.open()
	var recipe: Dictionary = Items.cook_recipes()[0]
	for id: String in recipe["needs"]:
		GameState.add_item(id, int(recipe["needs"][id]) + 2)
	GameState.hunger = 0.0
	ui._start_cooking(recipe, true)
	_check(ui._cooking, "cocinar debe empezar una cocción real, no aplicar el efecto al instante")
	_check(GameState.hunger < 0.5, "mientras cocina, todavía no debe llenarse el hambre")
	var waited := 0.0
	while ui._cooking and waited < 12.0:
		ui._process(0.2)
		waited += 0.2
	_check(not ui._cooking, "la cocción debe terminar en un tiempo razonable (%.1fs)" % waited)
	_check(GameState.hunger > 0.5, "al terminar de cocinar, el hambre debe llenarse de verdad")
	ui._close()


## Visitante nocturno real (completando la simplificación anotada en
## docs/decisiones_sin_preguntar.md: antes solo una burbuja "¿?" sin nadie caminando): un
## PokemonActor real camina hasta la fogata, se queda un rato, deja un objeto y se va.
func _check_night_visitor(entry: Dictionary) -> void:
	var camp: Camp = entry["camp"]
	_camp._visitor = {}
	var attempts := 0
	while _camp._visitor.is_empty() and attempts < 60:
		_camp._maybe_visit(camp)
		attempts += 1
	_check(not _camp._visitor.is_empty(), "el visitante nocturno debe aparecer tras suficientes intentos")
	if _camp._visitor.is_empty():
		return
	var actor: PokemonActor = _camp._visitor["actor"]
	_check(actor != null and is_instance_valid(actor), "el visitante debe ser un PokemonActor real, no solo una burbuja")
	var fire: Vector3 = _camp._visitor["target"]
	var gift_before := GameState.item_count("oran-berry") + GameState.item_count("pecha-berry") + GameState.item_count("nugget")
	var waited := 0.0
	while _camp._visitor.get("state", "") == "arrive" and waited < 20.0:
		_camp._update_visitor(0.2)
		waited += 0.2
	_check(_camp._visitor.get("state", "") == "linger", "el visitante debe caminar de verdad hasta la fogata")
	_check(is_instance_valid(actor) and actor.global_position.distance_to(fire) < 0.5, "el visitante debe llegar junto a la fogata de verdad")
	var gift_after := GameState.item_count("oran-berry") + GameState.item_count("pecha-berry") + GameState.item_count("nugget")
	_check(gift_after > gift_before, "el visitante debe dejar un objeto de verdad al llegar")
	waited = 0.0
	while _camp._visitor.get("state", "") == "linger" and waited < 10.0:
		_camp._update_visitor(0.2)
		waited += 0.2
	_check(_camp._visitor.get("state", "") == "leave", "tras un rato junto a la fogata, el visitante debe irse caminando")
	waited = 0.0
	while not _camp._visitor.is_empty() and waited < 20.0:
		_camp._update_visitor(0.2)
		waited += 0.2
	_check(_camp._visitor.is_empty(), "el visitante debe irse caminando por donde llegó")
	await get_tree().process_frame
	_check(not is_instance_valid(actor), "el visitante debe quedar liberado al irse")


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
