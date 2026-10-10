class_name SaveTab
extends RefCounted
## Pestaña Guardar: 3 ranuras manuales con personaje, nombre, tiempo jugado, compañero y
## Pokédex; abajo, el autoguardado (cada 5 minutos).


static func build(menu: GameMenu) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.add_child(MenuStyle.label("Guardar la partida", 30, MenuStyle.ACCENT))
	for slot in range(1, SaveSystem.SLOTS + 1):
		box.add_child(_slot_row(menu, slot))
	box.add_child(MenuStyle.label("Autoguardado", 24, MenuStyle.ACCENT))
	var auto := SaveSystem.slot_info(0)
	box.add_child(MenuStyle.label(_describe(auto) if not auto.is_empty() else "Todavía no hay autoguardado (se guarda solo cada 5 minutos).", 20, MenuStyle.MUTED))
	return box


static func _slot_row(menu: GameMenu, slot: int) -> Control:
	var panel := MenuStyle.panel_container()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)
	var info := SaveSystem.slot_info(slot)
	if not info.is_empty() and info["character"] != "":
		var atlas := AtlasTexture.new()
		atlas.atlas = PlayerCharacters.sheet(info["character"])
		atlas.region = Rect2(0, 0, 32, 32)
		row.add_child(MenuStyle.texture_rect(atlas, Vector2(72, 72)))
	var text := MenuStyle.label("Ranura %d — %s" % [slot, _describe(info) if not info.is_empty() else "vacía"], 21)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var save := MenuStyle.button("Guardar aquí", 20)
	save.pressed.connect(func() -> void:
		var ok := SaveSystem.save_slot(slot, menu.main)
		if ok:
			AudioBus.play_sfx("save")
		menu.show_tab(menu.tab)
		if menu.main != null:
			(menu.main.get_node("Hud") as Hud).show_toast("Partida guardada en la ranura %d." % slot if ok else "No se pudo guardar."))
	row.add_child(save)
	return panel


static func _describe(info: Dictionary) -> String:
	var minutes := int(float(info.get("play_time", 0.0)) / 60.0)
	var companion := MenuStyle.species(info.get("companion", "")) if info.get("companion", "") != "" else null
	return "%s · %d h %02d min · %d capturados%s · %s" % [info.get("name", "?"), minutes / 60, minutes % 60, int(info.get("caught", 0)),
			(" · con " + companion.display_name) if companion != null else "", info.get("saved_at", "")]
