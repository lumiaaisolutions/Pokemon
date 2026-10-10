class_name DexTab
extends RefCounted
## Pestaña Pokédex (como en los juegos): lista nacional de 1,025 con número regional,
## filtros (tipo, estado, hábitat) y búsqueda; ficha con sprite (silueta si solo lo
## viste), categoría, descripción, altura y peso, tipos y debilidades, estadísticas,
## cadena evolutiva, formas (shiny, megas), sexos registrados, tarjeta de investigación,
## mapa de hábitat según el nivel de investigación, grito y comparación de tamaño.

const PAGE := 60
const HABITAT_NAMES := ["Pradera", "Bosque", "Montaña", "Agua dulce", "Mar", "Pantano"]
const STATUS_NAMES := ["Todos", "Vistos", "Capturados", "Sin ver", "Shiny", "Completados"]

var _menu: GameMenu
var _search := ""
var _type := -1
var _status := 0
var _habitat := -1
var _page := 0
var _selected := ""
var _show_shiny := false
var _cry_player: AudioStreamPlayer


func _init(menu: GameMenu) -> void:
	_menu = menu


func build() -> Control:
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 560
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)
	left.add_child(_filters())
	var list := _filtered()
	var seen := 0
	var caught := 0
	for species in DexData.all_species():
		seen += 1 if GameState.is_seen(species.identifier) else 0
		caught += 1 if GameState.is_caught(species.identifier) else 0
	left.add_child(MenuStyle.label("Vistos %d · Capturados %d · de 1,025   (%d en la lista)" % [seen, caught, list.size()], 17, MenuStyle.MUTED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 560)
	left.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	_page = clampi(_page, 0, maxi((list.size() - 1) / PAGE, 0))
	for i in range(_page * PAGE, mini((_page + 1) * PAGE, list.size())):
		rows.add_child(_row(list[i]))
	var pager := HBoxContainer.new()
	var previous := MenuStyle.button("◀ Anterior", 17)
	previous.disabled = _page == 0
	previous.pressed.connect(func() -> void:
		_page -= 1
		_menu.show_tab(_menu.tab))
	pager.add_child(previous)
	pager.add_child(MenuStyle.label("  Página %d de %d  " % [_page + 1, maxi((list.size() + PAGE - 1) / PAGE, 1)], 17))
	var next := MenuStyle.button("Siguiente ▶", 17)
	next.disabled = (_page + 1) * PAGE >= list.size()
	next.pressed.connect(func() -> void:
		_page += 1
		_menu.show_tab(_menu.tab))
	pager.add_child(next)
	left.add_child(pager)
	if _selected == "" and not list.is_empty():
		_selected = list[0].identifier
	var species := MenuStyle.species(_selected) if _selected != "" else null
	if species != null:
		root.add_child(_detail(species))
	return root


func _filters() -> Control:
	var box := VBoxContainer.new()
	var search := LineEdit.new()
	search.placeholder_text = "Buscar por nombre o número…"
	search.text = _search
	search.add_theme_font_size_override("font_size", 18)
	search.text_submitted.connect(func(text: String) -> void:
		_search = text.strip_edges().to_lower()
		_page = 0
		_menu.show_tab(_menu.tab))
	box.add_child(search)
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(_option(["Todos los tipos"] + MenuStyle.TYPE_NAMES, _type + 1, func(i: int) -> void: _type = i - 1))
	row.add_child(_option(STATUS_NAMES, _status, func(i: int) -> void: _status = i))
	row.add_child(_option(["Todo hábitat"] + HABITAT_NAMES, _habitat + 1, func(i: int) -> void: _habitat = i - 1))
	return box


func _option(names: Array, selected: int, setter: Callable) -> OptionButton:
	var option := OptionButton.new()
	for name: String in names:
		option.add_item(name)
	option.selected = selected
	option.add_theme_font_size_override("font_size", 16)
	option.item_selected.connect(func(i: int) -> void:
		setter.call(i)
		_page = 0
		_menu.show_tab(_menu.tab))
	return option


func _filtered() -> Array[SpeciesData]:
	var result: Array[SpeciesData] = []
	for species in DexData.all_species():
		var id := species.identifier
		var seen := GameState.is_seen(id)
		if _search != "":
			var matches := str(species.dex_id) == _search or (seen and species.display_name.to_lower().contains(_search))
			if not matches:
				continue
		if _type >= 0 and (not seen or not species.types.has(_type)):
			continue
		if _habitat >= 0 and (not seen or not species.habitats.has(_habitat)):
			continue
		match _status:
			1:
				if not seen:
					continue
			2:
				if not GameState.is_caught(id):
					continue
			3:
				if seen:
					continue
			4:
				if not GameState.dex.get(id, {}).get("shiny", false):
					continue
			5:
				if not Research.is_complete(id):
					continue
		result.append(species)
	return result


func _row(species: SpeciesData) -> Button:
	var id := species.identifier
	var seen := GameState.is_seen(id)
	var caught := GameState.is_caught(id)
	var button := Button.new()
	button.icon = MenuStyle.overworld_icon(species) if seen else null
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", 40)
	var marks := ("◓ " if caught else "   ") + ("✦" if GameState.dex.get(id, {}).get("shiny", false) else "")
	var research := "  Inv. %d" % Research.level(id) if seen else ""
	button.text = "%s  N.º %04d   %s%s" % [marks, species.dex_id, species.display_name if seen else "???", research]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 18)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuStyle.style_button(button, id == _selected)
	button.pressed.connect(func() -> void:
		_selected = id
		_show_shiny = false
		_menu.show_tab(_menu.tab)
		_play_cry(species))
	return button


