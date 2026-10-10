class_name TeamTab
extends RefCounted
## Sección Pokémon (estilo Z-A): arriba los 6 del equipo (retrato, vida y vínculo); abajo
## la ficha del elegido con encabezado blanco (nombre, tipos, vida), sus 4 movimientos en
## paralelogramos (toca uno para elegir el espacio y luego el nuevo de la lista), la
## gráfica de estadísticas en hexágono, los Puntos de Entrenamiento por repartir, la
## megaevolución y el botón para hacerlo tu acompañante.

const STAT_NAMES := ["PS", "Ataque", "Defensa", "At. Esp.", "Def. Esp.", "Velocidad"]
const STAT_KEYS := ["hp", "attack", "defense", "sp_attack", "sp_defense", "speed"]

## Tope de Puntos de Entrenamiento (como los EV): por estadística y en total.
const MAX_PER_STAT := 31
const MAX_TOTAL := 127

var _menu: GameMenu
## Espacio de movimiento elegido para cambiar (0-3).
var _slot := 0


static func _total(training: Dictionary) -> int:
	var total := 0
	for key: String in training:
		total += int(training[key])
	return total


func _init(menu: GameMenu) -> void:
	_menu = menu


func build() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	if GameState.party.is_empty():
		root.add_child(UiKit.label("Todavía no tienes Pokémon. ¡Elige a tu compañero lanzándole una Pokéball!", 24))
		return root
	_menu.selected_member = clampi(_menu.selected_member, 0, GameState.party.size() - 1)
	var row := _menu.party_row(func(i: int) -> void:
		_menu.selected_member = i
		_menu.show_tab(_menu.tab), _menu.selected_member)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(row)
	var detail := _detail(_menu.selected_member)
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(detail)
	return root


func _detail(index: int) -> Control:
	var entry: Dictionary = GameState.party[index]
	var species := MenuStyle.species(entry["species"])
	var shiny: bool = entry.get("shiny", false)
	var ratio := float(entry.get("hp_ratio", 1.0))
	var hp_max := int(20.0 + species.hp * 0.6)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	# Encabezado blanco.
	var header := PanelContainer.new()
	var header_style := UiKit.card_style(10)
	header_style.corner_radius_bottom_left = 0
	header_style.corner_radius_bottom_right = 0
	header_style.content_margin_left = 22
	header_style.content_margin_right = 22
	header.add_theme_stylebox_override("panel", header_style)
	box.add_child(header)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	header.add_child(head)
	head.add_child(UiKit.icon_rect(Items.icon(entry.get("ball", "poke-ball")), Vector2(30, 30)))
	var gender := int(entry.get("gender", -1))
	var name := UiKit.label("%s%s%s" % [species.display_name, " ♂" if gender == 0 else (" ♀" if gender == 1 else ""), "  ✦" if shiny else ""], 28, UiKit.INK, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(UiKit.label("Vínculo %d/10" % int(entry.get("bond", 1)), 20, Color(0.25, 0.35, 0.6), true))
	for t in species.types:
		head.add_child(UiKit.type_chip(t))
	# Cuerpo azul.
	var body := PanelContainer.new()
	var body_style := UiKit.panel_style(true, 10)
	body_style.corner_radius_top_left = 0
	body_style.corner_radius_top_right = 0
	body.add_theme_stylebox_override("panel", body_style)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	body.add_child(columns)
	# Columna 1: retrato, vida y acompañante.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size.x = 300
	columns.add_child(left)
	left.add_child(UiKit.icon_rect(MenuStyle.front_sprite(species, shiny), Vector2(260, 220)))
	var hp_row := HBoxContainer.new()
	hp_row.add_child(UiKit.bar(ratio, 200, UiKit.hp_color(ratio), 14))
	hp_row.add_child(UiKit.label("  %d/%d" % [int(hp_max * ratio), hp_max], 20, UiKit.WHITE, true))
	left.add_child(hp_row)
	left.add_child(UiKit.label("N.º %04d · %s" % [species.dex_id, DexData.genus(species.identifier)], 17, UiKit.MUTED))
	left.add_child(UiKit.label("Temperamento: %s" % MenuStyle.TEMPERAMENT_NAMES[species.temperament], 17, UiKit.MUTED))
	if index == GameState.companion_index:
		left.add_child(UiKit.label("★ Es tu acompañante", 20, UiKit.GOLD, true))
	else:
		var make := UiKit.slant_button("Hacer acompañante", UiKit.MINT)
		make.pressed.connect(func() -> void:
			if _menu.main != null and _menu.main.has_method("swap_companion"):
				_menu.main.swap_companion(index)
			_menu.show_tab(_menu.tab))
		left.add_child(make)
	# Columna 2: movimientos.
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 12)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(middle)
	_moves_section(middle, entry, index)
	# Columna 3: estadísticas, entrenamiento y megas.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	var radar := RadarChart.new()
	var training: Dictionary = entry.get("training", {})
	radar.set_species(species, training)
	right.add_child(radar)
	var free := int(entry.get("training_free", 0))
	right.add_child(UiKit.label("Entrenamiento %d/%d · por repartir: %d" % [_total(training), MAX_TOTAL, free], 18, UiKit.MINT if free > 0 else UiKit.MUTED, true))
	if free > 0:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		right.add_child(grid)
		for i in STAT_KEYS.size():
			var key: String = STAT_KEYS[i]
			var plus := MenuStyle.button("+1 %s" % STAT_NAMES[i], 15)
			plus.disabled = int(training.get(key, 0)) >= MAX_PER_STAT or _total(training) >= MAX_TOTAL
			plus.pressed.connect(func() -> void:
				var current: Dictionary = entry.get("training", {})
				current[key] = int(current.get(key, 0)) + 1
				entry["training"] = current
				entry["training_free"] = int(entry.get("training_free", 0)) - 1
				_menu.show_tab(_menu.tab))
			grid.add_child(plus)
	var megas := MegaCatalog.load_catalog().for_species(species.identifier)
	if not megas.is_empty():
		var names := PackedStringArray()
		for mega in megas:
			names.append("%s (%s)" % [mega.display_name, mega.stone if mega.stone != "" else "Ascenso del Dragón"])
		right.add_child(UiKit.wrapped("✦ Megaevolución: " + ", ".join(names), 16, Color(1.0, 0.7, 1.0)))
	return box


