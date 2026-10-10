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
	_moves_section(right, entry, index)
	right.add_child(MenuStyle.wrapped(DexData.flavor(species.identifier), 18))
	return panel


## Movimientos: los 4 que lleva (toca uno para elegir el espacio) y los desbloqueados
## para cambiarlo. Muestra el dominio y qué falta para el siguiente.
func _moves_section(box: VBoxContainer, entry: Dictionary, index: int) -> void:
	Moves.ensure_entry(entry)
	box.add_child(MenuStyle.label("Movimientos (elige un espacio y luego el movimiento)", 22, MenuStyle.ACCENT))
	var equipped: Array = entry["moves"]
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	box.add_child(slots)
	for slot in 4:
		var id: String = equipped[slot] if slot < equipped.size() else ""
		var button := MenuStyle.button(_move_text(entry, id) if id != "" else "— vacío —", 16)
		button.custom_minimum_size = Vector2(260, 64)
		MenuStyle.style_button(button, slot == _slot)
		button.pressed.connect(func() -> void:
			_slot = slot
			_menu.show_tab(0))
		slots.add_child(button)
	var unlocked: Array = entry.get("unlocked", [])
	var choices := HFlowContainer.new()
	choices.add_theme_constant_override("h_separation", 6)
	choices.add_theme_constant_override("v_separation", 6)
	box.add_child(choices)
	for id: String in unlocked:
		if equipped.has(id):
			continue
		var button := MenuStyle.button(_move_text(entry, id), 15)
		button.pressed.connect(func() -> void:
			var list: Array = entry["moves"]
			while list.size() <= _slot:
				list.append(id)
			list[_slot] = id
			if index == GameState.companion_index and _menu.main != null:
				var companion := _menu.main.get("companion") as PokemonActor
				if companion != null:
					companion.moves.assign(list)
			_menu.show_tab(0))
		choices.add_child(button)
	var next := Moves.next_unlock(entry)
	var total := Moves.all_for(entry["species"]).size()
	box.add_child(MenuStyle.label("Desbloqueados %d de %d. Siguiente: %s (cada %d usos, o con la investigación de su especie)." % [unlocked.size(), total,
			Moves.get_move(next)["name"] if next != "" else "ninguno", Moves.UNLOCK_EVERY], 16, MenuStyle.MUTED))
	box.add_child(MenuStyle.label("En el mundo: %s-%s ordenan sus movimientos; mantén %s para Fuerte o %s para Ágil." % [MoveInput.hint(0), MoveInput.hint(3), InputHints.hint("run"), InputHints.hint("dive")], 16, MenuStyle.MUTED))


func _move_text(entry: Dictionary, id: String) -> String:
	var move := Moves.get_move(id)
	var power := ("Pot. %d" % int(move["power"])) if int(move["power"]) > 0 else Moves.effect(id).replace("_", " ")
	return "%s\n%s · %s · %s · rango %d" % [move["name"], Moves.type_name(id), Moves.class_name_es(id), power, Moves.rank(entry, id)]
