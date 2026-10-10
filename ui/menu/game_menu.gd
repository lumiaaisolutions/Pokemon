class_name GameMenu
extends Control
## Menú del juego (Esc / Options), estilo Leyendas Arceus con ventanas B2W2: pausa el
## juego, muestra arriba las pestañas y siempre la tira del equipo (acceso rápido a la
## ficha de cada Pokémon). Pestañas: Equipo, Mochila, Pokédex, Ficha, Mapa, Controles,
## Opciones y Guardar. Se cambia de pestaña con Q / E o L1 / R1.

const TABS := ["Equipo", "Mochila", "Pokédex", "Ficha", "Mapa", "Controles", "Opciones", "Guardar"]

## Escena principal (compañero, cambio de acompañante, mapa).
var main: Node
var tab := 0
## Miembro del equipo que se muestra en la pestaña Equipo.
var selected_member := 0
var _tab_bar: HBoxContainer
var _strip: HBoxContainer
var _content: Control
var _footer: Label
var _team_tab: TeamTab
var _bag_tab: BagTab
var _dex_tab: DexTab


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.06, 0.1, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 40
	layout.offset_right = -40
	layout.offset_top = 24
	layout.offset_bottom = -20
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	layout.add_child(top)
	top.add_child(InputGlyph.make("menu_prev"))
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 6)
	top.add_child(_tab_bar)
	top.add_child(InputGlyph.make("menu_next"))
	for i in TABS.size():
		var button := MenuStyle.button(TABS[i], 22)
		button.pressed.connect(show_tab.bind(i))
		_tab_bar.add_child(button)
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 10)
	layout.add_child(_strip)
	_content = MarginContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_content)
	_footer = MenuStyle.label("", 17, MenuStyle.MUTED)
	layout.add_child(_footer)
	_team_tab = TeamTab.new(self)
	_bag_tab = BagTab.new(self)
	_dex_tab = DexTab.new(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") and not _other_overlay_open():
		get_viewport().set_input_as_handled()
		close() if visible else open()
		return
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("menu_prev"):
		get_viewport().set_input_as_handled()
		show_tab((tab - 1 + TABS.size()) % TABS.size())
	elif event.is_action_pressed("menu_next"):
		get_viewport().set_input_as_handled()
		show_tab((tab + 1) % TABS.size())


## La Ayuda o el mapa completo ya pausan el juego: el menú no se abre encima.
func _other_overlay_open() -> bool:
	return get_tree().paused and not visible


func open() -> void:
	if main != null and main.has_method("sync_companion_to_party"):
		main.sync_companion_to_party()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_strip()
	show_tab(tab)


func close() -> void:
	visible = false
	get_tree().paused = false


func show_tab(index: int) -> void:
	tab = index
	for i in _tab_bar.get_child_count():
		MenuStyle.style_button(_tab_bar.get_child(i) as Button, i == tab)
	for child in _content.get_children():
		child.queue_free()
	var page: Control
	match TABS[tab]:
		"Equipo":
			page = _team_tab.build()
		"Mochila":
			page = _bag_tab.build()
		"Pokédex":
			page = _dex_tab.build()
		"Ficha":
			page = _trainer_card()
		"Mapa":
			page = _map_page()
		"Controles":
			page = HelpOverlay.build_content()
		"Opciones":
			page = OptionsTab.build()
		"Guardar":
			page = SaveTab.build(self)
	_content.add_child(page)
	_footer.text = "%s / %s Cambiar de pestaña   ·   %s Cerrar" % [InputHints.hint("menu_prev"), InputHints.hint("menu_next"), InputHints.hint("menu")]


## Tira del equipo: siempre visible arriba; tocar un Pokémon abre su ficha.
func refresh_strip() -> void:
	for child in _strip.get_children():
		child.queue_free()
	for i in GameState.PARTY_MAX:
		var card := Button.new()
		card.custom_minimum_size = Vector2(250, 92)
		MenuStyle.style_button(card, i == GameState.companion_index and i < GameState.party.size())
		_strip.add_child(card)
		if i >= GameState.party.size():
			card.disabled = true
			card.text = "—"
			continue
		var entry: Dictionary = GameState.party[i]
		var species := MenuStyle.species(entry["species"])
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		var icon := MenuStyle.texture_rect(MenuStyle.front_sprite(species, entry.get("shiny", false)), Vector2(72, 72))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(info)
		var star := "★ " if i == GameState.companion_index else ""
		var title := MenuStyle.label(star + species.display_name + (" ✦" if entry.get("shiny", false) else ""), 18)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(title)
		var ratio := float(entry.get("hp_ratio", 1.0))
		info.add_child(MenuStyle.bar(ratio, 110, Color(0.3, 0.85, 0.4) if ratio > 0.5 else (Color(0.95, 0.8, 0.2) if ratio > 0.2 else Color(0.9, 0.25, 0.2)), 8))
		var types := HBoxContainer.new()
		types.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for t in species.types:
			types.add_child(MenuStyle.type_pill(t))
		info.add_child(types)
		card.pressed.connect(func() -> void:
			selected_member = i
			show_tab(0))


func _trainer_card() -> Control:
	var box := MenuStyle.panel_container(MenuStyle.ACCENT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	box.add_child(row)
	var atlas := AtlasTexture.new()
	atlas.atlas = PlayerCharacters.sheet(GameState.character_id)
	atlas.region = Rect2(0, 0, 32, 32)
	row.add_child(MenuStyle.texture_rect(atlas, Vector2(224, 224)))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	row.add_child(info)
	var entry := PlayerCharacters.find(GameState.character_id)
	info.add_child(MenuStyle.label("Ficha de entrenador", 30, MenuStyle.ACCENT))
	info.add_child(MenuStyle.label("Nombre: %s   ·   Región de origen: %s" % [GameState.player_name, entry["region"]], 22))
	var minutes := int(GameState.play_time / 60.0)
	info.add_child(MenuStyle.label("Tiempo jugado: %d h %02d min" % [minutes / 60, minutes % 60], 22))
	info.add_child(MenuStyle.label("Dinero: $%d" % GameState.money, 22))
	var seen := 0
	var caught := 0
	var shinies := 0
	for id: String in GameState.dex:
		seen += 1 if GameState.dex[id]["seen"] > 0 else 0
		caught += 1 if GameState.dex[id]["caught"] > 0 else 0
		shinies += 1 if GameState.dex[id]["shiny"] else 0
	info.add_child(MenuStyle.label("Pokédex: %d vistos · %d capturados (de 1,025)" % [seen, caught], 22))
	info.add_child(MenuStyle.label("Shinies capturados: %d   ·   Legendarios: %d" % [shinies, GameState.legendary_caught.size()], 22))
	info.add_child(MenuStyle.label("Dificultad: %s" % GameState.DIFFICULTIES[GameState.difficulty]["name"], 22))
	info.add_child(MenuStyle.label("Medallas, cintas e insignias: llegarán con los caminos.", 18, MenuStyle.MUTED))
	return box


func _map_page() -> Control:
	var box := VBoxContainer.new()
	box.add_child(MenuStyle.label("Mapa de la región", 28, MenuStyle.ACCENT))
	box.add_child(MenuStyle.wrapped("Abre el mapa completo con la niebla de lo que has explorado. También con %s." % InputHints.hint("map"), 20))
	var open_map := MenuStyle.button("Abrir el mapa", 24)
	open_map.pressed.connect(func() -> void:
		close()
		var map_ui := main.get_node_or_null("MapUi") if main != null else null
		if map_ui != null:
			map_ui.call("toggle_full_map"))
	box.add_child(open_map)
	return box