## Movimientos: los 4 que lleva en rombo (toca uno para elegir el espacio) y los
## desbloqueados para cambiarlo, con su tipo, clase, potencia y dominio.
func _moves_section(box: VBoxContainer, entry: Dictionary, index: int) -> void:
	Moves.ensure_entry(entry)
	box.add_child(UiKit.label("Movimientos", 22, UiKit.WHITE, true))
	var equipped: Array = entry["moves"]
	var diamond := VBoxContainer.new()
	diamond.add_theme_constant_override("separation", 8)
	box.add_child(diamond)
	var rows := [[0], [1, 2], [3]]
	for slots: Array in rows:
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", 10)
		diamond.add_child(line)
		for slot: int in slots:
			var id: String = equipped[slot] if slot < equipped.size() else ""
			var color: Color = AttackProjectile.TYPE_COLORS.get(int(Moves.get_move(id)["type"]), Color.GRAY) if id != "" else Color(1, 1, 1, 0.3)
			var button := UiKit.slant_button(Moves.get_move(id)["name"] if id != "" else "— vacío —", color, 19, slot == _slot)
			button.custom_minimum_size = Vector2(250, 48)
			button.icon = UiIcons.type_icon(int(Moves.get_move(id)["type"])) if id != "" else null
			button.tooltip_text = _move_text(entry, id) if id != "" else ""
			button.pressed.connect(func() -> void:
				_slot = slot
				_menu.show_tab(_menu.tab))
			line.add_child(button)
	var current: String = equipped[_slot] if _slot < equipped.size() else ""
	if current != "":
		box.add_child(UiKit.wrapped(_move_text(entry, current), 16, UiKit.MUTED))
	box.add_child(UiKit.label("Cambiar el espacio %d por:" % (_slot + 1), 18, UiKit.MINT, true))
	var unlocked: Array = entry.get("unlocked", [])
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 160
	box.add_child(scroll)
	var choices := HFlowContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("h_separation", 6)
	choices.add_theme_constant_override("v_separation", 6)
	scroll.add_child(choices)
	for id: String in unlocked:
		if equipped.has(id):
			continue
		var button := MenuStyle.button(Moves.get_move(id)["name"], 16)
		button.icon = UiIcons.type_icon(int(Moves.get_move(id)["type"]))
		button.tooltip_text = _move_text(entry, id)
		button.pressed.connect(func() -> void:
			var list: Array = entry["moves"]
			while list.size() <= _slot:
				list.append(id)
			list[_slot] = id
			if index == GameState.companion_index and _menu.main != null:
				var companion := _menu.main.get("companion") as PokemonActor
				if companion != null:
					companion.moves.assign(list)
			_menu.show_tab(_menu.tab))
		choices.add_child(button)
	var next := Moves.next_unlock(entry)
	var total := Moves.all_for(entry["species"]).size()
	box.add_child(UiKit.wrapped("Desbloqueados %d de %d · siguiente: %s (cada %d usos o con su investigación). En el mundo, %s-%s los usan; mantén %s para Fuerte o %s para Ágil." % [unlocked.size(), total,
			Moves.get_move(next)["name"] if next != "" else "ninguno", Moves.UNLOCK_EVERY, MoveInput.hint(0), MoveInput.hint(3), InputHints.hint("run"), InputHints.hint("dive")], 15, UiKit.MUTED))


func _move_text(entry: Dictionary, id: String) -> String:
	var move := Moves.get_move(id)
	var power := ("Pot. %d" % int(move["power"])) if int(move["power"]) > 0 else Moves.effect(id).replace("_", " ")
	return "%s · %s · %s · %s · rango %d" % [move["name"], Moves.type_name(id), Moves.class_name_es(id), power, Moves.rank(entry, id)]
