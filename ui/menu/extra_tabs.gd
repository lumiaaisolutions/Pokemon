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


## Logros (medallas por hitos) y estadísticas de la partida.
static func achievements() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var left := MenuStyle.panel_container(MenuStyle.ACCENT)
	left.custom_minimum_size.x = 900
	row.add_child(left)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	left.add_child(list)
	list.add_child(MenuStyle.label("Logros · %d de %d" % [GameState.achievements.size(), Achievements.LIST.size()], 26, MenuStyle.ACCENT))
	for entry: Array in Achievements.LIST:
		var unlocked := GameState.achievements.has(entry[0])
		var value := float(GameState.stats.get(entry[3], 0.0))
		var text := "%s %s — %s" % ["🏅" if unlocked else "○", entry[1], entry[2]]
		if not unlocked:
			text += "  (%s / %s)" % [_number(value, entry[3]), _number(float(entry[4]), entry[3])]
		list.add_child(MenuStyle.label(text, 18, MenuStyle.TEXT if unlocked else MenuStyle.MUTED))
	var right := MenuStyle.panel_container()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var stats := VBoxContainer.new()
	right.add_child(stats)
	stats.add_child(MenuStyle.label("Estadísticas", 26, MenuStyle.ACCENT))
	var names := {"distance": "Recorrido", "captures": "Capturas", "shinies": "Shinies capturados", "behind": "Capturas por la espalda",
			"defeated": "Salvajes debilitados por tu compañero", "gathered": "Objetos recogidos", "activities": "Actividades cumplidas",
			"blackouts": "Desmayos (Centro Pokémon)", "recoveries": "Recuperaciones en el campo"}
	for key: String in names:
		stats.add_child(MenuStyle.label("%s: %s" % [names[key], _number(float(GameState.stats.get(key, 0.0)), key)], 18))
	var minutes := int(GameState.play_time / 60.0)
	stats.add_child(MenuStyle.label("Tiempo jugado: %d h %02d min · Día del juego %d" % [minutes / 60, minutes % 60, GameState.game_day() + 1], 18))
	return row


static func _number(value: float, key: String) -> String:
	if key == "distance":
		return "%.1f km" % (value / 1000.0) if value >= 1000.0 else "%d m" % int(value)
	return str(int(value))


## Dinero: saldo, movimientos recientes y precios de referencia para las tiendas.
static func money() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var left := MenuStyle.panel_container(MenuStyle.ACCENT)
	left.custom_minimum_size.x = 760
	row.add_child(left)
	var box := VBoxContainer.new()
	left.add_child(box)
	box.add_child(MenuStyle.label("Dinero: $%d" % GameState.money, 30, MenuStyle.ACCENT))
	box.add_child(MenuStyle.label("Movimientos recientes", 22, MenuStyle.ACCENT))
	if GameState.money_log.is_empty():
		box.add_child(MenuStyle.label("Sin movimientos todavía.", 18, MenuStyle.MUTED))
	for entry: Dictionary in GameState.money_log.slice(0, 14):
		var amount := int(entry["amount"])
		box.add_child(MenuStyle.label("Día %d · %s$%d · %s" % [int(entry["day"]), "+" if amount >= 0 else "−", absi(amount), entry["reason"]], 17,
				Color(0.6, 1.0, 0.7) if amount >= 0 else Color(1.0, 0.6, 0.6)))
	var right := MenuStyle.panel_container()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var prices := VBoxContainer.new()
	right.add_child(prices)
	prices.add_child(MenuStyle.label("Precios de referencia (tiendas de los pueblos)", 22, MenuStyle.ACCENT))
	for id in ["poke-ball", "great-ball", "ultra-ball", "potion", "super-potion", "repel", "escape-rope", "nugget", "pearl", "star-piece"]:
		var item := Items.get_item(id)
		var sell := int(item.get("sell", int(item.get("price", 0)) / 2))
		prices.add_child(MenuStyle.label("%s: compra $%d · venta $%d" % [item.get("name", id), int(item.get("price", 0)), sell], 17))
	return row
