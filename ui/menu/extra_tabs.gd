class_name ExtraTabs
extends RefCounted
## Pestañas Caja (PC), Logros y estadísticas, y Dinero del menú.


## Caja: los capturados fuera del equipo; se pasan al equipo, se cambian con un
## miembro o se liberan.
static func box(menu: GameMenu) -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.add_child(MenuStyle.label("Caja (PC) · %d Pokémon guardados" % GameState.box.size(), 28, MenuStyle.ACCENT))
	root.add_child(MenuStyle.wrapped("Cuando el equipo está lleno (6), lo que capturas llega aquí. Pasa un Pokémon al equipo o cámbialo por el que tengas elegido en la tira de arriba.", 18, MenuStyle.MUTED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	root.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	if GameState.box.is_empty():
		root.add_child(MenuStyle.label("La caja está vacía.", 20, MenuStyle.MUTED))
	for i in GameState.box.size():
		var entry: Dictionary = GameState.box[i]
		var species := MenuStyle.species(entry["species"])
		var card := MenuStyle.panel_container()
		var column := VBoxContainer.new()
		card.add_child(column)
		column.add_child(MenuStyle.texture_rect(MenuStyle.front_sprite(species, entry.get("shiny", false)), Vector2(96, 96)))
		column.add_child(MenuStyle.label(species.display_name + (" ✦" if entry.get("shiny", false) else ""), 17))
		var to_party := MenuStyle.button("Al equipo" if GameState.party.size() < GameState.PARTY_MAX else "Cambiar", 15)
		to_party.pressed.connect(func() -> void:
			if GameState.party.size() < GameState.PARTY_MAX:
				GameState.party.append(GameState.box.pop_at(i))
			else:
				var member := clampi(menu.selected_member, 0, GameState.party.size() - 1)
				if member == GameState.companion_index:
					return
				var swapped: Dictionary = GameState.party[member]
				GameState.party[member] = GameState.box[i]
				GameState.box[i] = swapped
			menu.refresh_strip()
			menu.show_tab(menu.tab))
		column.add_child(to_party)
		var release := MenuStyle.button("Liberar", 15)
		release.pressed.connect(func() -> void:
			GameState.box.remove_at(i)
			GameState.notice.emit("%s volvió a la naturaleza. ¡Adiós!" % species.display_name)
			menu.show_tab(menu.tab))
		column.add_child(release)
		grid.add_child(card)
	if GameState.party.size() > 1:
		var member := clampi(menu.selected_member, 0, GameState.party.size() - 1)
		if member != GameState.companion_index:
			var send := MenuStyle.button("Enviar a la Caja: %s" % MenuStyle.species(GameState.party[member]["species"]).display_name, 18)
			send.pressed.connect(func() -> void:
				var moved: Dictionary = GameState.party.pop_at(member)
				GameState.box.append(moved)
				if GameState.companion_index > member:
					GameState.companion_index -= 1
				menu.selected_member = GameState.companion_index
				menu.refresh_strip()
				menu.show_tab(menu.tab))
			root.add_child(send)
	return root


## Íconos simples (emoji) por categoría de la estadística, para no dejar listas de texto
## plano (pedido de Fernando, 2026-10-11: "tarjetas, íconos y colores por categoría").
const STAT_ICONS := {"distance": "🥾", "captures": "🎯", "shinies": "✨", "behind": "🫣", "defeated": "🤝",
		"gathered": "🧺", "activities": "📋", "blackouts": "💤", "recoveries": "💪"}


## Logros (medallas por hitos, en tarjetas con ícono y barra) y estadísticas de la partida.
static func achievements() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var left := MenuStyle.panel_container(MenuStyle.ACCENT)
	left.custom_minimum_size.x = 920
	row.add_child(left)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	left.add_child(column)
	column.add_child(MenuStyle.label("Logros · %d de %d" % [GameState.achievements.size(), Achievements.LIST.size()], 26, MenuStyle.ACCENT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 540)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	for entry: Array in Achievements.LIST:
		grid.add_child(_achievement_card(entry))
	var right := MenuStyle.panel_container()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	right.add_child(stats)
	stats.add_child(MenuStyle.label("Estadísticas", 26, MenuStyle.ACCENT))
	var names := {"distance": "Recorrido", "captures": "Capturas", "shinies": "Shinies capturados", "behind": "Capturas por la espalda",
			"defeated": "Salvajes debilitados por tu compañero", "gathered": "Objetos recogidos", "activities": "Actividades cumplidas",
			"blackouts": "Desmayos (Centro Pokémon)", "recoveries": "Recuperaciones en el campo"}
	for key: String in names:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		line.add_child(MenuStyle.label(STAT_ICONS.get(key, "•"), 18))
		line.add_child(MenuStyle.label("%s: %s" % [names[key], _number(float(GameState.stats.get(key, 0.0)), key)], 18))
		stats.add_child(line)
	var minutes := int(GameState.play_time / 60.0)
	stats.add_child(MenuStyle.label("⏱ Tiempo jugado: %d h %02d min · Día del juego %d" % [minutes / 60, minutes % 60, GameState.game_day() + 1], 18))
	return row


static func _achievement_card(entry: Array) -> Control:
	var unlocked := GameState.achievements.has(entry[0])
	var value := float(GameState.stats.get(entry[3], 0.0))
	var goal := float(entry[4])
	var card := MenuStyle.panel_container(Color(1.0, 0.85, 0.3) if unlocked else Color(1, 1, 1, 0.14))
	card.custom_minimum_size = Vector2(420, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(1.0, 0.8, 0.25) if unlocked else Color(0, 0, 0, 0.1)
	badge_style.set_corner_radius_all(24)
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.custom_minimum_size = Vector2(48, 48)
	var badge_label := UiKit.label("🏅" if unlocked else "🔒", 22, Color.WHITE, true)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(badge_label)
	row.add_child(badge)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(MenuStyle.label(String(entry[1]), 18, MenuStyle.TEXT if unlocked else MenuStyle.MUTED))
	if not unlocked:
		text.add_child(MenuStyle.bar(value / maxf(goal, 1.0), 320, Color(0.95, 0.75, 0.25), 8))
		text.add_child(MenuStyle.label("%s / %s" % [_number(value, entry[3]), _number(goal, entry[3])], 14, MenuStyle.MUTED))
	card.tooltip_text = String(entry[2])
	return card


static func _number(value: float, key: String) -> String:
	if key == "distance":
		return "%.1f km" % (value / 1000.0) if value >= 1000.0 else "%d m" % int(value)
	return str(int(value))


## Dinero: saldo grande con monedas, gráfica de ingresos y gastos, movimientos recientes
## con ícono y precios de referencia con el ícono del objeto (pedido de Fernando,
## 2026-10-11: "nada de listas de texto plano").
static func money() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var left := MenuStyle.panel_container(MenuStyle.ACCENT)
	left.custom_minimum_size.x = 780
	row.add_child(left)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	left.add_child(box)
	# Saldo grande con la moneda del menú.
	var balance := HBoxContainer.new()
	balance.add_theme_constant_override("separation", 14)
	box.add_child(balance)
	balance.add_child(MenuIcon.make("Dinero", 64))
	balance.add_child(MenuStyle.label("$%s" % _thousands(GameState.money), 36, MenuStyle.ACCENT))
	box.add_child(MenuStyle.label("Ingresos y gastos (últimos movimientos, el más nuevo a la derecha)", 16, MenuStyle.MUTED))
	box.add_child(_money_chart(GameState.money_log.slice(0, 14)))
	box.add_child(MenuStyle.label("Movimientos recientes", 22, MenuStyle.ACCENT))
	var moves := ScrollContainer.new()
	moves.custom_minimum_size = Vector2(0, 300)
	moves.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(moves)
	var moves_box := VBoxContainer.new()
	moves_box.add_theme_constant_override("separation", 6)
	moves.add_child(moves_box)
	if GameState.money_log.is_empty():
		moves_box.add_child(MenuStyle.label("Sin movimientos todavía.", 18, MenuStyle.MUTED))
	for entry: Dictionary in GameState.money_log.slice(0, 20):
		var amount := int(entry["amount"])
		var move_row := HBoxContainer.new()
		move_row.add_theme_constant_override("separation", 8)
		move_row.add_child(UiKit.label("▲" if amount >= 0 else "▼", 15, Color(0.3, 0.7, 0.35) if amount >= 0 else Color(0.8, 0.3, 0.28), true))
		move_row.add_child(MenuStyle.label("Día %d · %s$%d · %s" % [int(entry["day"]), "+" if amount >= 0 else "−", absi(amount), entry["reason"]], 16,
				Color(0.25, 0.55, 0.3) if amount >= 0 else Color(0.75, 0.3, 0.28)))
		moves_box.add_child(move_row)
	var right := MenuStyle.panel_container()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var prices := VBoxContainer.new()
	prices.add_theme_constant_override("separation", 8)
	right.add_child(prices)
	prices.add_child(MenuStyle.label("Precios de referencia (tiendas de los pueblos)", 22, MenuStyle.ACCENT))
	for id in ["poke-ball", "great-ball", "ultra-ball", "potion", "super-potion", "repel", "escape-rope", "nugget", "pearl", "star-piece"]:
		var item := Items.get_item(id)
		var sell := int(item.get("sell", int(item.get("price", 0)) / 2))
		var price_row := HBoxContainer.new()
		price_row.add_theme_constant_override("separation", 10)
		price_row.add_child(UiKit.icon_rect(Items.icon(id), Vector2(28, 28)))
		price_row.add_child(MenuStyle.label("%s: compra $%d · venta $%d" % [item.get("name", id), int(item.get("price", 0)), sell], 17))
		price_row.tooltip_text = "Precio de referencia; puede variar un poco entre tiendas."
		prices.add_child(price_row)
	return row


## Gráfica de barras (verde ingreso, rojo gasto) de los últimos movimientos de dinero.
static func _money_chart(entries: Array) -> Control:
	var chart := Control.new()
	chart.custom_minimum_size = Vector2(0, 110)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.tooltip_text = "Verde: lo que ganaste. Rojo: lo que gastaste o perdiste."
	var ordered: Array = entries.duplicate()
	ordered.reverse()
	chart.draw.connect(func() -> void:
		var w := chart.size.x
		var h := chart.size.y
		var zero_y := h * 0.5
		chart.draw_line(Vector2(0, zero_y), Vector2(w, zero_y), Color(0, 0, 0, 0.18), 1.5)
		if ordered.is_empty():
			return
		var max_abs := 1.0
		for entry: Dictionary in ordered:
			max_abs = maxf(max_abs, absf(float(entry["amount"])))
		var count := ordered.size()
		var cell := w / maxf(float(count), 1.0)
		var bar_w := cell * 0.6
		for i in count:
			var amount := float((ordered[i] as Dictionary)["amount"])
			var bar_h := absf(amount) / max_abs * (h * 0.45)
			var x := cell * i + (cell - bar_w) * 0.5
			var color := Color(0.4, 0.78, 0.45) if amount >= 0 else Color(0.88, 0.35, 0.32)
			var y := zero_y - bar_h if amount >= 0 else zero_y
			var style := StyleBoxFlat.new()
			style.bg_color = color
			style.set_corner_radius_all(3)
			chart.draw_style_box(style, Rect2(x, y, maxf(bar_w, 2.0), maxf(bar_h, 2.0))))
	return chart


static func _thousands(value: int) -> String:
	var text := str(absi(value))
	var result := ""
	while text.length() > 3:
		result = "," + text.substr(text.length() - 3) + result
		text = text.substr(0, text.length() - 3)
	return ("-" if value < 0 else "") + text + result
