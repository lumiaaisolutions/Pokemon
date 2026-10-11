class_name RotomTab
extends RefCounted
## Pestaña Rotom Móvil (rediseño pedido por Fernando, 2026-10-11): el teléfono Rotom
## entra flotando a la izquierda (parpadea y sonríe al cumplir algo, ver
## ui/kit/rotom_character.gd) y a la derecha su pantalla con 7 apps de íconos grandes
## (ui/kit/menu_icon.gd). Al tocar una se abre a pantalla completa con tarjetas.
## Apps: Actividades y caminos, Noticias, Clima y calendario, Charla con Rotom,
## Cámara y álbum, Brújula de objetivos, Contactos.

const APPS := [
	{"title": "Actividades y caminos", "subtitle": "Tus misiones con plazo"},
	{"title": "Noticias", "subtitle": "Lo que pasa en la región"},
	{"title": "Clima y calendario", "subtitle": "Pronóstico y eventos"},
	{"title": "Charla con Rotom", "subtitle": "Consejos para ti"},
	{"title": "Cámara y álbum", "subtitle": "Tus fotos y misión del día"},
	{"title": "Brújula de objetivos", "subtitle": "Marca un lugar en el mapa"},
	{"title": "Contactos", "subtitle": "Líderes, héroes, profesor y rival"},
]


static func build(menu: GameMenu) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 20)
	root.add_child(row)

	# --- Izquierda: el Rotom Teléfono flotando -------------------------------------------
	var left := MenuStyle.panel_container(Color(0.95, 0.45, 0.35))
	left.custom_minimum_size.x = 300
	row.add_child(left)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(side)
	var character := RotomCharacter.new()
	character.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	character.happy = _proud_today(menu)
	side.add_child(character)
	side.add_child(MenuStyle.label("Día %d · %s" % [GameState.game_day() + 1, DayNight.clock_text(GameState.clock_hour())], 19, MenuStyle.ACCENT))
	var tips := _tips(menu)
	side.add_child(MenuStyle.wrapped("💬 " + tips[0], 15, MenuStyle.MUTED))

	# --- Derecha: cuadrícula de apps o la app elegida a pantalla completa ----------------
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(right)

	var grid_scroll := ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(grid_scroll)
	var grid_center := CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.add_child(grid_center)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	grid_center.add_child(grid)

	var app_screen := VBoxContainer.new()
	app_screen.add_theme_constant_override("separation", 10)
	app_screen.visible = false
	app_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(app_screen)
	var app_header := HBoxContainer.new()
	app_header.add_theme_constant_override("separation", 12)
	app_screen.add_child(app_header)
	var back := MenuStyle.button("◂ Volver a las apps", 17)
	back.add_to_group(&"rotom_back_button")
	app_header.add_child(back)
	var app_title := MenuStyle.label("", 22, MenuStyle.ACCENT)
	app_header.add_child(app_title)
	var app_scroll := ScrollContainer.new()
	app_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	app_screen.add_child(app_scroll)
	var app_content := MarginContainer.new()
	app_content.add_theme_constant_override("margin_right", 10)
	app_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_scroll.add_child(app_content)

	back.pressed.connect(func() -> void:
		app_screen.visible = false
		grid_scroll.visible = true)

	for app: Dictionary in APPS:
		var tile := _app_tile(app["title"], app["subtitle"])
		tile.add_to_group(&"rotom_app_tile")
		tile.pressed.connect(func() -> void:
			grid_scroll.visible = false
			app_screen.visible = true
			app_title.text = app["title"]
			for child in app_content.get_children():
				child.queue_free()
			var page := _build_app(String(app["title"]), menu)
			app_content.add_child(page)
			UiKit.animate_in(page))
		grid.add_child(tile)
	return root


