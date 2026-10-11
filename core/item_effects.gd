class_name ItemEffects
extends RefCounted
## Qué hace cada objeto al usarlo desde la Mochila. use() devuelve el mensaje para el
## jugador y gasta el objeto solo si tuvo efecto.

## Texto del botón según el objeto ("" si no se puede usar desde la Mochila).
static func action_label(id: String) -> String:
	var item := Items.get_item(id)
	if item.has("spoiled"):
		return "Tirar"
	if item.has("ball"):
		return "Elegir para lanzar"
	if item.has("heal_companion") or item.has("cure_status"):
		return "Usar en tu compañero"
	if item.has("heal_hearts") or item.has("feed"):
		return "Comer"
	if item.has("repel") or item.has("smoke") or item.has("lure") or item.has("decoy") or item.has("escape") or item.has("boost"):
		return "Usar"
	if item.has("training"):
		return "Dar a tu compañero"
	if item.has("tm"):
		return "Enseñar a tu compañero"
	if item.get("pocket", "") == "evolucion":
		return "Usar en tu compañero"
	if id == "bicycle":
		return "Montar / bajar"
	if id == "town-map":
		return "Ver el mapa"
	if item.has("tent"):
		return "Armar aquí (fuera del pueblo)"
	if item.has("rod"):
		return "Pescar"
	return ""


