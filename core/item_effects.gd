class_name ItemEffects
extends RefCounted
## Qué hace cada objeto al usarlo desde la Mochila. use() devuelve el mensaje para el
## jugador y gasta el objeto solo si tuvo efecto.

## Texto del botón según el objeto ("" si no se puede usar desde la Mochila).
static func action_label(id: String) -> String:
	var item := Items.get_item(id)
	if item.has("ball"):
		return "Elegir para lanzar"
	if item.has("heal_companion") or item.has("cure_status"):
		return "Usar en tu compañero"
	if item.has("heal_hearts"):
		return "Comer"
	if item.has("repel") or item.has("smoke") or item.has("lure") or item.has("decoy") or item.has("escape") or item.has("boost"):
		return "Usar"
	if item.has("training"):
		return "Dar a tu compañero"
	if id == "town-map":
		return "Ver el mapa"
	return ""


static func use(id: String, main: Node) -> String:
	var item := Items.get_item(id)
	if GameState.item_count(id) <= 0:
		return "No te quedan."
	var player := main.get_node_or_null("Player") as Player if main != null else null
	var companion := main.get("companion") as PokemonActor if main != null else null
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
	if item.has("heal_hearts"):
		if player == null or player.health >= player.config.health_max:
			return "Tienes todos tus corazones."
		player.heal(float(item["heal_hearts"]))
		GameState.use_item(id)
		return "¡Ñam! Recuperaste corazones."
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
	if id == "town-map":
		return "map"
	return ""


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
