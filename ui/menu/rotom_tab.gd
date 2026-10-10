class_name RotomTab
extends RefCounted
## Pestaña Rotom Móvil: actividades activas con su camino, progreso, plazo y premio;
## progreso en cada camino, reputación con cada grupo, el elenco de la partida y las
## noticias (lo que pasó al cumplir o al vencer un plazo).


static func build() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var left := MenuStyle.panel_container(Color(0.95, 0.45, 0.35))
	left.custom_minimum_size.x = 900
	row.add_child(left)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	left.add_child(box)
	box.add_child(MenuStyle.label("Rotom Móvil · Día %d · %s" % [GameState.game_day() + 1, DayNight.clock_text(GameState.clock_hour())], 28, MenuStyle.ACCENT))
	box.add_child(MenuStyle.label("Profesor %s · Rival: %s · Amenaza: %s" % [GameState.professor, GameState.rival, GameState.villain_team], 19, MenuStyle.MUTED))
	box.add_child(MenuStyle.label("Actividades", 24, MenuStyle.ACCENT))
	var any := false
	for activity: Dictionary in GameState.activities:
		if activity.get("done", false) or activity.get("failed", false):
			continue
		any = true
		var card := MenuStyle.panel_container()
		var lines := VBoxContainer.new()
		card.add_child(lines)
		var path: Dictionary = ActivityManager.PATHS[activity["path"]]
		lines.add_child(MenuStyle.label("[%s] %s" % [path["name"], activity["title"]], 20))
		var progress := HBoxContainer.new()
		progress.add_theme_constant_override("separation", 10)
		progress.add_child(MenuStyle.bar(float(activity["progress"]) / maxf(float(activity["target"]), 1.0), 300, Color(0.45, 0.85, 0.5), 12))
		var days_left := int(activity["deadline_day"]) - GameState.game_day()
		var hours_left := days_left * 24.0 + (24.0 - GameState.clock_hour())
		progress.add_child(MenuStyle.label("%d / %d · quedan %d h del juego" % [int(activity["progress"]), int(activity["target"]), int(hours_left)], 17, Color(1.0, 0.6, 0.5) if hours_left < 24.0 else MenuStyle.MUTED))
		lines.add_child(progress)
		lines.add_child(MenuStyle.label("Premio: $%d y %s × %d · Si vence: pierdes el premio, baja tu reputación y pasa algo en el mundo." % [int(activity["money"]), Items.display_name(activity["item"]), int(activity["item_amount"])], 15, MenuStyle.MUTED))
		box.add_child(card)
	if not any:
		box.add_child(MenuStyle.label("Sin actividades por ahora. Elige a tu compañero para empezar.", 18, MenuStyle.MUTED))
	var right := MenuStyle.panel_container()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	right.add_child(side)
	side.add_child(MenuStyle.label("Caminos (sin orden)", 22, MenuStyle.ACCENT))
	for key: String in ActivityManager.PATHS:
		var path: Dictionary = ActivityManager.PATHS[key]
		var done := int(GameState.path_progress.get(key, 0))
		var rival_ahead := int(GameState.rival_progress.get(key, 0))
		side.add_child(MenuStyle.label("%s: %d/%d %s%s" % [path["name"], done, int(path["max"]), path["goal"], ("  (rival +%d)" % rival_ahead) if rival_ahead > 0 else ""], 17))
		var rep := int(GameState.reputation.get(path["group"], 50))
		var line := HBoxContainer.new()
		line.add_child(MenuStyle.label("  Reputación con %s " % path["group"], 15, MenuStyle.MUTED))
		line.add_child(MenuStyle.bar(rep / 100.0, 160, Color(0.95, 0.75, 0.25), 8))
		side.add_child(line)
	# Misión de fotografía del día.
	var photo := (_main_photo() as PhotoMode)
	if photo != null:
		var current := photo.mission()
		if not current.is_empty():
			side.add_child(MenuStyle.label("Fotografía del día", 22, Color(0.6, 0.85, 1.0)))
			side.add_child(MenuStyle.wrapped(("✓ " if current.get("done", false) else "📷 ") + "Retrata a un %s (%s Foto)." % [MenuStyle.species(current["species"]).display_name, InputHints.hint("photo")], 15))
	# Megaevolución: Piedra Llave y misiones de megapiedras.
	side.add_child(MenuStyle.label("Megapiedras", 22, Color(1.0, 0.7, 1.0)))
	side.add_child(MenuStyle.wrapped("Piedra Llave: " + ("¡la tienes!" if GameState.item_count("key-stone") > 0 else "dicen que duerme en unas Ruinas Antiguas (resuelve su acertijo)."), 15, MenuStyle.MUTED))
	var missions := MegaMissions.all()
	if missions.is_empty():
		side.add_child(MenuStyle.wrapped("Cuando tengas un Pokémon que pueda megaevolucionar, aparecerá aquí su misión.", 15, MenuStyle.MUTED))
	for mission: Dictionary in missions:
		side.add_child(MenuStyle.wrapped(("✓ " if mission.get("done", false) else "◇ ") + MegaMissions.describe(mission), 15, MenuStyle.ACCENT if mission.get("done", false) else Color(0.95, 0.95, 1.0)))
	side.add_child(MenuStyle.label("Noticias", 22, MenuStyle.ACCENT))
	for item: Dictionary in GameState.news.slice(0, 8):
		side.add_child(MenuStyle.wrapped("Día %d · %s" % [int(item["day"]), item["text"]], 15))
	return row


static func _main_photo() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group(&"photo_mode") if tree != null else null