static func use(id: String, main: Node) -> String:
	var item := Items.get_item(id)
	if GameState.item_count(id) <= 0:
		return "No te quedan."
	var player := main.get_node_or_null("Player") as Player if main != null else null
	var companion := main.get("companion") as PokemonActor if main != null else null
	# Comida echada a perder: se tira y a tu compañero no le gusta (pierde un poco de
	# vínculo: lo que gana en 2 victorias).
	if item.has("spoiled"):
		GameState.use_item(id, GameState.item_count(id))
		if not GameState.party.is_empty():
			var member: Dictionary = GameState.party[GameState.companion_index]
			member["bond_xp"] = maxf(float(member.get("bond_xp", 0.0)) - 6.0, 0.0)
		return "Tiraste la comida echada a perder. A tu compañero no le gustó que se desperdiciara."
	if item.get("pocket", "") == "evolucion" and not item.has("ball"):
		if GameState.party.is_empty():
			return "No tienes Pokémon."
		var member: Dictionary = GameState.party[GameState.companion_index]
		var option := Evolution.item_option(member, id)
		var name := MenuStyle.species(member["species"]).display_name
		if option.is_empty():
			return "%s no reacciona a %s." % [name, item["name"]]
		GameState.use_item(id)
		EvolutionScene.play(main if main != null else Engine.get_main_loop().root, GameState.companion_index, option["to"])
		return "¡%s reacciona a %s!" % [name, item["name"]]
	if item.has("ball"):
		GameState.selected_ball = id
		GameState.bag_changed.emit()
		return "Lanzarás %s." % item["name"]
	if item.has("heal_companion"):
		if GameState.party.is_empty():
			return "No tienes Pokémon."
		var entry: Dictionary = GameState.party[GameState.companion_index]
		if float(entry.get("hp_ratio", 1.0)) >= 0.999:
			return "Tu compañero ya tiene la vida completa."
		entry["hp_ratio"] = minf(float(entry.get("hp_ratio", 1.0)) + float(item["heal_companion"]), 1.0)
		if companion != null:
			companion.recover(entry["hp_ratio"])
		GameState.use_item(id)
		return "¡Tu compañero recuperó vida!"
	if item.has("cure_status"):
		return "Tu compañero no está aturdido."
	if item.has("heal_hearts") or item.has("feed"):
		var fed := false
		if item.has("feed") and GameState.hunger < GameState.HUNGER_MAX - 0.001:
			GameState.feed(float(item["feed"]))
			fed = true
		var healed := false
		if item.has("heal_hearts") and player != null and player.health < player.config.health_max:
			player.heal(float(item["heal_hearts"]))
			healed = true
		if not fed and not healed:
			return "No tienes hambre y ya tienes todos tus corazones."
		GameState.use_item(id)
		if item.has("boost"):
			var boost: Dictionary = item["boost"]
			GameState.boosts[boost["kind"]] = GameState.play_time + float(boost["seconds"])
		return "¡Ñam! " + ("Recuperaste corazones y llenaste algo de hambre." if fed and healed else ("Llenaste algo de hambre." if fed else "Recuperaste corazones."))
	if item.has("repel"):
		GameState.repel_until = GameState.play_time + float(item["repel"])
		GameState.use_item(id)
		return "Los Pokémon salvajes no se acercarán durante %d s." % int(item["repel"])
	if item.has("smoke") or item.has("decoy"):
		var seconds := float(item.get("smoke", item.get("decoy", 6)))
		var calmed := 0
		for node in main.get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
			var wild := node as PokemonActor
			if player != null and wild.global_position.distance_to(player.global_position) < 18.0:
				wild.lose_track(seconds)
				calmed += 1
		if player != null and item.has("smoke"):
			PixelBurst.spawn(main, player.global_position + Vector3.UP * 0.6, PixelBurst.Kind.SMOKE, 2.5)
		GameState.use_item(id)
		return "Los salvajes cercanos te perdieron de vista (%d)." % calmed
	if item.has("lure"):
		var spawner := main.get_node_or_null("Spawner") as WildSpawner
		var count := spawner.spawn_lure(player.global_position) if spawner != null and player != null else 0
		GameState.use_item(id)
		return "El aroma atrajo a %d Pokémon." % count if count > 0 else "Nada acudió esta vez..."
	if item.has("escape"):
		if player != null:
			player.respawn_at(GameState.respawn_point)
		GameState.use_item(id)
		return "Regresaste al punto seguro."
	if item.has("boost"):
		var boost: Dictionary = item["boost"]
		GameState.boosts[boost["kind"]] = GameState.play_time + float(boost["seconds"])
		GameState.use_item(id)
		return "%s activo durante %d s." % [item["name"], int(boost["seconds"])]
	if item.has("training"):
		if GameState.party.is_empty():
			return "No tienes Pokémon."
		var target: Dictionary = GameState.party[GameState.companion_index]
		target["training_free"] = int(target.get("training_free", 0)) + int(item["training"])
		GameState.use_item(id)
		return "+%d Puntos de Entrenamiento para repartir (pestaña Equipo)." % int(item["training"])
	if item.has("tm"):
		if GameState.party.is_empty():
			return "No tienes Pokémon."
		var learner: Dictionary = GameState.party[GameState.companion_index]
		var learned := Moves.teach_type(learner, int(item["tm"]))
		if learned == "":
			return "%s no puede aprender más movimientos de tipo %s." % [MenuStyle.species(learner["species"]).display_name, MenuStyle.TYPE_NAMES[int(item["tm"])]]
		GameState.use_item(id)
		return "¡%s aprendió %s! Equípalo en el menú (Equipo)." % [MenuStyle.species(learner["species"]).display_name, Moves.get_move(learned)["name"]]
	if id == "bicycle":
		if player == null:
			return ""
		return player.toggle_bicycle()
	if id == "town-map":
		return "map"
	if item.has("tent"):
		if player == null or main == null:
			return ""
		# Sin tipo estático a propósito: CampManager usa CookingUI, que a su vez llama a
		# ItemEffects (este archivo); tipar aquí crearía una dependencia circular entre
		# clases globales que Godot no puede resolver al compilar.
		var camp: Node = main.get_node_or_null("CampManager")
		if camp == null:
			return ""
		var result: Dictionary = camp.call("pitch_tent", _forward_spot(main, player, 3.0))
		if bool(result["ok"]):
			GameState.use_item(id)
		return String(result["message"])
	if item.has("rod"):
		if player == null or main == null:
			return ""
		if main.get_node_or_null("Fishing") != null:
			return "Ya tienes el anzuelo en el agua."
		if player != null and player.mode != Player.Mode.WALK:
			return "Sal del agua para pescar (desde la orilla)."
		if _nearby_water_depth(player) < 0.15:
			return "Necesitas estar junto al agua para pescar."
		var fishing := FishingMinigame.new()
		fishing.name = "Fishing"
		fishing.main = main
		fishing.player = player
		fishing.rod_tier = int((item["rod"] as Dictionary).get("tier", 1))
		main.add_child(fishing)
		return "¡Lanzas el anzuelo al agua!"
	return ""


