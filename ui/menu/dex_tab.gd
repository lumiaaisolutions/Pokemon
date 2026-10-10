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


## Vista: "grid" (cuadrícula estilo Pokopia) o "detail" (ficha de una especie).
var _view := "grid"
var _sort := 0
const SORT_NAMES := ["Orden numérico", "Por nombre", "Por tipo"]
const GRID_PAGE := 48


func build() -> Control:
	if _view == "detail" and _selected != "" and MenuStyle.species(_selected) != null:
		return _detail_page(MenuStyle.species(_selected))
	return _grid_page()


## Cuadrícula: capturados a color, vistos en silueta gris y los no vistos solo con su
## número (no aparecen). Al enfocar: círculo amarillo y burbuja con el nombre.
func _grid_page() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	var list := _filtered()
	match _sort:
		1:
			list.sort_custom(func(a: SpeciesData, b: SpeciesData) -> bool: return _sort_name(a) < _sort_name(b))
		2:
			list.sort_custom(func(a: SpeciesData, b: SpeciesData) -> bool: return _sort_type(a) < _sort_type(b))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Margen arriba para que quepa la burbuja del nombre de la primera fila.
	var top_space := MarginContainer.new()
	top_space.add_theme_constant_override("margin_top", 34)
	top_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_space.add_child(center)
	scroll.add_child(top_space)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 18)
	center.add_child(grid)
	_page = clampi(_page, 0, maxi((list.size() - 1) / GRID_PAGE, 0))
	var first: Button = null
	for i in range(_page * GRID_PAGE, mini((_page + 1) * GRID_PAGE, list.size())):
		var tile := _tile(list[i])
		grid.add_child(tile)
		if first == null or list[i].identifier == _selected:
			first = tile
	if first != null:
		first.grab_focus.call_deferred()
	# Barra de abajo: contador, filtro, orden y páginas.
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	root.add_child(bar)
	var seen := 0
	var caught := 0
	for species in DexData.all_species():
		seen += 1 if GameState.is_seen(species.identifier) else 0
		caught += 1 if GameState.is_caught(species.identifier) else 0
	var counter := PanelContainer.new()
	counter.add_theme_stylebox_override("panel", UiKit.light_style(UiKit.RED, 16, 2))
	var counter_box := HBoxContainer.new()
	counter_box.add_theme_constant_override("separation", 18)
	counter.add_child(counter_box)
	counter_box.add_child(UiKit.label("Vistos  %d" % seen, 19, UiKit.TEXT, true))
	counter_box.add_child(UiKit.label("Capturados  %d" % caught, 19, UiKit.RED_DARK, true))
	bar.add_child(counter)
	var search := LineEdit.new()
	search.placeholder_text = "🔍  Buscar nombre o número"
	search.text = _search
	search.custom_minimum_size.x = 280
	search.add_theme_font_size_override("font_size", 18)
	search.text_submitted.connect(func(text: String) -> void:
		_search = text.strip_edges().to_lower()
		_page = 0
		_menu.show_tab(_menu.tab))
	bar.add_child(search)
	bar.add_child(_option(["Todos los tipos"] + MenuStyle.TYPE_NAMES, _type + 1, func(i: int) -> void: _type = i - 1))
	bar.add_child(_option(STATUS_NAMES, _status, func(i: int) -> void: _status = i))
	bar.add_child(_option(SORT_NAMES, _sort, func(i: int) -> void: _sort = i))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var previous := MenuStyle.button("◀", 18)
	previous.disabled = _page == 0
	previous.pressed.connect(func() -> void:
		_page -= 1
		_menu.show_tab(_menu.tab))
	bar.add_child(previous)
	bar.add_child(UiKit.label("%d / %d" % [_page + 1, maxi((list.size() + GRID_PAGE - 1) / GRID_PAGE, 1)], 18, UiKit.TEXT, true))
	var next := MenuStyle.button("▶", 18)
	next.disabled = (_page + 1) * GRID_PAGE >= list.size()
	next.pressed.connect(func() -> void:
		_page += 1
		_menu.show_tab(_menu.tab))
	bar.add_child(next)
	return root


func _sort_name(species: SpeciesData) -> String:
	return species.display_name.to_lower() if GameState.is_seen(species.identifier) else "~%04d" % species.dex_id


func _sort_type(species: SpeciesData) -> String:
	return ("%02d" % species.types[0]) + ("%04d" % species.dex_id) if GameState.is_seen(species.identifier) and not species.types.is_empty() else "99%04d" % species.dex_id