## Una tarjeta grande de app: ícono, título y una línea de descripción.
static func _app_tile(title: String, subtitle: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(300, 140)
	var style := MenuStyle.panel(Color(1, 1, 1, 0.14))
	var hover := style.duplicate() as StyleBoxFlat
	hover.border_color = UiKit.RED if UiKit.light else UiKit.MINT
	hover.set_border_width_all(4)
	for state in ["normal", "focus", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("hover", hover)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	row.add_child(MenuIcon.make(title, 72))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var title_label := UiKit.label(title, 19, UiKit.INK if UiKit.light else UiKit.WHITE, true)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(title_label)
	text.add_child(MenuStyle.wrapped(subtitle, 14, MenuStyle.MUTED))
	button.tooltip_text = subtitle
	button.pressed.connect(func() -> void: AudioBus.play_sfx("ui_decide"))
	return button


static func _build_app(title: String, menu: GameMenu) -> Control:
	match title:
		"Actividades y caminos":
			return _app_activities(menu)
		"Noticias":
			return _app_news(menu)
		"Clima y calendario":
			return _app_weather(menu)
		"Charla con Rotom":
			return _app_chat(menu)
		"Cámara y álbum":
			return _app_camera(menu)
		"Brújula de objetivos":
			return _app_compass(menu)
		"Contactos":
			return _app_contacts(menu)
	return VBoxContainer.new()


# --- Utilidades compartidas --------------------------------------------------------------

static func _group(menu: GameMenu, name: StringName) -> Node:
	return menu.get_tree().get_first_node_in_group(name) if menu != null else null


## Tarjeta blanca con una línea de acento a la izquierda (estilo de toda la app).
static func _card(accent: Color = Color(1, 1, 1, 0.14)) -> PanelContainer:
	return MenuStyle.panel_container(accent)


static func _emoji_badge(emoji: String, color: Color, diameter: float = 44.0) -> Control:
	var holder := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(diameter * 0.5))
	holder.add_theme_stylebox_override("panel", style)
	holder.custom_minimum_size = Vector2(diameter, diameter)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = emoji
	label.add_theme_font_size_override("font_size", int(diameter * 0.5))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(label)
	return holder


## ¿El Rotom tiene algo que celebrar hoy? (logro, actividad o misión de foto cumplida).
static func _proud_today(menu: GameMenu) -> bool:
	var today := GameState.game_day() + 1
	for day in GameState.achievements.values():
		if int(day) == today:
			return true
	if not GameState.money_log.is_empty():
		var last: Dictionary = GameState.money_log[0]
		if int(last.get("day", -1)) == today and int(last.get("amount", 0)) > 0:
			return true
	var photo := _group(menu, &"photo_mode") as PhotoMode
	if photo != null:
		var mission := photo.mission()
		if mission.get("done", false) and int(mission.get("day", -1)) == GameState.game_day():
			return true
	return false


## Consejos según lo que te falta (para el saludo y la app "Charla con Rotom").
static func _tips(menu: GameMenu) -> Array[String]:
	var tips: Array[String] = []
	var badges := Regions.badges()
	if badges < 8:
		tips.append("Te faltan %d medalla%s para retar a la Liga de %s." % [8 - badges, "" if 8 - badges == 1 else "s", Regions.region_name()])
	var photo := _group(menu, &"photo_mode") as PhotoMode
	if photo != null:
		var mission := photo.mission()
		if not mission.is_empty() and not mission.get("done", false):
			var species := MenuStyle.species(String(mission["species"]))
			if species != null:
				tips.append("Te falta fotografiar a un %s hoy (%s)." % [species.display_name, InputHints.hint("photo")])
	for activity: Dictionary in GameState.activities:
		if activity.get("done", false) or activity.get("failed", false):
			continue
		var days_left := int(activity["deadline_day"]) - GameState.game_day()
		var hours_left := days_left * 24.0 + (24.0 - GameState.clock_hour())
		if hours_left < 20.0:
			tips.append("¡\"%s\" vence pronto! Te quedan %d h del juego." % [activity["title"], int(maxf(hours_left, 0.0))])
	if GameState.item_count("key-stone") <= 0:
		tips.append("Dicen que la Piedra Llave duerme en unas Ruinas Antiguas; resuelve su acertijo para megaevolucionar.")
	if not GameState.reputation.is_empty():
		var lowest_group := ""
		var lowest_value := 999
		for group: String in GameState.reputation:
			var value := int(GameState.reputation[group])
			if value < lowest_value:
				lowest_value = value
				lowest_group = group
		if lowest_group != "" and lowest_value < 45:
			tips.append("Tu reputación con %s está baja (%d/100). Cumple una actividad de ese camino para subirla." % [lowest_group, lowest_value])
	if tips.is_empty():
		tips.append("¡Vas muy bien! Por ahora no tengo ningún consejo pendiente.")
	return tips


# --- App 1: Actividades y caminos --------------------------------------------------------

static func _app_activities(_menu: GameMenu) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var active := GameState.activities.filter(func(a: Dictionary) -> bool: return not a.get("done", false) and not a.get("failed", false))
	box.add_child(MenuStyle.label("Actividades activas · %d/%d" % [active.size(), ActivityManager.MAX_ACTIVE], 21, MenuStyle.ACCENT))
	if active.is_empty():
		box.add_child(MenuStyle.wrapped("Sin actividades por ahora. Elige a tu compañero para empezar.", 16, MenuStyle.MUTED))
	for activity: Dictionary in active:
		box.add_child(_activity_card(activity))
	box.add_child(MenuStyle.label("Caminos", 21, MenuStyle.ACCENT))
	var path_grid := GridContainer.new()
	path_grid.columns = 2
	path_grid.add_theme_constant_override("h_separation", 14)
	path_grid.add_theme_constant_override("v_separation", 14)
	box.add_child(path_grid)
	for key: String in ActivityManager.PATHS:
		path_grid.add_child(_path_card(key))
	box.add_child(_mega_card())
	return box


static func _activity_card(activity: Dictionary) -> Control:
	var path: Dictionary = ActivityManager.PATHS[activity["path"]]
	var card := _card(Color(0.95, 0.75, 0.25))
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 6)
	card.add_child(lines)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	lines.add_child(head)
	head.add_child(_emoji_badge("📋", Color(0.95, 0.75, 0.25), 36))
	head.add_child(MenuStyle.label("[%s] %s" % [path["name"], activity["title"]], 18))
	var progress := HBoxContainer.new()
	progress.add_theme_constant_override("separation", 10)
	progress.add_child(MenuStyle.bar(float(activity["progress"]) / maxf(float(activity["target"]), 1.0), 280, Color(0.45, 0.85, 0.5), 12))
	var days_left := int(activity["deadline_day"]) - GameState.game_day()
	var hours_left := days_left * 24.0 + (24.0 - GameState.clock_hour())
	progress.add_child(MenuStyle.label("%d / %d · quedan %d h" % [int(activity["progress"]), int(activity["target"]), int(hours_left)], 16, Color(1.0, 0.6, 0.5) if hours_left < 24.0 else MenuStyle.MUTED))
	lines.add_child(progress)
	var reward := HBoxContainer.new()
	reward.add_theme_constant_override("separation", 6)
	reward.add_child(UiKit.icon_rect(Items.icon(activity["item"]), Vector2(22, 22)))
	reward.add_child(MenuStyle.wrapped("$%d y %s × %d · si vence, pierdes el premio y baja tu reputación." % [int(activity["money"]), Items.display_name(activity["item"]), int(activity["item_amount"])], 14, MenuStyle.MUTED))
	lines.add_child(reward)
	card.tooltip_text = "%s: cumple el objetivo antes del plazo para cobrar el premio." % path["name"]
	return card