func _detail(species: SpeciesData) -> Control:
	var id := species.identifier
	var seen := GameState.is_seen(id)
	var caught := GameState.is_caught(id)
	var entry: Dictionary = GameState.dex.get(id, {})
	var panel := MenuStyle.panel_container(MenuStyle.ACCENT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 680)
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	box.add_child(head)
	var sprite := MenuStyle.texture_rect(MenuStyle.front_sprite(species, _show_shiny), Vector2(200, 200))
	if not seen:
		sprite.modulate = Color(0, 0, 0, 0.85)
	head.add_child(sprite)
	var titles := VBoxContainer.new()
	head.add_child(titles)
	titles.add_child(MenuStyle.label("N.º %04d  ·  Regional %03d" % [species.dex_id, regional_number(species)], 18, MenuStyle.MUTED))
	titles.add_child(MenuStyle.label(species.display_name if seen else "???", 34, MenuStyle.ACCENT))
	if not seen:
		titles.add_child(MenuStyle.wrapped("Todavía no lo has visto. Explora sus zonas para registrarlo.", 18))
		return panel
	titles.add_child(MenuStyle.label(DexData.genus(id), 20))
	var types := HBoxContainer.new()
	for t in species.types:
		types.add_child(MenuStyle.type_pill(t))
	titles.add_child(types)
	titles.add_child(MenuStyle.label("Altura %.1f m  ·  Peso %.1f kg" % [DexData.height(id), DexData.weight(id)], 18))
	var buttons := HBoxContainer.new()
	titles.add_child(buttons)
	var cry := MenuStyle.button("▶ Grito", 17)
	cry.pressed.connect(func() -> void: _play_cry(species))
	buttons.add_child(cry)
	if caught or entry.get("shiny_seen", false):
		var shiny := MenuStyle.button("Ver normal" if _show_shiny else "Ver shiny ✦", 17)
		shiny.pressed.connect(func() -> void:
			_show_shiny = not _show_shiny
			_menu.show_tab(_menu.tab))
		buttons.add_child(shiny)
	box.add_child(MenuStyle.wrapped(DexData.flavor(id) if caught else "Captúralo para completar su descripción.", 19))
	if caught:
		_weaknesses(box, species)
		_stats(box, species)
		_evolution(box, species)
		_forms(box, species, entry)
		_size(box, species, entry)
	_research(box, id)
	_habitat_map(box, species)
	return panel


func _weaknesses(box: VBoxContainer, species: SpeciesData) -> void:
	var row := HBoxContainer.new()
	row.add_child(MenuStyle.label("Débil contra: ", 18))
	for t in 18:
		if TypeChart.effectiveness(t, species.types) > 1.0:
			row.add_child(MenuStyle.type_pill(t))
	box.add_child(row)