## Punto frente al jugador (según la cámara) para armar la tienda de campaña.
static func _forward_spot(main: Node, player: Player, distance: float) -> Vector3:
	var camera := main.get_viewport().get_camera_3d() if main != null else null
	var forward := -camera.global_basis.z if camera != null else Vector3.FORWARD
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	return player.global_position + forward * distance


## Profundidad de agua más cercana frente al jugador (o en sus pies si ya está adentro).
static func _nearby_water_depth(player: Player) -> float:
	var world := player.get_tree().get_first_node_in_group(WorldBuilder.WORLD_GROUP) as WorldBuilder
	if world == null:
		return -1.0
	var best := world.water_depth_at(player.global_position.x, player.global_position.z)
	var camera := player.get_viewport().get_camera_3d()
	var forward := -camera.global_basis.z if camera != null else Vector3.FORWARD
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	for distance: float in [1.5, 3.0, 4.5]:
		var spot := player.global_position + forward * distance
		best = maxf(best, world.water_depth_at(spot.x, spot.z))
	return best


## ¿Hay materiales para la receta?
static func can_craft(recipe: Dictionary) -> bool:
	for id: String in recipe["needs"]:
		if GameState.item_count(id) < int(recipe["needs"][id]):
			return false
	return true


static func craft(recipe: Dictionary) -> String:
	if not can_craft(recipe):
		return "Te faltan materiales."
	for id: String in recipe["needs"]:
		GameState.use_item(id, int(recipe["needs"][id]))
	GameState.add_item(recipe["result"], int(recipe["amount"]))
	return "¡Fabricaste %d %s!" % [int(recipe["amount"]), Items.display_name(recipe["result"])]


## Cocina en la fogata de la tienda de campaña (acordado con Fernando el 2026-10-10):
## consume los ingredientes y se come al instante (llena mucho el hambre y da un efecto
## extra simple); tu equipo sale a comer contigo y sube su vínculo.
## Cocina la receta; eat_now: comerlo ahí (si no, se guarda en la Mochila y caduca).
## Tu equipo come contigo y sube su vínculo en los dos casos.
static func cook(recipe: Dictionary, main: Node, eat_now: bool = true) -> String:
	if not can_craft(recipe):
		return "Te faltan ingredientes."
	for id: String in recipe["needs"]:
		GameState.use_item(id, int(recipe["needs"][id]))
	var dish := Items.get_item(String(recipe["result"]))
	if not eat_now:
		GameState.add_item(String(recipe["result"]), int(recipe.get("amount", 1)))
		for member: Dictionary in GameState.party:
			member["bond_xp"] = float(member.get("bond_xp", 0.0)) + 2.0
		return "¡Cocinaste %s y lo guardaste en la Mochila! Tu equipo comió contigo. Caduca en %d día(s)." % [Items.display_name(String(recipe["result"])), int(dish.get("shelf_days", 1))]
	GameState.feed(float(dish.get("feed", 0.0)) * float(recipe.get("amount", 1)))
	var player := main.get_node_or_null("Player") as Player if main != null else null
	if dish.has("heal_hearts") and player != null:
		player.heal(float(dish["heal_hearts"]))
	if dish.has("boost"):
		var boost: Dictionary = dish["boost"]
		GameState.boosts[boost["kind"]] = GameState.play_time + float(boost["seconds"])
	for member: Dictionary in GameState.party:
		member["bond_xp"] = float(member.get("bond_xp", 0.0)) + 2.0
	if main != null:
		var companion := main.get("companion") as PokemonActor
		if companion != null:
			PixelBurst.spawn(main, companion.global_position + Vector3.UP, PixelBurst.Kind.HEAL, 1.0)
	return "¡Cocinaste %s! Tu equipo salió a comer contigo y subió su vínculo." % Items.display_name(String(recipe["result"]))