static func _path_card(key: String) -> Control:
	var path: Dictionary = ActivityManager.PATHS[key]
	var card := _card()
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 6)
	card.add_child(lines)
	var done := int(GameState.path_progress.get(key, 0))
	var max_steps := int(path["max"])
	var rival_ahead := int(GameState.rival_progress.get(key, 0))
	lines.add_child(MenuStyle.label(path["name"], 18, MenuStyle.ACCENT))
	var badges_row := HBoxContainer.new()
	badges_row.add_theme_constant_override("separation", 3)
	for i in max_steps:
		badges_row.add_child(_emoji_badge("✓" if i < done else "", Color(0.45, 0.8, 0.5) if i < done else Color(0, 0, 0, 0.08), 20))
	lines.add_child(badges_row)
	lines.add_child(MenuStyle.label("%d/%d %s%s" % [done, max_steps, path["goal"], ("  · rival +%d" % rival_ahead) if rival_ahead > 0 else ""], 15))
	var rep := int(GameState.reputation.get(path["group"], 50))
	var rep_row := HBoxContainer.new()
	rep_row.add_theme_constant_override("separation", 8)
	rep_row.add_child(MenuStyle.label("Reputación %s" % path["group"], 14, MenuStyle.MUTED))
	rep_row.add_child(MenuStyle.bar(rep / 100.0, 130, Color(0.95, 0.75, 0.25), 8))
	lines.add_child(rep_row)
	card.tooltip_text = "Cada actividad de %s cumplida suma 1 a este camino y sube tu reputación con %s." % [path["name"], path["group"]]
	return card