func _stats(box: VBoxContainer, species: SpeciesData) -> void:
	box.add_child(MenuStyle.label("Estadísticas base (total %d)" % species.base_total, 20, MenuStyle.ACCENT))
	for i in TeamTab.STAT_KEYS.size():
		var value := int(species.get(TeamTab.STAT_KEYS[i]))
		var line := HBoxContainer.new()
		var name := MenuStyle.label(TeamTab.STAT_NAMES[i], 17)
		name.custom_minimum_size.x = 110
		line.add_child(name)
		line.add_child(MenuStyle.bar(value / 200.0, 300, Color(0.45, 0.75, 1.0), 10))
		line.add_child(MenuStyle.label(" %d" % value, 17, MenuStyle.MUTED))
		box.add_child(line)


func _evolution(box: VBoxContainer, species: SpeciesData) -> void:
	var chain: Array[SpeciesData] = []
	for other in DexData.all_species():
		if other.evolution_chain == species.evolution_chain:
			chain.append(other)
	if chain.size() < 2:
		return
	chain.sort_custom(func(a: SpeciesData, b: SpeciesData) -> bool: return a.evolution_stage < b.evolution_stage)
	box.add_child(MenuStyle.label("Cadena evolutiva (se desbloquea con misiones, sin niveles)", 20, MenuStyle.ACCENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for member in chain:
		var seen := GameState.is_seen(member.identifier)
		var icon := MenuStyle.texture_rect(MenuStyle.front_sprite(member), Vector2(80, 80))
		if not seen:
			icon.modulate = Color(0, 0, 0, 0.8)
		var column := VBoxContainer.new()
		column.add_child(icon)
		column.add_child(MenuStyle.label(member.display_name if seen else "???", 15))
		row.add_child(column)
	box.add_child(row)


func _forms(box: VBoxContainer, species: SpeciesData, entry: Dictionary) -> void:
	var parts := PackedStringArray()
	parts.append("♂ %d · ♀ %d capturados" % [int(entry.get("male", 0)), int(entry.get("female", 0))] if int(DexData.info(species.identifier).get("gender_rate", -1)) >= 0 else "Sin sexo")
	parts.append("Shiny: %s" % ("capturado ✦" if entry.get("shiny", false) else ("visto" if entry.get("shiny_seen", false) else "no visto")))
	box.add_child(MenuStyle.label("Formas: " + "   ·   ".join(parts), 18))
	var megas := MegaCatalog.load_catalog().for_species(species.identifier)
	if megas.is_empty():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for mega in megas:
		var column := VBoxContainer.new()
		if mega.front != null:
			column.add_child(MenuStyle.texture_rect(mega.front, Vector2(96, 96)))
		column.add_child(MenuStyle.label(mega.display_name, 15, Color(0.95, 0.6, 0.9)))
		row.add_child(column)
	box.add_child(row)


## Tu personaje junto al Pokémon a escala, con los récords de tamaño capturados.
func _size(box: VBoxContainer, species: SpeciesData, entry: Dictionary) -> void:
	box.add_child(MenuStyle.label("Comparar tamaño", 20, MenuStyle.ACCENT))
	var height := maxf(DexData.height(species.identifier), 0.1)
	var player_height := 1.5
	var scale := 180.0 / maxf(height, player_height)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 30)
	row.custom_minimum_size.y = 190
	var trainer := AtlasTexture.new()
	trainer.atlas = PlayerCharacters.sheet(GameState.character_id)
	trainer.region = Rect2(0, 0, 32, 32)
	var you := MenuStyle.texture_rect(trainer, Vector2(player_height * scale, player_height * scale))
	you.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(you)
	var mon := MenuStyle.texture_rect(MenuStyle.front_sprite(species), Vector2(height * scale * 1.4, height * scale * 1.4))
	mon.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(mon)
	box.add_child(row)
	box.add_child(MenuStyle.label("%s %.1f m · %s %.2f m · récord grande %.2f m · récord pequeño %.2f m" % [GameState.player_name, player_height, species.display_name, height, float(entry.get("biggest", 0.0)), float(entry.get("smallest", 0.0))], 16, MenuStyle.MUTED))


func _research(box: VBoxContainer, id: String) -> void:
	var points := Research.points(id)
	box.add_child(MenuStyle.label("Investigación: nivel %d%s (%d puntos)" % [Research.level(id), "  ★ completada" if Research.is_complete(id) else "", points], 20, MenuStyle.ACCENT))
	box.add_child(MenuStyle.bar(points / float(Research.COMPLETE_POINTS), 420, Color(0.95, 0.75, 0.25), 10))
	for task: Array in Research.TASKS:
		var value := int(GameState.dex.get(id, {}).get(task[0], 0))
		var goal := Research.next_goal(id, task)
		box.add_child(MenuStyle.label("• %s: %d%s" % [task[1], value, (" / %d" % goal) if goal > 0 else "  ✔"], 17))


## Mapa del hábitat según la investigación: visto = zona aproximada; capturado = zonas
## exactas; completado = además horario, clima y si es nómada.
func _habitat_map(box: VBoxContainer, species: SpeciesData) -> void:
	box.add_child(MenuStyle.label("Hábitat", 20, MenuStyle.ACCENT))
	var spawner := _menu.main.get_node_or_null("Spawner") as WildSpawner if _menu.main != null else null
	var map_ui := _menu.main.get_node_or_null("MapUi") as MapUi if _menu.main != null else null
	if map_ui != null:
		map_ui.data.wait()
	if spawner == null or map_ui == null or map_ui.data.map_texture == null:
		box.add_child(MenuStyle.label("Mapa no disponible.", 17, MenuStyle.MUTED))
		return
	var id := species.identifier
	var areas := spawner.home_areas(id)
	var caught := GameState.is_caught(id)
	var image := map_ui.data.map_texture.get_image()
	image.convert(Image.FORMAT_RGBA8)
	var size_m := map_ui.data.size_m
	var to_px := image.get_width() / size_m
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	for area in areas:
		var center := Vector2(area.x, area.y)
		var radius := area.z
		if not caught:
			# Aproximada: más grande y corrida.
			center += Vector2(rng.randf_range(-25, 25), rng.randf_range(-25, 25))
			radius *= 2.0
		_disc(image, (center + Vector2(size_m, size_m) * 0.5) * to_px, radius * to_px, Color(1.0, 0.3, 0.35, 0.55 if caught else 0.3))
	var map := MenuStyle.texture_rect(ImageTexture.create_from_image(image), Vector2(360, 360))
	box.add_child(map)
	if areas.is_empty():
		box.add_child(MenuStyle.label("No tiene zonas propias: aparece de vez en cuando por su hábitat.", 17, MenuStyle.MUTED))
	elif not caught:
		box.add_child(MenuStyle.label("Zona aproximada. Captúralo para ver dónde vive exactamente.", 17, MenuStyle.MUTED))
	if Research.is_complete(id):
		var night := species.types.has(PokemonTypes.Type.GHOST) or species.types.has(PokemonTypes.Type.DARK)
		box.add_child(MenuStyle.label("Horario: %s  ·  Clima: cualquiera%s" % ["más de noche" if night else "día y noche", "  ·  Nómada: cambia de zona cada día" if spawner.is_nomad(id) else ""], 17))
	else:
		box.add_child(MenuStyle.label("Completa su investigación para ver su horario y clima.", 16, MenuStyle.MUTED))


func _disc(image: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(maxi(int(center.y - radius), 0), mini(int(center.y + radius) + 1, image.get_height())):
		for x in range(maxi(int(center.x - radius), 0), mini(int(center.x + radius) + 1, image.get_width())):
			if Vector2(x, y).distance_to(center) <= radius:
				image.set_pixel(x, y, image.get_pixel(x, y).blend(color))


## Número regional: orden de la Pokédex de tu región (especies con zonas, por hábitat).
func regional_number(species: SpeciesData) -> int:
	return (species.habitats[0] if not species.habitats.is_empty() else 0) * 200 + species.dex_id % 200


func _play_cry(species: SpeciesData) -> void:
	var stream := DexData.cry(species)
	if stream == null:
		return
	if _cry_player == null or not is_instance_valid(_cry_player):
		_cry_player = AudioStreamPlayer.new()
		_cry_player.process_mode = Node.PROCESS_MODE_ALWAYS
		_menu.add_child(_cry_player)
	_cry_player.stream = stream
	_cry_player.volume_db = linear_to_db(maxf(GameOptions.cries_volume, 0.001))
	_cry_player.play()
