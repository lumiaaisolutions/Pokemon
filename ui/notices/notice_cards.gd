class_name NoticeCards
extends Control
## Avisos en tarjetas (acordado con Fernando el 2026-10-10): entran por la derecha bajo
## el reloj, se apilan (máximo MAX a la vez) y se van solas. Cada una tiene un círculo de
## color con el ícono de su categoría, el nombre de la categoría y el texto, para saber de
## un vistazo de qué se trata. Lo que dice un NPC no va aquí: va a la caja de diálogo.

const MAX := 3
const WIDTH := 460.0
## Categoría: [nombre visible, color, ícono (sección de UiIcons u objeto)].
const CATEGORIES := {
	"capture": ["Captura", Color(0.89, 0.22, 0.25), "item:poke-ball"],
	"item": ["Objeto", Color(0.3, 0.72, 0.4), "Mochila"],
	"money": ["Dinero", Color(0.95, 0.68, 0.15), "Dinero"],
	"mission": ["Misión", Color(0.95, 0.5, 0.2), "Rotom"],
	## Noticias del Rotom Móvil que no son misiones (brotes, bandadas, lluvia de estrellas…).
	"rotom": ["Rotom", Color(0.82, 0.3, 0.55), "Rotom"],
	"achievement": ["Logro", Color(0.92, 0.72, 0.1), "Logros"],
	"battle": ["Combate", Color(0.55, 0.35, 0.85), "Nueva partida"],
	"pokemon": ["Tu Pokémon", Color(0.25, 0.6, 0.9), "Pokémon"],
	"research": ["Investigación", Color(0.2, 0.65, 0.75), "Pokédex"],
	"place": ["Lugar", Color(0.4, 0.55, 0.35), "Mapa"],
	"save": ["Partida", Color(0.35, 0.45, 0.7), "Guardar"],
	"info": ["Aviso", Color(0.45, 0.5, 0.6), "Ficha"],
}

var _box: VBoxContainer
var _last := ""
var _last_time := -10.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -WIDTH - 24.0
	offset_right = -24.0
	offset_top = 290.0
	offset_bottom = 290.0
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.custom_minimum_size.x = WIDTH
	add_child(_box)


## Categoría de un aviso según su texto (los 100+ avisos del juego ya existentes).
static func category_of(text: String) -> String:
	var t := text.to_lower()
	if t.begins_with("¡logro") or t.contains("logro desbloqueado"):
		return "achievement"
	if t.contains("atrapaste") or t.contains("escapó de la pokéball") or t.contains("captura"):
		return "capture"
	if t.begins_with("¡logro") or t.contains("logro desbloqueado"):
		return "achievement"
	if t.contains("misión") or t.contains("rotom") or t.contains("actividad") or t.contains("megapiedra"):
		return "mission"
	if t.contains("$") or t.contains("dinero"):
		return "money"
	if t.contains("combate") or t.contains("ganó") or t.contains("escapaste") or t.contains("saca a") or t.contains("quiere pelear") or t.contains("venciste") or t.contains("retiraste"):
		return "battle"
	if t.contains("encontraste") or t.contains("recibiste") or t.contains("soltó") or t.contains("te dio") or t.begins_with("+"):
		return "item"
	if t.contains("investigación") or t.contains("pokédex") or t.contains("foto"):
		return "research"
	if t.contains("vínculo") or t.contains("evolucion") or t.contains("adelante") or t.contains("regresa") or t.contains("te acompaña") or t.contains("aprendió") or t.contains("desbloqueó"):
		return "pokemon"
	if t.contains("guardad") or t.contains("partida"):
		return "save"
	return "info"


## Noticia del Rotom: es "Misión" si habla de misiones, actividades o megapiedras; si no, "Rotom".
static func rotom_category(text: String) -> String:
	var t := text.to_lower()
	return "mission" if t.contains("misión") or t.contains("actividad") or t.contains("megapiedra") else "rotom"


func show_notice(text: String, category: String = "") -> void:
	# El mismo aviso dos veces seguidas no se repite.
	var now := Time.get_ticks_msec() / 1000.0
	if text == _last and now - _last_time < 3.0:
		return
	_last = text
	_last_time = now
	var kind := category if CATEGORIES.has(category) else category_of(text)
	var data: Array = CATEGORIES[kind]
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiKit.light_style(data[1], 16, 0)
	style.border_width_left = 8
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	row.add_child(UiKit.icon_badge(_icon(String(data[2])), data[1], 52.0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var title := UiKit.label(String(data[0]).to_upper(), 15, (data[1] as Color).darkened(0.15), true)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	column.add_child(title)
	var body := UiKit.label(text, 19, UiKit.TEXT, true)
	body.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = WIDTH - 110.0
	column.add_child(body)
	var slide := MarginContainer.new()
	slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slide.add_theme_constant_override("margin_left", 80)
	slide.add_child(card)
	_box.add_child(slide)
	while _box.get_child_count() > MAX:
		var oldest := _box.get_child(0)
		_box.remove_child(oldest)
		oldest.queue_free()
	# Entra deslizándose desde la derecha y se va sola.
	slide.modulate.a = 0.0
	var tween := slide.create_tween()
	tween.tween_property(slide, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_method(func(v: float) -> void: slide.add_theme_constant_override("margin_left", int(v)), 80.0, 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(GameOptions.notice_seconds(text))
	tween.tween_property(slide, "modulate:a", 0.0, 0.35)
	tween.tween_callback(slide.queue_free)


static func _icon(name: String) -> Texture2D:
	if name.begins_with("item:"):
		return Items.icon(name.substr(5))
	return UiIcons.section(name)


func visible_texts() -> Array[String]:
	var result: Array[String] = []
	for slide in _box.get_children():
		var labels := slide.find_children("*", "Label", true, false)
		if labels.size() >= 2:
			result.append((labels[1] as Label).text)
	return result