static func _mega_card() -> Control:
	var card := _card(Color(1.0, 0.7, 1.0))
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 6)
	card.add_child(lines)
	lines.add_child(MenuStyle.label("Megapiedras", 20, Color(0.7, 0.3, 0.7)))
	lines.add_child(MenuStyle.wrapped("Piedra Llave: " + ("¡la tienes!" if GameState.item_count("key-stone") > 0 else "dicen que duerme en unas Ruinas Antiguas (resuelve su acertijo)."), 15, MenuStyle.MUTED))
	var missions := MegaMissions.all()
	if missions.is_empty():
		lines.add_child(MenuStyle.wrapped("Cuando tengas un Pokémon que pueda megaevolucionar, aparecerá aquí su misión.", 14, MenuStyle.MUTED))
	for mission: Dictionary in missions:
		lines.add_child(MenuStyle.wrapped(("✓ " if mission.get("done", false) else "◇ ") + MegaMissions.describe(mission), 14, MenuStyle.ACCENT if mission.get("done", false) else MenuStyle.TEXT))
	return card


# --- App 2: Noticias ----------------------------------------------------------------------

const NEWS_STYLE := {
	"brote": {"emoji": "🐛", "color": Color(0.45, 0.8, 0.5)},
	"bandada": {"emoji": "🕊", "color": Color(0.5, 0.75, 0.98)},
	"rumor": {"emoji": "❓", "color": Color(0.7, 0.55, 0.9)},
	"dominante": {"emoji": "👑", "color": Color(0.95, 0.55, 0.3)},
	"medalla": {"emoji": "🏅", "color": Color(0.95, 0.75, 0.25)},
	"general": {"emoji": "📰", "color": Color(0.6, 0.6, 0.68)},
}


