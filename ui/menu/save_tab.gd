class_name SaveTab
extends RefCounted
## Pestaña Guardar (nivel Dinero/Logros, pedido de Fernando el 2026-10-11): una tarjeta de
## partida por ranura (retrato, tiempo, medallas y región) con su botón de acción propio;
## abajo, el autoguardado en su propia tarjeta.


static func build(menu: GameMenu) -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 16)
	scroll.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	head.add_child(MenuIcon.make("Guardar", 44))
	var heading := UiKit.label("Tus 3 ranuras", 26, UiKit.INK, true)
	head.add_child(heading)
	box.add_child(UiKit.wrapped("Elige una ranura y guarda tu progreso ahí; sobrescribe lo que tenía. También hay autoguardado cada 5 minutos (ranura aparte, no se puede elegir a mano).", 17, UiKit.TEXT_SOFT))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	box.add_child(cards)
	for slot in range(1, SaveSystem.SLOTS + 1):
		var card := _slot_card(menu, slot)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.add_child(card)
	box.add_child(_auto_card())
	return scroll


## Tarjeta de una ranura: retrato (o hueco vacío), chips con ícono (tiempo, medallas,
## región, Pokédex) y el botón de acción (Guardar / Sobrescribir).
static func _slot_card(menu: GameMenu, slot: int) -> Control:
	var panel := PanelContainer.new()
	var info := SaveSystem.slot_info(slot)
	var empty := info.is_empty()
	panel.add_theme_stylebox_override("panel", UiKit.light_style(Color(0.3, 0.55, 0.85) if not empty else Color(0, 0, 0, 0.12), 20, 3))
	panel.tooltip_text = "Ranura %d: %s" % [slot, ("partida guardada el %s" % info.get("saved_at", "")) if not empty else "todavía no tiene partida"]
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size = Vector2(300, 0)
	panel.add_child(column)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	column.add_child(title_row)
	title_row.add_child(UiKit.icon_badge(Items.icon("poke-ball"), Color(0.3, 0.55, 0.85) if not empty else Color(0.6, 0.6, 0.62), 36))
	var title := UiKit.label("Ranura %d" % slot, 22, UiKit.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	if empty:
		column.add_child(UiKit.wrapped("Vacía: todavía no has guardado aquí.", 17, UiKit.TEXT_SOFT))
		var portrait_empty := UiKit.empty_slot(Vector2(0, 120))
		portrait_empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(portrait_empty)
	else:
		var portrait_row := HBoxContainer.new()
		portrait_row.add_theme_constant_override("separation", 10)
		column.add_child(portrait_row)
		var atlas := AtlasTexture.new()
		atlas.atlas = PlayerCharacters.sheet(info.get("character", ""))
		atlas.region = Rect2(0, 0, 32, 32)
		var portrait_panel := PanelContainer.new()
		var portrait_style := UiKit.panel_style(true, 12)
		portrait_style.bg_color = Color(0.85, 0.9, 1.0)
		portrait_panel.add_theme_stylebox_override("panel", portrait_style)
		portrait_panel.add_child(UiKit.icon_rect(atlas, Vector2(72, 72)))
		portrait_row.add_child(portrait_panel)
		var name_box := VBoxContainer.new()
		portrait_row.add_child(name_box)
		name_box.add_child(UiKit.label(String(info.get("name", "?")), 20, UiKit.INK, true))
		var companion := MenuStyle.species(info.get("companion", "")) if info.get("companion", "") != "" else null
		if companion != null:
			name_box.add_child(UiKit.label("Con %s" % companion.display_name, 15, UiKit.TEXT_SOFT))
		var minutes := int(float(info.get("play_time", 0.0)) / 60.0)
		column.add_child(_chip_row([
			["⏱", "%d h %02d min" % [minutes / 60, minutes % 60], "Tiempo jugado en esa partida"],
			["🎖", "%d / %d medallas" % [int(info.get("badges", 0)), Regions.GYMS], "Medallas de gimnasio en la región donde estaba"],
			["🗺", String(info.get("region", "—")), "Región donde estaba al guardar"],
			["📘", "%d capturados" % int(info.get("caught", 0)), "Especies capturadas en la Pokédex"],
			["$", "$%s" % _thousands(int(info.get("money", 0))), "Dinero en esa partida"],
		]))
		column.add_child(UiKit.label("Guardado el %s" % String(info.get("saved_at", "")), 14, UiKit.TEXT_SOFT))
	var save := UiKit.action_button("Sobrescribir" if not empty else "Guardar aquí", UiIcons.section("Guardar"), Color(0.75, 0.35, 0.3) if not empty else Color(0.3, 0.6, 0.4))
	save.tooltip_text = "Guarda tu progreso actual en la ranura %d%s." % [slot, " (borra lo que tenía)" if not empty else ""]
	save.pressed.connect(func() -> void:
		var ok := SaveSystem.save_slot(slot, menu.main)
		if ok:
			AudioBus.play_sfx("save")
		menu.show_tab(menu.tab)
		if menu.main != null:
			(menu.main.get_node("Hud") as Hud).show_toast("Partida guardada en la ranura %d." % slot if ok else "No se pudo guardar."))
	column.add_child(save)
	return panel


## Tarjeta del autoguardado (ranura 0): informativa, sin botón (no se guarda a mano ahí).
static func _auto_card() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.light_style(Color(0.8, 0.65, 0.25), 20, 3))
	panel.tooltip_text = "Se actualiza sola cada 5 minutos y al entrar a un Centro Pokémon; no se elige a mano."
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(UiKit.icon_badge(Items.icon("poke-ball"), Color(0.8, 0.65, 0.25), 40))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UiKit.label("Autoguardado", 20, UiKit.INK, true))
	var auto := SaveSystem.slot_info(0)
	text.add_child(UiKit.wrapped(_describe(auto) if not auto.is_empty() else "Todavía no hay autoguardado (se guarda solo cada 5 minutos o al entrar a un Centro Pokémon).", 17, UiKit.TEXT_SOFT))
	return panel


## Fila de chips con ícono/emoji, valor y una explicación en su tooltip (pedido de
## Fernando: "tooltips que expliquen cada cosa").
static func _chip_row(entries: Array) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	for entry: Array in entries:
		var chip := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.06) if UiKit.light else Color(1, 1, 1, 0.08)
		style.set_corner_radius_all(10)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", style)
		chip.tooltip_text = String(entry[2])
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		chip.add_child(line)
		line.add_child(UiKit.label(String(entry[0]), 16, UiKit.INK, true))
		line.add_child(UiKit.label(String(entry[1]), 16, UiKit.TEXT_SOFT, true))
		flow.add_child(chip)
	return flow


static func _describe(info: Dictionary) -> String:
	var minutes := int(float(info.get("play_time", 0.0)) / 60.0)
	var companion := MenuStyle.species(info.get("companion", "")) if info.get("companion", "") != "" else null
	return "%s · %d h %02d min · %d capturados%s · %s" % [info.get("name", "?"), minutes / 60, minutes % 60, int(info.get("caught", 0)),
			(" · con " + companion.display_name) if companion != null else "", info.get("saved_at", "")]


static func _thousands(value: int) -> String:
	var text := str(absi(value))
	var result := ""
	while text.length() > 3:
		result = "," + text.substr(text.length() - 3) + result
		text = text.substr(0, text.length() - 3)
	return ("-" if value < 0 else "") + text + result