func _tile(species: SpeciesData) -> Button:
	var id := species.identifier
	var seen := GameState.is_seen(id)
	var caught := GameState.is_caught(id)
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(104, 104)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0.06) if seen else Color(0, 0, 0, 0.025)
	normal.set_corner_radius_all(52)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(1.0, 0.85, 0.25)
	focus.shadow_color = Color(0, 0, 0, 0.15)
	focus.shadow_size = 6
	tile.add_theme_stylebox_override("normal", normal)
	tile.add_theme_stylebox_override("hover", focus)
	tile.add_theme_stylebox_override("focus", focus)
	tile.add_theme_stylebox_override("pressed", focus)
	if seen:
		var sprite := UiKit.icon_rect(MenuStyle.front_sprite(species), Vector2(88, 88))
		sprite.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		sprite.offset_left = -44
		sprite.offset_right = 44
		sprite.offset_top = -44
		sprite.offset_bottom = 44
		# Visto pero no capturado: silueta gris.
		if not caught:
			sprite.modulate = Color(0.0, 0.0, 0.05, 0.42)
		tile.add_child(sprite)
		if GameState.dex.get(id, {}).get("shiny", false):
			var star := UiKit.label("✦", 18, Color(0.95, 0.65, 0.1), true)
			star.position = Vector2(78, 2)
			tile.add_child(star)
	else:
		# No visto: solo su número, tenue.
		var number := UiKit.label("%03d" % species.dex_id, 17, Color(0, 0, 0, 0.25), true)
		number.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		number.grow_horizontal = Control.GROW_DIRECTION_BOTH
		number.grow_vertical = Control.GROW_DIRECTION_BOTH
		tile.add_child(number)
	# Burbuja con el nombre (aparece con el foco).
	var bubble := PanelContainer.new()
	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color(1, 1, 1)
	bubble_style.border_color = Color(1.0, 0.75, 0.2)
	bubble_style.set_border_width_all(3)
	bubble_style.set_corner_radius_all(14)
	bubble_style.content_margin_left = 12
	bubble_style.content_margin_right = 12
	bubble_style.content_margin_top = 2
	bubble_style.content_margin_bottom = 4
	bubble.add_theme_stylebox_override("panel", bubble_style)
	bubble.add_child(UiKit.label(species.display_name if seen else "N.º %04d" % species.dex_id, 16, UiKit.TEXT, true))
	bubble.position = Vector2(0, -26)
	bubble.visible = false
	bubble.z_index = 5
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(bubble)
	tile.focus_entered.connect(func() -> void:
		bubble.visible = true
		bubble.reset_size()
		bubble.position = Vector2((104 - bubble.size.x) * 0.5, -bubble.size.y + 4)
		_selected = id)
	tile.focus_exited.connect(func() -> void: bubble.visible = false)
	tile.mouse_entered.connect(tile.grab_focus)
	tile.pressed.connect(func() -> void:
		AudioBus.play_sfx("ui_decide")
		_selected = id
		if seen:
			_view = "detail"
			_show_shiny = false
			_menu.show_tab(_menu.tab)
			_play_cry(species))
	return tile


## Ficha de una especie a pantalla completa, con botón para volver a la cuadrícula.
func _detail_page(species: SpeciesData) -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	var back := MenuStyle.button("◀  Volver a la Pokédex", 18)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func() -> void:
		_view = "grid"
		_menu.show_tab(_menu.tab))
	root.add_child(back)
	var detail := _detail(species)
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(detail)
	back.grab_focus.call_deferred()
	return root


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


func _detail(species: SpeciesData) -> Control:
	var id := species.identifier
	var seen := GameState.is_seen(id)
	var caught := GameState.is_caught(id)
	var entry: Dictionary = GameState.dex.get(id, {})
	var panel := MenuStyle.panel_container(MenuStyle.ACCENT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 600)
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
	var regional := regional_number(species)
	titles.add_child(MenuStyle.label("N.º %04d  ·  Regional %s" % [species.dex_id, ("%03d" % regional) if regional > 0 else "—"], 18, MenuStyle.MUTED))
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


## Número regional (ver WildSpawner.regional_number): por cercanía al pueblo inicial.
func regional_number(species: SpeciesData) -> int:
	var spawner := _menu.main.get_node_or_null("Spawner") as WildSpawner if _menu.main != null else null
	return spawner.regional_number(species.identifier) if spawner != null else 0


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