static func _app_news(menu: GameMenu) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(MenuStyle.label("Noticias · %d" % GameState.news.size(), 21, MenuStyle.ACCENT))
	if GameState.news.is_empty():
		box.add_child(MenuStyle.wrapped("Todavía no hay noticias. Te avisaré aquí de brotes, bandadas, medallas y rumores.", 16, MenuStyle.MUTED))
		return box
	var events := _group(menu, &"world_events") as WorldEvents
	var outbreak := events.current_outbreak() if events != null else {}
	for i in GameState.news.size():
		var item: Dictionary = GameState.news[i]
		var kind := String(item.get("type", "general"))
		var style: Dictionary = NEWS_STYLE.get(kind, NEWS_STYLE["general"])
		var card := _card(style["color"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		row.add_child(_emoji_badge(style["emoji"], style["color"]))
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		text.add_child(MenuStyle.wrapped(String(item["text"]), 16))
		# La hora se guarda desde 2026-10-11 (revisión de Fernando); las noticias de
		# partidas viejas no la tienen, así que se muestra solo si existe.
		var day_label := "Día %d" % int(item["day"])
		if item.has("hour"):
			day_label += " · %s" % DayNight.clock_text(float(item["hour"]))
		text.add_child(MenuStyle.label(day_label, 13, MenuStyle.MUTED))
		if i == 0 and kind == "brote" and not outbreak.is_empty():
			var see := MenuStyle.button("Ver en el mapa", 14)
			see.pressed.connect(func() -> void:
				var map_ui := menu.main.get_node_or_null("MapUi") as MapUi if menu.main != null else null
				if map_ui != null:
					map_ui.set_waypoint(Vector3(float(outbreak["x"]), 0.0, float(outbreak["z"])))
				GameState.world_flags["waypoint_label"] = "Brote masivo")
			row.add_child(see)
		box.add_child(card)
	return box


# --- App 3: Clima y calendario -------------------------------------------------------------

static func _app_weather(menu: GameMenu) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.add_child(MenuStyle.label("Clima y calendario", 21, MenuStyle.ACCENT))
	var today := _card(Color(0.5, 0.7, 0.95))
	var today_row := HBoxContainer.new()
	today_row.add_theme_constant_override("separation", 14)
	today.add_child(today_row)
	today_row.add_child(_emoji_badge(Weather.ICONS[Weather.current], Color(0.5, 0.7, 0.95), 52))
	var today_text := VBoxContainer.new()
	today_row.add_child(today_text)
	today_text.add_child(MenuStyle.label("Hoy: %s" % Weather.NAMES[Weather.current], 19))
	today_text.add_child(MenuStyle.label("Estación: %s (día %d del juego)" % [Weather.season_name(GameState.game_day()), GameState.game_day() + 1], 16, MenuStyle.MUTED))
	var events := _group(menu, &"world_events") as WorldEvents
	if events != null and events.meteor_scheduled_today():
		today_text.add_child(MenuStyle.label("✨ Esta noche habrá lluvia de estrellas (después de las 20:00).", 15, Color(0.8, 0.85, 1.0)))
	# Clima extremo real (completar lo simplificado del mundo, 2026-10-11): además del
	# aviso del Rotom al amanecer, se ve aquí todo el día qué bioma lo tiene.
	if events != null:
		var extreme := events.extreme_weather_today()
		if not extreme.is_empty():
			var extreme_biome: String = RegionLayout.BIOME_NAMES[int(extreme["biome"])]
			today_text.add_child(MenuStyle.label("⚠ %s hoy en zonas de %s." % [events.extreme_weather_name_today(), extreme_biome], 15, Color(1.0, 0.75, 0.4)))
	box.add_child(today)
	var world := menu.main.get_node_or_null("World") as WorldBuilder if menu.main != null else null
	var player := menu.main.get_node_or_null("Player") as Node3D if menu.main != null else null
	if world != null and player != null:
		var forecast := _card()
		var forecast_box := VBoxContainer.new()
		forecast_box.add_theme_constant_override("separation", 6)
		forecast.add_child(forecast_box)
		forecast_box.add_child(MenuStyle.label("Pronóstico aquí cerca (puede cambiar si viajas de bioma)", 17, MenuStyle.ACCENT))
		var biome := world.layout.biome_at(player.global_position.x, player.global_position.z)
		for d in range(1, 5):
			var future_time := GameState.play_time + d * GameState.DAY_SECONDS
			var kind := Weather.weather_for(biome, future_time, GameState.world_seed)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.add_child(MenuStyle.label(Weather.ICONS[kind], 20))
			row.add_child(MenuStyle.label("Día %d: %s" % [GameState.game_day() + 1 + d, Weather.NAMES[kind]], 16))
			forecast_box.add_child(row)
		box.add_child(forecast)
	var schedule := _card(Color(0.95, 0.55, 0.3))
	var schedule_box := VBoxContainer.new()
	schedule_box.add_theme_constant_override("separation", 6)
	schedule.add_child(schedule_box)
	schedule_box.add_child(MenuStyle.label("Horario de los líderes de gimnasio", 18, MenuStyle.ACCENT))
	schedule_box.add_child(MenuStyle.wrapped("Gimnasio abierto de %d:00 a %d:00; luego entrenan afuera hasta las %d:00; de noche están en casa. Un día a la semana viajan." % [int(GymLeaders.GYM_START), int(GymLeaders.GYM_END), int(GymLeaders.TRAINING_END)], 15))
	box.add_child(schedule)
	return box


# --- App 4: Charla con Rotom ---------------------------------------------------------------

static func _app_chat(menu: GameMenu) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_child(MenuStyle.label("Charla con Rotom", 21, MenuStyle.ACCENT))
	box.add_child(MenuStyle.wrapped("Esto es lo que te recomiendo ahora:", 16, MenuStyle.MUTED))
	var tips := _tips(menu)
	for i in tips.size():
		var card := _card(Color(0.5, 0.75, 0.98))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		row.add_child(_emoji_badge("💬", Color(0.5, 0.75, 0.98)))
		row.add_child(MenuStyle.wrapped(tips[i], 16))
		box.add_child(card)
		UiKit.animate_in(card, i * 0.08)
	return box


# --- App 5: Cámara y álbum ------------------------------------------------------------------

static func _app_camera(menu: GameMenu) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.add_child(MenuStyle.label("Cámara y álbum", 21, MenuStyle.ACCENT))
	var photo := _group(menu, &"photo_mode") as PhotoMode
	var mission_card := _card(Color(0.6, 0.85, 1.0))
	var mission_box := VBoxContainer.new()
	mission_box.add_theme_constant_override("separation", 6)
	mission_card.add_child(mission_box)
	mission_box.add_child(MenuStyle.label("Misión de fotografía del día", 18, Color(0.3, 0.55, 0.85)))
	if photo != null:
		var mission := photo.mission()
		if not mission.is_empty():
			var species := MenuStyle.species(String(mission["species"]))
			var done: bool = mission.get("done", false)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			mission_box.add_child(row)
			if species != null:
				row.add_child(UiKit.icon_rect(MenuStyle.front_sprite(species), Vector2(64, 64)))
			row.add_child(MenuStyle.wrapped(("✓ ¡Ya la cumpliste! " if done else "📷 Falta retratar a ") + (species.display_name if species != null else "?") + ("." if done else (" (%s Foto)." % InputHints.hint("photo"))), 16))
		else:
			mission_box.add_child(MenuStyle.wrapped("Hoy no hay un Pokémon cerca para la misión; sal a explorar.", 15, MenuStyle.MUTED))
	box.add_child(mission_card)
	box.add_child(MenuStyle.label("Álbum", 20, MenuStyle.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var files := _photo_files()
	if files.is_empty():
		box.add_child(MenuStyle.wrapped("Todavía no has tomado fotos. Sal al mundo y presiona %s." % InputHints.hint("photo"), 15, MenuStyle.MUTED))
	else:
		for path in files.slice(0, 16):
			var image := Image.new()
			if image.load(PhotoMode.PHOTO_DIR + path) == OK:
				image.resize(160, 90, Image.INTERPOLATE_LANCZOS)
				var frame := PanelContainer.new()
				frame.add_theme_stylebox_override("panel", UiKit.card_style(8))
				frame.add_child(UiKit.icon_rect(ImageTexture.create_from_image(image), Vector2(140, 80)))
				grid.add_child(frame)
		box.add_child(grid)
	return box


static func _photo_files() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(PhotoMode.PHOTO_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".png"):
			result.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort()
	result.reverse()
	return result


# --- App 6: Brújula de objetivos -----------------------------------------------------------

static func _app_compass(menu: GameMenu) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.add_child(MenuStyle.label("Brújula de objetivos", 21, MenuStyle.ACCENT))
	box.add_child(MenuStyle.wrapped("Elige qué marcar: una bandera y una flecha en el minimapa te guían hasta llegar.", 16, MenuStyle.MUTED))
	var current_card := _card(Color(0.95, 0.75, 0.25))
	var current_row := HBoxContainer.new()
	current_row.add_theme_constant_override("separation", 12)
	current_card.add_child(current_row)
	var current_label := String(GameState.world_flags.get("waypoint_label", ""))
	var current_text := MenuStyle.label("Objetivo actual: %s" % (current_label if current_label != "" else "ninguno"), 17)
	current_row.add_child(current_text)
	var clear := MenuStyle.button("Quitar objetivo", 14)
	clear.visible = current_label != ""
	clear.pressed.connect(func() -> void:
		var map_ui := menu.main.get_node_or_null("MapUi") as MapUi if menu.main != null else null
		if map_ui != null:
			map_ui.clear_waypoint()
		GameState.world_flags.erase("waypoint_label")
		current_text.text = "Objetivo actual: ninguno"
		clear.visible = false)
	current_row.add_child(clear)
	box.add_child(current_card)

	var categories := [
		{"title": "Líder de gimnasio", "targets": _compass_leaders(menu)},
		{"title": "Brote masivo", "targets": _compass_outbreak(menu)},
		{"title": "Cueva descubierta", "targets": _compass_caves(menu)},
		{"title": "Guardián de bioma", "targets": _compass_guardians(menu)},
	]
	for category: Dictionary in categories:
		box.add_child(MenuStyle.label(category["title"], 19, MenuStyle.ACCENT))
		var targets: Array = category["targets"]
		if targets.is_empty():
			box.add_child(MenuStyle.wrapped("Nada que marcar aquí por ahora.", 15, MenuStyle.MUTED))
			continue
		for target: Dictionary in targets:
			var card := _card()
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			card.add_child(row)
			var info := MenuStyle.wrapped(String(target["text"]), 15)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info)
			var mark := MenuStyle.button("Marcar", 14)
			mark.add_to_group(&"rotom_compass_target")
			mark.pressed.connect(func() -> void:
				var map_ui := menu.main.get_node_or_null("MapUi") as MapUi if menu.main != null else null
				if map_ui != null:
					map_ui.set_waypoint(Vector3(float(target["x"]), 0.0, float(target["z"])))
				GameState.world_flags["waypoint_label"] = String(target["label"])
				current_text.text = "Objetivo actual: %s" % target["label"]
				clear.visible = true
				AudioBus.play_sfx("ui_decide"))
			row.add_child(mark)
			box.add_child(card)
	return box


static func _compass_leaders(menu: GameMenu) -> Array:
	var leaders := _group(menu, &"gym_leaders") as GymLeaders
	var result: Array = []
	if leaders == null:
		return result
	var won: Array = GameState.world_flags.get("badges", [])
	for entry: Dictionary in leaders.gyms():
		var id: String = entry["id"]
		var settlement: Dictionary = entry["settlement"]
		var has_badge := (won as Array).has(settlement.get("name", ""))
		var where := leaders.where(id)
		if where.is_empty():
			continue
		result.append({"text": "%s%s (%s) · %s" % ["✓ " if has_badge else "", Leaders.name_of(id), Leaders.type_name(id), where["text"]],
				"x": float(where["x"]), "z": float(where["z"]), "label": "Líder " + Leaders.name_of(id)})
	return result


static func _compass_outbreak(menu: GameMenu) -> Array:
	var events := _group(menu, &"world_events") as WorldEvents
	var world := menu.main.get_node_or_null("World") as WorldBuilder if menu.main != null else null
	if events == null or world == null:
		return []
	var outbreak := events.current_outbreak()
	if outbreak.is_empty():
		return []
	var species := MenuStyle.species(String(outbreak["species"]))
	if species == null:
		return []
	return [{"text": "Brote masivo de %s cerca de %s (solo hoy)." % [species.display_name, world.location_name(float(outbreak["x"]), float(outbreak["z"]))],
			"x": float(outbreak["x"]), "z": float(outbreak["z"]), "label": "Brote: " + species.display_name}]


static func _compass_caves(menu: GameMenu) -> Array:
	var result: Array = []
	var pois := _group(menu, &"points_of_interest") as PointsOfInterest
	if pois == null:
		return result
	var i := 0
	for poi: Dictionary in PointsOfInterest.seen_list():
		if String(poi["kind"]) != "small_cave":
			continue
		i += 1
		result.append({"text": "Cueva chica descubierta #%d." % i, "x": float(poi["x"]), "z": float(poi["z"]), "label": "Cueva chica #%d" % i})
		if result.size() >= 6:
			break
	return result


## Guardianes de bioma reales (Fase 6): uno por bioma de la región, con su estado.
static func _compass_guardians(menu: GameMenu) -> Array:
	var result: Array = []
	var bosses := _group(menu, &"bosses") as BossManager
	if bosses == null:
		return result
	for target: Dictionary in bosses.guardian_targets():
		var defeated: bool = target["defeated"]
		result.append({"text": "%s%s: %s." % ["✓ " if defeated else "", target["label"], "ya lo venciste" if defeated else "un Pokémon enorme y fuerte vigila la zona"],
				"x": float(target["x"]), "z": float(target["z"]), "label": String(target["label"])})
		if result.size() >= 8:
			break
	return result


# --- App 7: Contactos -----------------------------------------------------------------------

static func _app_contacts(menu: GameMenu) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.add_child(MenuStyle.label("Contactos", 21, MenuStyle.ACCENT))

	box.add_child(MenuStyle.label("Líderes de gimnasio", 19, MenuStyle.ACCENT))
	var leaders := _group(menu, &"gym_leaders") as GymLeaders
	if leaders != null:
		var won: Array = GameState.world_flags.get("badges", [])
		for entry: Dictionary in leaders.gyms():
			var id: String = entry["id"]
			var where := leaders.where(id)
			var has_badge := (won as Array).has((entry["settlement"] as Dictionary).get("name", ""))
			box.add_child(_contact_card("Líder " + Leaders.name_of(id), Leaders.type_name(id).capitalize(), String(where.get("text", "?")),
					"✓ Ya tienes su medalla." if has_badge else "Habla con él en su gimnasio para ganarla.",
					Vector3(float(where.get("x", 0.0)), 0.0, float(where.get("z", 0.0))), "Líder " + Leaders.name_of(id), menu))
	else:
		box.add_child(MenuStyle.wrapped("Todavía no hay líderes asignados en esta región.", 15, MenuStyle.MUTED))

	box.add_child(MenuStyle.label("Héroes no elegidos", 19, MenuStyle.ACCENT))
	var heroes := _group(menu, &"heroes") as Heroes
	if heroes != null:
		var rumored: Array = heroes.rumored_today()
		for id: String in heroes.roster():
			var name := String(PlayerCharacters.find(id)["name"])
			var has_rumor: bool = rumored.has(id)
			var loc := heroes.location(id)
			var status := "Hoy se le vio cerca de %s (de 8:00 a 20:00)." % loc.get("name", "?") if has_rumor else "Sin rumor fresco hoy; viaja por la región sin aviso."
			if heroes.beaten_today(id):
				status += " Ya lo venciste hoy: vuelve mañana por la revancha."
			var target := Vector3(float(loc.get("x", 0.0)), 0.0, float(loc.get("z", 0.0))) if has_rumor else Vector3.INF
			box.add_child(_contact_card(name, "Entrenador único", status, "", target, "Héroe " + name, menu))
	else:
		box.add_child(MenuStyle.wrapped("Todavía no hay héroes activos.", 15, MenuStyle.MUTED))

	box.add_child(MenuStyle.label("Profesor y rival", 19, MenuStyle.ACCENT))
	var professor := _group(menu, &"professor") as Professor
	var professor_status := "Trabaja en el laboratorio de 8:00 a 19:00."
	if professor != null:
		var trip := professor.trip_place()
		if not trip.is_empty():
			professor_status = "Hoy salió de viaje de investigación; vuelve mañana al laboratorio."
		elif professor.in_lab():
			professor_status = "Está en el laboratorio ahora mismo."
	box.add_child(_contact_card(Professor.title(), "Profesor de la región", professor_status, "", Vector3.INF, "", menu))
	var rival_badges := int(GameState.world_flags.get("rival_badges", 0))
	box.add_child(_contact_card(GameState.rival if GameState.rival != "" else "Rival", "Rival", "Te busca tras cada medalla nueva y, de vez en cuando, en los caminos (tenía %d medallas la última vez)." % rival_badges, "", Vector3.INF, "", menu))
	return box


static func _contact_card(name: String, role: String, status: String, advice: String, target: Vector3, label: String, menu: GameMenu) -> Control:
	var card := _card(Color(0.5, 0.7, 0.95))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(_emoji_badge("★", Color(0.5, 0.7, 0.95)))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 3)
	row.add_child(text)
	text.add_child(MenuStyle.label("%s · %s" % [name, role], 17))
	text.add_child(MenuStyle.wrapped(status + (("  " + advice) if advice != "" else ""), 14, MenuStyle.MUTED))
	if target != Vector3.INF:
		var mark := MenuStyle.button("Marcar en el mapa", 14)
		mark.pressed.connect(func() -> void:
			var map_ui := menu.main.get_node_or_null("MapUi") as MapUi if menu.main != null else null
			if map_ui != null:
				map_ui.set_waypoint(target)
			GameState.world_flags["waypoint_label"] = label
			AudioBus.play_sfx("ui_decide"))
		row.add_child(mark)
	return card
