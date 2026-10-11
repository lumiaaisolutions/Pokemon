class_name BoxTab
extends RefCounted
## Sección Cajas (estilo Escarlata/Púrpura y Z-A): a la izquierda el Equipo (6) y la caja
## actual en cuadrícula de 6 × 5 (cajas de 30, se cambia con ◀ ▶); a la derecha la ficha
## del elegido (número, tipos, temperamento, vínculo y la gráfica de estadísticas) y las
## acciones: pasar al equipo o a la caja, intercambiar, hacerlo acompañante o liberarlo
## (pide confirmación).

const PER_BOX := 30
const COLUMNS := 6

## Selección actual: ["party" | "box", índice].
static var _selected := ["party", 0]
static var _page := 0
static var _confirm_release := false


static func build(menu: GameMenu) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	# Izquierda: equipo y caja.
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UiKit.panel_style(false))
	row.add_child(left)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	left.add_child(column)
	var team_title := UiKit.label("Equipo", 22, UiKit.WHITE, true)
	team_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(team_title)
	var team := HBoxContainer.new()
	team.add_theme_constant_override("separation", 8)
	column.add_child(team)
	for i in GameState.PARTY_MAX:
		if i < GameState.party.size():
			var card := UiKit.portrait_card(GameState.party[i], _selected == ["party", i], true)
			card.pressed.connect(func() -> void: _pick(menu, "party", i))
			team.add_child(card)
		else:
			team.add_child(UiKit.empty_slot(Vector2(96, 96)))
	var pages := maxi(1, int(ceil(GameState.box.size() / float(PER_BOX))) + (1 if GameState.box.size() % PER_BOX == 0 and GameState.box.size() > 0 else 0))
	_page = clampi(_page, 0, pages - 1)
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 18)
	column.add_child(bar)
	var prev := MenuStyle.button("◀", 18)
	prev.pressed.connect(func() -> void:
		_page = (_page - 1 + pages) % pages
		menu.show_tab(menu.tab))
	bar.add_child(prev)
	bar.add_child(UiKit.label("Caja %d · %d Pokémon guardados" % [_page + 1, GameState.box.size()], 22, UiKit.WHITE, true))
	var next := MenuStyle.button("▶", 18)
	next.pressed.connect(func() -> void:
		_page = (_page + 1) % pages
		menu.show_tab(menu.tab))
	bar.add_child(next)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	for slot in PER_BOX:
		var index := _page * PER_BOX + slot
		if index < GameState.box.size():
			var card := UiKit.portrait_card(GameState.box[index], _selected == ["box", index], true)
			card.pressed.connect(func() -> void: _pick(menu, "box", index))
			grid.add_child(card)
		else:
			grid.add_child(UiKit.empty_slot(Vector2(96, 96)))
	# Derecha: ficha y acciones.
	var detail := _detail(menu)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	return row


static func _pick(menu: GameMenu, source: String, index: int) -> void:
	_selected = [source, index]
	_confirm_release = false
	menu.show_tab(menu.tab)


static func _entry() -> Dictionary:
	var list: Array = GameState.party if _selected[0] == "party" else GameState.box
	var index: int = _selected[1]
	return list[index] if index >= 0 and index < list.size() else {}


