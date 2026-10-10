class_name GameMenu
extends Control
## Menú del juego (I / Start) al estilo Pokopia (acordado con Fernando el 2026-10-10):
## - Inicio: el juego sigue visible a la izquierda y a la derecha un panel rojo
##   redondeado (lente y luces arriba, hora y dinero) con una tarjeta clara y la
##   cuadrícula de íconos grandes; el elegido tiene halo amarillo y rebota.
## - Sección: se abre a pantalla completa dentro de un marco rojo con su título en una
##   píldora arriba. Esc / B regresa al inicio; Q / E cambian de sección; I cierra.
## Pausa el juego. Escala 1920×1080 (se adapta a la ventana).

const TABS := ["Equipo", "Mochila", "Pokédex", "Caja", "Rotom", "Logros", "Dinero", "Ficha", "Mapa", "Controles", "Opciones", "Guardar"]
## Nombre visible de cada sección.
const TITLES := {"Equipo": "Pokémon", "Caja": "Cajas"}
const HUB := -1

## Escena principal (compañero, cambio de acompañante, mapa).
var main: Node
## Sección abierta (HUB = el inicio con la cuadrícula).
var tab := HUB
## Miembro del equipo que se muestra en la pestaña Equipo.
var selected_member := 0
var _hub: Control
var _grid: GridContainer
var _hub_info: Label
var _section: Control
var _title_label: Label
var _header: HBoxContainer
var _content: Control
var _footer: HBoxContainer
var _money: Label
var _team_tab: TeamTab
var _bag_tab: BagTab
var _dex_tab: DexTab
var _last_section := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	visible = false
	_build_hub()
	_build_section()
	_team_tab = TeamTab.new(self)
	_bag_tab = BagTab.new(self)
	_dex_tab = DexTab.new(self)


# --- Inicio: panel rojo con la cuadrícula ------------------------------------------------

func _build_hub() -> void:
	_hub = Control.new()
	_hub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hub)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.18)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hub.add_child(dim)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UiKit.RED
	style.set_corner_radius_all(40)
	style.border_color = UiKit.RED_DARK
	style.set_border_width_all(6)
	style.set_content_margin_all(26)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 16
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -700
	panel.offset_right = -36
	panel.offset_top = 36
	panel.offset_bottom = -36
	_hub.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	# Lente y luces (como la Pokédex) más la hora y el dinero.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	column.add_child(top)
	top.add_child(_lens(84, Color(0.35, 0.8, 0.9)))
	for light_color in [Color(0.95, 0.5, 0.6), Color(0.98, 0.82, 0.25), Color(0.45, 0.82, 0.4)]:
		var holder := CenterContainer.new()
		holder.add_child(_lens(30, light_color))
		top.add_child(holder)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var pill := PanelContainer.new()
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color(1, 1, 1, 0.92)
	pill_style.set_corner_radius_all(22)
	pill_style.content_margin_left = 20
	pill_style.content_margin_right = 20
	pill_style.content_margin_top = 6
	pill_style.content_margin_bottom = 8
	pill.add_theme_stylebox_override("panel", pill_style)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hub_info = UiKit.label("", 19, UiKit.TEXT_SOFT, true)
	pill.add_child(_hub_info)
	top.add_child(pill)
	# Tarjeta clara con la cuadrícula.
	var card := PanelContainer.new()
	var card_style := UiKit.light_style(Color(0, 0, 0, 0), 30, 0)
	card_style.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", card_style)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	card.add_child(inner)
	var heading := UiKit.label("Menú", 28, UiKit.TEXT_SOFT, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 34)
	_grid.add_theme_constant_override("v_separation", 14)
	center.add_child(_grid)
	_money = UiKit.label("", 1, UiKit.TEXT)
	# Pie con botones.
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	footer.add_child(_pill_hint("menu", "Cerrar"))
	footer.add_child(_pill_hint("interact", "Abrir"))


## Círculo brillante (lente de la Pokédex y luces).
func _lens(diameter: float, color: Color) -> Control:
	var lens := Control.new()
	lens.custom_minimum_size = Vector2(diameter, diameter)
	lens.draw.connect(func() -> void:
		var c := lens.size * 0.5
		var r := diameter * 0.5
		lens.draw_circle(c, r, Color(1, 1, 1, 0.95))
		lens.draw_circle(c, r * 0.82, color.darkened(0.15))
		lens.draw_circle(c, r * 0.72, color)
		lens.draw_circle(c + Vector2(-r * 0.28, -r * 0.3), r * 0.2, Color(1, 1, 1, 0.65)))
	return lens


## Píldora blanca con el glifo del botón y su acción (como "Ⓑ Close" de Pokopia).
func _pill_hint(action: String, text: String) -> PanelContainer:
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.94)
	style.set_corner_radius_all(20)
	style.content_margin_left = 12
	style.content_margin_right = 16
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	pill.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	pill.add_child(row)
	row.add_child(InputGlyph.make(action))
	row.add_child(UiKit.label(text, 18, UiKit.TEXT, true))
	return pill


