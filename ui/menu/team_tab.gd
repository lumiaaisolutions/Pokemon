class_name TeamTab
extends RefCounted
## Pestaña Equipo: lista del equipo y la ficha completa del elegido (sprite, tipos,
## temperamento, vida, estadísticas comprimidas, entrenamiento, vínculo y megas). Desde
## aquí se elige al acompañante.

const STAT_NAMES := ["PS", "Ataque", "Defensa", "At. Esp.", "Def. Esp.", "Velocidad"]
const STAT_KEYS := ["hp", "attack", "defense", "sp_attack", "sp_defense", "speed"]

## Tope de Puntos de Entrenamiento (como los EV): por estadística y en total.
const MAX_PER_STAT := 31
const MAX_TOTAL := 127

var _menu: GameMenu


static func _total(training: Dictionary) -> int:
	var total := 0
	for key: String in training:
		total += int(training[key])
	return total


func _init(menu: GameMenu) -> void:
	_menu = menu


func build() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	if GameState.party.is_empty():
		row.add_child(MenuStyle.label("Todavía no tienes Pokémon. ¡Elige a tu compañero lanzándole una Pokéball!", 24))
		return row
	_menu.selected_member = clampi(_menu.selected_member, 0, GameState.party.size() - 1)
	row.add_child(_detail(_menu.selected_member))
	return row


func _detail(index: int) -> Control:
	var entry: Dictionary = GameState.party[index]
	var species := MenuStyle.species(entry["species"])
	var shiny: bool = entry.get("shiny", false)
	var panel := MenuStyle.panel_container(MenuStyle.ACCENT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	panel.add_child(row)
	# Izquierda: sprite grande, nombre, tipos y acciones.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	left.add_child(MenuStyle.texture_rect(MenuStyle.front_sprite(species, shiny), Vector2(240, 240)))
	left.add_child(MenuStyle.label("%s%s" % [species.display_name, "  ✦ shiny" if shiny else ""], 30, MenuStyle.ACCENT))
	left.add_child(MenuStyle.label("N.º %04d · %s" % [species.dex_id, DexData.genus(species.identifier)], 18, MenuStyle.MUTED))
	var types := HBoxContainer.new()
	for t in species.types:
		types.add_child(MenuStyle.type_pill(t))
	left.add_child(types)
	left.add_child(MenuStyle.label("Temperamento: %s" % MenuStyle.TEMPERAMENT_NAMES[species.temperament], 18))
	if index == GameState.companion_index:
		left.add_child(MenuStyle.label("★ Es tu acompañante", 20, MenuStyle.ACCENT))
	else:
		var make := MenuStyle.button("Hacer acompañante", 20)
		make.pressed.connect(func() -> void:
			if _menu.main != null and _menu.main.has_method("swap_companion"):
				_menu.main.swap_companion(index)
			_menu.refresh_strip()
			_menu.show_tab(0))
		left.add_child(make)
	# Derecha: vida, estadísticas, crecimiento y megas.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var ratio := float(entry.get("hp_ratio", 1.0))
	right.add_child(MenuStyle.label("Vida", 22, MenuStyle.ACCENT))
	right.add_child(MenuStyle.bar(ratio, 420, Color(0.3, 0.85, 0.4) if ratio > 0.5 else (Color(0.95, 0.8, 0.2) if ratio > 0.2 else Color(0.9, 0.25, 0.2)), 16))
	right.add_child(MenuStyle.label("Estadísticas (base equilibrada + entrenamiento)", 22, MenuStyle.ACCENT))
	var training: Dictionary = entry.get("training", {})
	for i in STAT_KEYS.size():
		var base := int(species.get(STAT_KEYS[i]))
		var effective := MenuStyle.effective_stat(base) + float(training.get(STAT_KEYS[i], 0))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var name := MenuStyle.label(STAT_NAMES[i], 18)
		name.custom_minimum_size.x = 110
		line.add_child(name)
		line.add_child(MenuStyle.bar(effective / 150.0, 320, Color(0.45, 0.75, 1.0), 12))
		line.add_child(MenuStyle.label("%d  (base %d)" % [int(effective), base], 18, MenuStyle.MUTED))
		# Puntos sin repartir: +1 a la estadística (máx. 31 por estadística, 127 en total).
		var free := int(entry.get("training_free", 0))
		var key: String = STAT_KEYS[i]
		if free > 0 and int(training.get(key, 0)) < MAX_PER_STAT and _total(training) < MAX_TOTAL:
			var plus := MenuStyle.button("+1", 16)
			plus.pressed.connect(func() -> void:
				var current: Dictionary = entry.get("training", {})
				current[key] = int(current.get(key, 0)) + 1
				entry["training"] = current
				entry["training_free"] = int(entry.get("training_free", 0)) - 1
				_menu.show_tab(0))
			line.add_child(plus)
		right.add_child(line)
	var points := 0
	for key: String in training:
		points += int(training[key])
	right.add_child(MenuStyle.label("Puntos de Entrenamiento: %d / %d   ·   Por repartir: %d   ·   Vínculo: %d / 10" % [points, MAX_TOTAL, int(entry.get("training_free", 0)), int(entry.get("bond", 1))], 20))
	var megas := MegaCatalog.load_catalog().for_species(species.identifier)
	if not megas.is_empty():
		var names := PackedStringArray()
		for mega in megas:
			names.append("%s (con %s)" % [mega.display_name, mega.stone if mega.stone != "" else "Ascenso del Dragón"])
		right.add_child(MenuStyle.wrapped("Megaevolución: " + ", ".join(names), 18, Color(0.95, 0.6, 0.9)))
	right.add_child(MenuStyle.wrapped("Movimientos: hasta 4 de su lista oficial; se eligen cuando llegue el combate (Fase 3).", 17, MenuStyle.MUTED))
	right.add_child(MenuStyle.wrapped(DexData.flavor(species.identifier), 18))
	return panel
