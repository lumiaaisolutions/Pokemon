class_name MissionPanel
extends Control
## Tablero de misiones (acordado con Fernando el 2026-10-10): a la izquierda, bajo la
## bienvenida, 3 tarjetas con las misiones en curso o con más avance (ícono, nombre y
## barra). J (o mantener la cruceta ↓) abre el tablero completo por categoría, con
## objetivos y premios (pausa el juego).

const WIDTH := 400.0

var _cards: VBoxContainer
var _full: Control
var _full_list: VBoxContainer
var _refresh := 0.0
var _key := ""
var _hold := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards = VBoxContainer.new()
	_cards.position = Vector2(24, 250)
	_cards.custom_minimum_size.x = WIDTH
	_cards.add_theme_constant_override("separation", 8)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards)
	_build_full()


func _process(delta: float) -> void:
	# Mantener la cruceta ↓ (cambiar ball) medio segundo también abre el tablero.
	if Input.is_action_pressed("ball_prev") and not get_tree().paused:
		_hold += delta
		if _hold > 0.5:
			_hold = -99.0
			toggle_full()
	elif not Input.is_action_pressed("ball_prev"):
		_hold = 0.0
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 1.0
	var top := MissionBoard.top(get_tree())
	var key := str(top.map(func(m: Dictionary) -> String: return "%s%.2f" % [m["title"], m["progress"]]))
	if key == _key:
		return
	_key = key
	for child in _cards.get_children():
		child.queue_free()
	if top.is_empty():
		return
	var header := UiKit.label_on_dark("MISIONES  ·  [%s] ver todas" % InputHints.hint("missions"), 16, Color(1, 0.95, 0.8))
	header.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.12))
	header.add_theme_constant_override("outline_size", 5)
	_cards.add_child(header)
	for mission: Dictionary in top:
		_cards.add_child(_card(mission, false))


## Las tarjetas van debajo del panel de bienvenida (o arriba si no hay).
func set_top(y: float) -> void:
	_cards.position.y = y


func _card(mission: Dictionary, full: bool) -> PanelContainer:
	var data: Array = MissionBoard.CATEGORIES[mission["category"]]
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiKit.light_style(data[1], 14, 0)
	style.border_width_left = 6
	style.set_content_margin_all(10)
	style.content_margin_left = 12
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	row.add_child(UiKit.icon_badge(UiIcons.section(String(data[2])), data[1], 38.0 if not full else 48.0))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)
	row.add_child(column)
	var title := UiKit.label(String(mission["title"]), 16 if not full else 20, UiKit.TEXT, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = (WIDTH - 90.0) if not full else 700.0
	column.add_child(title)
	column.add_child(UiKit.bar(float(mission["progress"]), 0, data[1], 8 if not full else 10))
	if full:
		column.add_child(UiKit.label("%s   ·   Premio: %s" % [mission["detail"], mission["reward"]], 16, UiKit.TEXT_SOFT, true))
	return card


# --- Tablero completo ------------------------------------------------------------------

func _build_full() -> void:
	# En su propia capa, encima de todo el HUD y del minimapa.
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_full = Control.new()
	_full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_full.theme = UiKit.theme()
	_full.visible = false
	layer.add_child(_full)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.06, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_full.add_child(dim)
	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = UiKit.RED
	frame_style.set_corner_radius_all(36)
	frame_style.border_color = UiKit.RED_DARK
	frame_style.set_border_width_all(6)
	frame_style.set_content_margin_all(22)
	frame.add_theme_stylebox_override("panel", frame_style)
	_full.add_child(UiKit.centered_margin(frame, 0.12, 0.07))
	var inner := PanelContainer.new()
	var inner_style := UiKit.light_style(Color(0, 0, 0, 0), 26, 0)
	inner_style.set_content_margin_all(24)
	inner.add_theme_stylebox_override("panel", inner_style)
	frame.add_child(inner)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	inner.add_child(column)
	column.add_child(UiKit.title("Misiones", UiIcons.section("Rotom"), 34))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_full_list = VBoxContainer.new()
	_full_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_full_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_full_list)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_child(UiKit.hint("missions", "Cerrar"))
	column.add_child(footer)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("missions") and (not get_tree().paused or _full.visible):
		get_viewport().set_input_as_handled()
		toggle_full()
	elif _full.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		toggle_full()


func toggle_full() -> void:
	_full.visible = not _full.visible
	get_tree().paused = _full.visible
	AudioBus.play_sfx("ui_open" if _full.visible else "ui_close")
	if not _full.visible:
		return
	for child in _full_list.get_children():
		child.queue_free()
	var all := MissionBoard.collect(get_tree())
	if all.is_empty():
		_full_list.add_child(UiKit.label("Sin misiones por ahora. Habla con la gente, el profesor y revisa el Rotom.", 20, UiKit.TEXT_SOFT, true))
	for category: String in MissionBoard.CATEGORIES:
		var group := all.filter(func(m: Dictionary) -> bool: return m["category"] == category)
		if group.is_empty():
			continue
		var data: Array = MissionBoard.CATEGORIES[category]
		_full_list.add_child(UiKit.label("%s  (%d)" % [String(data[0]).to_upper(), group.size()], 20, (data[1] as Color).darkened(0.2), true))
		for mission: Dictionary in group:
			_full_list.add_child(_card(mission, true))


func is_open() -> bool:
	return _full.visible