func _fill_hub() -> void:
	for child in _grid.get_children():
		child.queue_free()
	for i in TABS.size():
		var name: String = TABS[i]
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(170, 150)
		tile.focus_mode = Control.FOCUS_ALL
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus"]:
			tile.add_theme_stylebox_override(state, empty)
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 4)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(box)
		var marker := UiKit.label("▼", 16, Color(1.0, 0.7, 0.15), true)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.modulate.a = 0.0
		box.add_child(marker)
		var icon := MenuIcon.make(name, 96)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
		var caption := UiKit.label(TITLES.get(name, name), 19, UiKit.TEXT, true)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(caption)
		tile.focus_entered.connect(func() -> void:
			icon.focused = true
			marker.modulate.a = 1.0
			_last_section = i
			AudioBus.play_sfx("ui_select"))
		tile.focus_exited.connect(func() -> void:
			icon.focused = false
			marker.modulate.a = 0.0)
		tile.mouse_entered.connect(tile.grab_focus)
		tile.pressed.connect(func() -> void:
			AudioBus.play_sfx("ui_decide")
			show_tab(i))
		_grid.add_child(tile)
	(_grid.get_child(clampi(_last_section, 0, TABS.size() - 1)) as Button).grab_focus.call_deferred()
	var minutes := int(GameState.play_time / 60.0)
	_hub_info.text = "Día %d · %s   ·   $%s   ·   ⏱ %d h %02d" % [GameState.game_day() + 1, DayNight.clock_text(GameState.clock_hour()), _thousands(GameState.money), minutes / 60, minutes % 60]


# --- Sección a pantalla completa con marco rojo ------------------------------------------

func _build_section() -> void:
	_section = Control.new()
	_section.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_section.visible = false
	add_child(_section)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.06, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_section.add_child(dim)
	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = UiKit.RED
	frame_style.set_corner_radius_all(40)
	frame_style.border_color = UiKit.RED_DARK
	frame_style.set_border_width_all(6)
	frame_style.content_margin_left = 22
	frame_style.content_margin_right = 22
	frame_style.content_margin_top = 64
	frame_style.content_margin_bottom = 22
	frame_style.shadow_color = Color(0, 0, 0, 0.35)
	frame_style.shadow_size = 16
	frame.add_theme_stylebox_override("panel", frame_style)
	_section.add_child(UiKit.centered_margin(frame, 0.025, 0.04))
	var inner := PanelContainer.new()
	var inner_style := UiKit.light_style(Color(0, 0, 0, 0), 28, 0)
	inner_style.bg_color = UiKit.CREAM
	inner_style.set_content_margin_all(24)
	inner.add_theme_stylebox_override("panel", inner_style)
	frame.add_child(inner)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	inner.add_child(column)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 16)
	column.add_child(_header)
	_content = MarginContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_content)
	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_END
	_footer.add_theme_constant_override("separation", 12)
	column.add_child(_footer)
	# Título en píldora arriba al centro, sobre el marco (con una Pokéball).
	var title_holder := CenterContainer.new()
	title_holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title_holder.offset_top = 52
	title_holder.offset_bottom = 104
	title_holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_section.add_child(title_holder)
	var title_pill := PanelContainer.new()
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(1, 0.97, 0.94)
	title_style.set_corner_radius_all(24)
	title_style.border_color = UiKit.RED_DARK
	title_style.set_border_width_all(4)
	title_style.content_margin_left = 30
	title_style.content_margin_right = 34
	title_style.content_margin_top = 6
	title_style.content_margin_bottom = 8
	title_pill.add_theme_stylebox_override("panel", title_style)
	title_holder.add_child(title_pill)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	title_pill.add_child(title_row)
	title_row.add_child(MenuIcon.make("Pokémon", 34))
	_title_label = UiKit.label("", 26, UiKit.RED_DARK, true)
	title_row.add_child(_title_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") and not _other_overlay_open():
		get_viewport().set_input_as_handled()
		close() if visible else open()
		return
	if event.is_action_pressed("bag") and not _other_overlay_open():
		get_viewport().set_input_as_handled()
		if visible and tab >= 0 and TABS[tab] == "Mochila":
			close()
		else:
			tab = TABS.find("Mochila")
			open() if not visible else show_tab(tab)
		return
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		# En una sección, regresa al inicio; en el inicio, cierra.
		if tab == HUB:
			close()
		else:
			show_tab(HUB)
	elif tab != HUB and event.is_action_pressed("menu_prev"):
		get_viewport().set_input_as_handled()
		show_tab((tab - 1 + TABS.size()) % TABS.size())
	elif tab != HUB and event.is_action_pressed("menu_next"):
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
	tab = HUB
	_set_hud(true)
	get_tree().paused = false


## El HUD se oculta mientras el menú está abierto; el minimapa sigue en el inicio.
func _set_hud(on: bool) -> void:
	if main == null:
		return
	var hud := main.get_node_or_null("Hud") as CanvasLayer
	if hud != null:
		hud.visible = on
	var map_ui := main.get_node_or_null("MapUi") as CanvasLayer
	if map_ui != null:
		map_ui.visible = on or (visible and tab == HUB)


func show_tab(index: int) -> void:
	if visible and index != tab and index != HUB:
		AudioBus.play_sfx("ui_select")
	tab = index
	_hub.visible = tab == HUB
	_section.visible = tab != HUB
	_set_hud(not visible)
	if tab == HUB:
		_fill_hub()
		return
	_last_section = tab
	var name: String = TABS[tab]
	_title_label.text = String(TITLES.get(name, name))
	(_title_label.get_parent().get_child(0) as MenuIcon).icon_name = name
	(_title_label.get_parent().get_child(0) as MenuIcon).queue_redraw()
	# Encabezado: guía de la primera vez.
	for child in _header.get_children():
		child.queue_free()
	var guide := _guide(name)
	if guide != "":
		var tip := UiKit.wrapped("💡 " + guide, 17, UiKit.TEXT_SOFT)
		tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	# Ayudas de botones en píldoras.
	for child in _footer.get_children():
		child.queue_free()
	_footer.add_child(_pill_hint("menu_prev", "Anterior"))
	_footer.add_child(_pill_hint("menu_next", "Siguiente"))
	_footer.add_child(_pill_hint("ui_cancel", "Volver"))
	_footer.add_child(_pill_hint("menu", "Cerrar"))


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