static func _detail(menu: GameMenu) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var entry := _entry()
	if entry.is_empty():
		_selected = ["party", 0]
		entry = _entry()
	if entry.is_empty():
		box.add_child(UiKit.label("Elige un Pokémon.", 22))
		return box
	var species := MenuStyle.species(entry["species"])
	var header := PanelContainer.new()
	var header_style := UiKit.card_style(10)
	header_style.corner_radius_bottom_left = 0
	header_style.corner_radius_bottom_right = 0
	header_style.content_margin_left = 20
	header.add_theme_stylebox_override("panel", header_style)
	box.add_child(header)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	header.add_child(head)
	head.add_child(UiKit.icon_rect(Items.icon(entry.get("ball", "poke-ball")), Vector2(30, 30)))
	var gender := int(entry.get("gender", -1))
	var title := UiKit.label(species.display_name + (" ✦" if entry.get("shiny", false) else ""), 28, UiKit.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.label("♂" if gender == 0 else ("♀" if gender == 1 else ""), 28, Color(0.3, 0.5, 0.95) if gender == 0 else Color(0.95, 0.4, 0.6), true))
	var body := PanelContainer.new()
	var body_style := UiKit.panel_style(true, 10)
	body_style.corner_radius_top_left = 0
	body_style.corner_radius_top_right = 0
	body.add_theme_stylebox_override("panel", body_style)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	body.add_child(columns)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	info.custom_minimum_size.x = 300
	columns.add_child(info)
	info.add_child(UiKit.label("N.º %03d  %s" % [species.dex_id, species.display_name], 20, UiKit.WHITE, true))
	var types := HBoxContainer.new()
	for t in species.types:
		types.add_child(UiKit.type_chip(t))
	info.add_child(types)
	info.add_child(UiKit.icon_rect(MenuStyle.front_sprite(species, entry.get("shiny", false)), Vector2(200, 170)))
	for pair: Array in [["Temperamento", MenuStyle.TEMPERAMENT_NAMES[species.temperament]], ["Vínculo", "%d / 10" % int(entry.get("bond", 1))],
			["Entrenamiento", "%d / %d" % [TeamTab._total(entry.get("training", {})), TeamTab.MAX_TOTAL]], ["Ball", Items.display_name(entry.get("ball", "poke-ball"))]]:
		var section := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.08)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(8)
		section.add_theme_stylebox_override("panel", style)
		var line := VBoxContainer.new()
		section.add_child(line)
		line.add_child(UiKit.label(pair[0], 15, UiKit.MUTED, true))
		line.add_child(UiKit.label(str(pair[1]), 19, UiKit.WHITE))
		info.add_child(section)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var radar := RadarChart.new()
	radar.set_species(species, entry.get("training", {}))
	right.add_child(radar)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 10)
	right.add_child(actions)
	var source: String = _selected[0]
	var index: int = _selected[1]
	if source == "box":
		if GameState.party.size() < GameState.PARTY_MAX:
			var to_party := UiKit.slant_button("Al equipo", UiKit.MINT)
			to_party.tooltip_text = "Lo saca de la Caja y lo pone en tu equipo (hay %d/%d espacios)." % [GameState.party.size(), GameState.PARTY_MAX]
			to_party.pressed.connect(func() -> void:
				GameState.party.append(GameState.box.pop_at(index))
				_selected = ["party", GameState.party.size() - 1]
				menu.show_tab(menu.tab))
			actions.add_child(to_party)
		else:
			var swap := UiKit.slant_button("Cambiar por el %d.º del equipo" % (menu.selected_member + 1), UiKit.MINT)
			swap.tooltip_text = "Tu equipo ya tiene %d: este cambia de lugar con el elegido en la pestaña Equipo." % GameState.PARTY_MAX
			swap.disabled = menu.selected_member == GameState.companion_index
			swap.pressed.connect(func() -> void:
				var member := clampi(menu.selected_member, 0, GameState.party.size() - 1)
				var swapped: Dictionary = GameState.party[member]
				GameState.party[member] = GameState.box[index]
				GameState.box[index] = swapped
				menu.show_tab(menu.tab))
			actions.add_child(swap)
	else:
		menu.selected_member = index
		if GameState.party.size() > 1 and index != GameState.companion_index:
			var to_box := UiKit.slant_button("A la caja", Color(0.5, 0.7, 1.0))
			to_box.tooltip_text = "Lo guarda en la Caja (PC) y libera un espacio en tu equipo."
			to_box.pressed.connect(func() -> void:
				GameState.box.append(GameState.party.pop_at(index))
				if GameState.companion_index > index:
					GameState.companion_index -= 1
				_selected = ["box", GameState.box.size() - 1]
				menu.show_tab(menu.tab))
			actions.add_child(to_box)
		if index != GameState.companion_index:
			var make := UiKit.slant_button("Hacer acompañante", UiKit.GOLD)
			make.tooltip_text = "Te acompañará en el mundo y el combate (reemplaza al que tengas ahora)."
			make.pressed.connect(func() -> void:
				if menu.main != null and menu.main.has_method("swap_companion"):
					menu.main.swap_companion(index)
				menu.show_tab(menu.tab))
			actions.add_child(make)
	var can_release := source == "box" or (GameState.party.size() > 1 and index != GameState.companion_index)
	if can_release:
		var release := UiKit.slant_button("¿Seguro? Liberar" if _confirm_release else "Liberar", Color(1.0, 0.4, 0.4))
		release.tooltip_text = "Lo suelta en la naturaleza para siempre. Toca dos veces para confirmar."
		release.pressed.connect(func() -> void:
			if not _confirm_release:
				_confirm_release = true
				menu.show_tab(menu.tab)
				return
			_confirm_release = false
			var list: Array = GameState.party if source == "party" else GameState.box
			var freed: Dictionary = list.pop_at(index)
			if source == "party" and GameState.companion_index > index:
				GameState.companion_index -= 1
			GameState.notice.emit("%s volvió a la naturaleza. ¡Adiós!" % MenuStyle.species(freed["species"]).display_name)
			_selected = ["party", 0]
			menu.show_tab(menu.tab))
		actions.add_child(release)
	return box
