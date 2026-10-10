class_name GameMenu
extends Control
## Menú del juego (I / Options), estilo Leyendas Z-A: a la izquierda "MENÚ" con las
## secciones con ícono; a la derecha el encabezado blanco de la sección, su contenido y las
## ayudas de botones abajo. Pausa el juego. Se cambia de sección con Q / E o L1 / R1, con
## el mouse o con la cruceta. Se adapta a cualquier tamaño de ventana (escala 1920×1080).

const TABS := ["Equipo", "Mochila", "Pokédex", "Caja", "Rotom", "Logros", "Dinero", "Ficha", "Mapa", "Controles", "Opciones", "Guardar"]
## Nombre visible de cada sección.
const TITLES := {"Equipo": "Pokémon", "Caja": "Cajas"}

## Escena principal (compañero, cambio de acompañante, mapa).
var main: Node
var tab := 0
## Miembro del equipo que se muestra en la pestaña Equipo.
var selected_member := 0
var _sidebar: VBoxContainer
var _header: HBoxContainer
var _content: Control
var _footer: HBoxContainer
var _money: Label
var _team_tab: TeamTab
var _bag_tab: BagTab
var _dex_tab: DexTab


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	visible = false
	add_child(UiKit.backdrop(0.985))
	var outer := HBoxContainer.new()
	outer.add_theme_constant_override("separation", 34)
	add_child(UiKit.centered_margin(outer, 0.03, 0.035))
	# Barra lateral.
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 360
	side.add_theme_constant_override("separation", 14)
	outer.add_child(side)
	side.add_child(UiKit.title("Menú", UiIcons.section("Opciones"), 44))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	_sidebar = VBoxContainer.new()
	_sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar.add_theme_constant_override("separation", 8)
	scroll.add_child(_sidebar)
	_money = UiKit.label("", 20, UiKit.GOLD, true)
	side.add_child(_money)
	# Contenido.
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	outer.add_child(column)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 16)
	column.add_child(_header)
	_content = MarginContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_content)
	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_END
	_footer.add_theme_constant_override("separation", 26)
	column.add_child(_footer)
	_team_tab = TeamTab.new(self)
	_bag_tab = BagTab.new(self)
	_dex_tab = DexTab.new(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") and not _other_overlay_open():
		get_viewport().set_input_as_handled()
		close() if visible else open()
		return
	if event.is_action_pressed("bag") and not _other_overlay_open():
		get_viewport().set_input_as_handled()
		if visible and TABS[tab] == "Mochila":
			close()
		else:
			tab = TABS.find("Mochila")
			open() if not visible else show_tab(tab)
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
	# En combate el menú abre la Mochila (pociones y bayas).
	var battle := main.get_node_or_null("Battle") as BattleManager if main != null else null
	if battle != null and battle.active:
		tab = TABS.find("Mochila")
	_set_hud(false)
	AudioBus.play_sfx("ui_open")
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_tab(tab)


func close() -> void:
	if visible:
		AudioBus.play_sfx("ui_close")
	visible = false
	_set_hud(true)
	get_tree().paused = false


## El HUD y el minimapa se ocultan mientras el menú está abierto.
func _set_hud(on: bool) -> void:
	if main == null:
		return
	for path in ["Hud", "MapUi"]:
		var node := main.get_node_or_null(path) as CanvasLayer
		if node != null:
			node.visible = on


func show_tab(index: int) -> void:
	if visible and index != tab:
		AudioBus.play_sfx("ui_select")
	tab = index
	var name: String = TABS[tab]
	# Barra lateral.
	for child in _sidebar.get_children():
		child.queue_free()
	for i in TABS.size():
		var button := UiKit.side_button(TITLES.get(TABS[i], TABS[i]), UiIcons.section(TABS[i]), i == tab)
		button.pressed.connect(show_tab.bind(i))
		_sidebar.add_child(button)
		if i == tab:
			button.grab_focus.call_deferred()
	var minutes := int(GameState.play_time / 60.0)
	_money.text = "$%s      ⏱ %d h %02d" % [_thousands(GameState.money), minutes / 60, minutes % 60]
	# Encabezado.
	for child in _header.get_children():
		child.queue_free()
	_header.add_child(UiKit.header_chip(TITLES.get(name, name), UiIcons.section(name)))
	var guide := _guide(name)
	if guide != "":
		var tip := UiKit.wrapped("💡 " + guide, 17, UiKit.MUTED)
		tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_header.add_child(tip)
	# Contenido.
	for child in _content.get_children():
		child.queue_free()
	var page: Control
	match name:
		"Equipo":
			page = _team_tab.build()
		"Mochila":
			page = _bag_tab.build()
		"Pokédex":
			page = _dex_tab.build()
		"Rotom":
			page = RotomTab.build()
		"Caja":
			page = BoxTab.build(self)
		"Logros":
			page = ExtraTabs.achievements()
		"Dinero":
			page = ExtraTabs.money()
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
	# Ayudas de botones.
	for child in _footer.get_children():
		child.queue_free()
	_footer.add_child(UiKit.hint("menu_prev", "Sección anterior"))
	_footer.add_child(UiKit.hint("menu_next", "Sección siguiente"))
	_footer.add_child(UiKit.hint("menu", "Cerrar"))


static func _thousands(value: int) -> String:
	var text := str(absi(value))
	var result := ""
	while text.length() > 3:
		result = "," + text.substr(text.length() - 3) + result
		text = text.substr(0, text.length() - 3)
	return ("-" if value < 0 else "") + text + result


## Guía de la primera vez en cada sección.
const GUIDES := {
	"Equipo": "Elige un Pokémon arriba para ver su ficha. Reparte sus Puntos de Entrenamiento y cambia sus movimientos.",
	"Mochila": "Tus objetos por bolsillo (íconos de arriba). Úsalos en el Pokémon que elijas a la derecha.",
	"Pokédex": "Las 1,025 especies. Investiga cada una para ver dónde vive en el mapa.",
	"Caja": "Elige un Pokémon del equipo o de la caja para ver su ficha y moverlo.",
	"Rotom": "Tus actividades con plazo. Cúmplelas antes de que se acabe el tiempo.",
	"Logros": "Medallas por hitos y las estadísticas de tu partida.",
	"Dinero": "Tu dinero, lo que ganas y pierdes.",
	"Ficha": "Tu ficha de entrenador.",
	"Mapa": "Abre el mapa completo de la región.",
	"Controles": "Todos los botones del teclado de Mac y del control.",
	"Opciones": "Ajusta cámara, video, audio, dificultad, accesibilidad y botones.",
	"Guardar": "Guarda en 3 ranuras. También hay autoguardado.",
}


func _guide(name: String) -> String:
	var key := "menu_" + name
	if GameState.tips_seen.get(key, false) or not GUIDES.has(name):
		return ""
	GameState.tips_seen[key] = true
	return GUIDES[name]


## Compatibilidad: antes había una tira fija del equipo; ahora cada sección dibuja la suya.
func refresh_strip() -> void:
	pass


## Fila del equipo (6 retratos) que usan las secciones Equipo, Mochila y Cajas.
func party_row(on_pick: Callable, highlight: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for i in GameState.PARTY_MAX:
		if i >= GameState.party.size():
			row.add_child(UiKit.empty_slot(Vector2(118, 150)))
			continue
		var card := UiKit.portrait_card(GameState.party[i], i == highlight)
		if i == GameState.companion_index:
			var star := UiKit.label("★", 20, UiKit.GOLD, true)
			star.position = Vector2(6, 2)
			card.add_child(star)
		card.pressed.connect(on_pick.bind(i))
		row.add_child(card)
	return row


func _trainer_card() -> Control:
	var center := CenterContainer.new()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card_style(18))
	card.custom_minimum_size = Vector2(1100, 520)
	center.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	card.add_child(row)
	var atlas := AtlasTexture.new()
	atlas.atlas = PlayerCharacters.sheet(GameState.character_id)
	atlas.region = Rect2(0, 0, 32, 32)
	var portrait := PanelContainer.new()
	var portrait_style := UiKit.panel_style(true, 16)
	portrait_style.bg_color = Color(0.85, 0.9, 1.0)
	portrait.add_theme_stylebox_override("panel", portrait_style)
	portrait.add_child(UiKit.icon_rect(atlas, Vector2(260, 260)))
	row.add_child(portrait)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 12)
	row.add_child(info)
	var entry := PlayerCharacters.find(GameState.character_id)
	info.add_child(UiKit.label("FICHA DE ENTRENADOR", 30, UiKit.INK, true))
	var seen := 0
	var caught := 0
	var shinies := 0
	for id: String in GameState.dex:
		seen += 1 if GameState.dex[id]["seen"] > 0 else 0
		caught += 1 if GameState.dex[id]["caught"] > 0 else 0
		shinies += 1 if GameState.dex[id]["shiny"] else 0
	var minutes := int(GameState.play_time / 60.0)
	var lines := [
		["Nombre", GameState.player_name], ["Origen", entry["region"]], ["Tiempo jugado", "%d h %02d min" % [minutes / 60, minutes % 60]],
		["Dinero", "$" + _thousands(GameState.money)], ["Pokédex", "%d vistos · %d capturados" % [seen, caught]],
		["Shinies · Legendarios", "%d · %d" % [shinies, GameState.legendary_caught.size()]],
		["Dificultad", GameState.DIFFICULTIES[GameState.difficulty]["name"]],
		["Medallas", "%d / 8" % (GameState.world_flags.get("badges", []) as Array).size()],
		["Cintas", "%d / 5" % (GameState.world_flags.get("ribbons", []) as Array).size()],
	]
	for line: Array in lines:
		var item := HBoxContainer.new()
		var key := UiKit.label(line[0], 20, Color(0.35, 0.4, 0.55), true)
		key.custom_minimum_size.x = 280
		item.add_child(key)
		item.add_child(UiKit.label(str(line[1]), 22, UiKit.INK, true))
		info.add_child(item)
	return center


func _map_page() -> Control:
	var center := CenterContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	box.add_child(UiKit.icon_rect(Items.icon("town-map"), Vector2(140, 140)))
	box.add_child(UiKit.label("Mapa de la región", 32, UiKit.WHITE, true))
	box.add_child(UiKit.wrapped("Abre el mapa completo con la niebla de lo que has explorado. También con %s." % InputHints.hint("map"), 20, UiKit.MUTED))
	var open_map := UiKit.big_button("Abrir el mapa", Items.icon("town-map"))
	open_map.pressed.connect(func() -> void:
		close()
		var map_ui := main.get_node_or_null("MapUi") if main != null else null
		if map_ui != null:
			map_ui.call("toggle_full_map"))
	box.add_child(open_map)
	return center
