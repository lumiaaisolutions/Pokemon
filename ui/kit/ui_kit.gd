class_name UiKit
extends RefCounted
## Kit visual de toda la interfaz (estilo Leyendas Z-A / Escarlata y Púrpura, pedido de
## Fernando el 2026-10-10): fondo azul marino translúcido, paneles redondeados, encabezados
## blancos tipo etiqueta, botones en paralelogramo, retratos de Pokémon en recuadros
## claros, barras redondeadas, gráfica de estadísticas en hexágono e íconos (UiIcons).
## Tipografía del sistema (Avenir Next en la Mac) para que se lea limpio.

const NAVY := Color(0.07, 0.11, 0.24)
const NAVY_SOFT := Color(0.12, 0.18, 0.36, 0.86)
const NAVY_LIGHT := Color(0.2, 0.29, 0.52, 0.9)
const WHITE := Color(0.97, 0.98, 1.0)
const INK := Color(0.1, 0.13, 0.25)
const MINT := Color(0.72, 0.95, 0.45)
const GOLD := Color(1.0, 0.86, 0.35)
const MUTED := Color(0.72, 0.78, 0.92)
const HP_GREEN := Color(0.36, 0.86, 0.46)
## Estilo claro (Pokopia, acordado el 2026-10-10): paneles crema, acentos rojos.
const CREAM := Color(0.98, 0.97, 0.94)
const PAPER := Color(0.93, 0.92, 0.88)
const RED := Color(0.89, 0.22, 0.25)
const RED_DARK := Color(0.68, 0.12, 0.16)
const TEXT := Color(0.2, 0.2, 0.26)
const TEXT_SOFT := Color(0.45, 0.45, 0.52)

static var _font: Font
static var _font_bold: Font
static var _theme: Theme


## Fuente del sistema (regular y negrita), con la de Godot como respaldo.
static func font(bold: bool = false) -> Font:
	if _font == null:
		var regular := SystemFont.new()
		regular.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial"])
		regular.font_weight = 500
		regular.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font = regular
		var heavy := SystemFont.new()
		heavy.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial"])
		heavy.font_weight = 800
		heavy.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font_bold = heavy
	return _font_bold if bold else _font


## Tema común (fuente y tamaños) para los controles que no se estilizan a mano.
static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = font()
		_theme.default_font_size = 20
		var scroll_grabber := StyleBoxFlat.new()
		scroll_grabber.bg_color = Color(1, 1, 1, 0.35)
		scroll_grabber.set_corner_radius_all(4)
		_theme.set_stylebox("grabber", "VScrollBar", scroll_grabber)
		_theme.set_stylebox("grabber_highlight", "VScrollBar", scroll_grabber)
		var scroll_bg := StyleBoxFlat.new()
		scroll_bg.bg_color = Color(1, 1, 1, 0.06)
		scroll_bg.set_corner_radius_all(4)
		scroll_bg.content_margin_left = 6
		_theme.set_stylebox("scroll", "VScrollBar", scroll_bg)
		var tooltip := StyleBoxFlat.new()
		tooltip.bg_color = Color(0.05, 0.08, 0.18, 0.96)
		tooltip.set_corner_radius_all(8)
		tooltip.set_content_margin_all(10)
		_theme.set_stylebox("panel", "TooltipPanel", tooltip)
		var line := StyleBoxFlat.new()
		line.bg_color = Color(1, 1, 1, 0.12)
		line.set_corner_radius_all(8)
		line.set_content_margin_all(10)
		line.border_color = Color(1, 1, 1, 0.35)
		line.set_border_width_all(2)
		_theme.set_stylebox("normal", "LineEdit", line)
		var line_focus := line.duplicate() as StyleBoxFlat
		line_focus.border_color = MINT
		_theme.set_stylebox("focus", "LineEdit", line_focus)
	return _theme


# --- Fondo y paneles ---------------------------------------------------------------------

## Fondo de pantalla completa: degradado azul con franjas diagonales de luz.
static func backdrop(alpha: float = 0.93) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.04, 0.07, 0.17, alpha), Color(0.1, 0.2, 0.42, alpha), Color(0.05, 0.1, 0.24, alpha)])
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 1)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rect)
	# Franjas de luz.
	var streaks := Control.new()
	streaks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	streaks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	streaks.draw.connect(func() -> void:
		var size := streaks.size
		for i in 6:
			var x := size.x * (0.15 + i * 0.17)
			var width := 40.0 + i * 18.0
			streaks.draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + width, 0), Vector2(x + width - size.y * 0.45, size.y), Vector2(x - size.y * 0.45, size.y)]),
					Color(1, 1, 1, 0.025)))
	root.add_child(streaks)
	return root


static func panel_style(light: bool = false, radius: int = 14, border: Color = Color(1, 1, 1, 0.12)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = NAVY_LIGHT if light else NAVY_SOFT
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 8
	return style


static func panel(light: bool = false) -> PanelContainer:
	var container := PanelContainer.new()
	container.add_theme_stylebox_override("panel", panel_style(light))
	return container


## Panel blanco (fichas como la de Gyarados de la referencia).
static func card_style(radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = WHITE
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(12)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 6
	return style


# --- Texto ----------------------------------------------------------------------------------

static func label(text: String, size: int = 20, color: Color = WHITE, bold: bool = false) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override("font", font(bold))
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35) if color.v > 0.5 else Color(0, 0, 0, 0))
	result.add_theme_constant_override("shadow_offset_x", 1)
	result.add_theme_constant_override("shadow_offset_y", 2)
	return result


static func wrapped(text: String, size: int = 18, color: Color = WHITE) -> Label:
	var result := label(text, size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result


## Título grande con espaciado ("MENÚ", "CAJAS"…).
static func title(text: String, icon: Texture2D = null, size: int = 46) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	if icon != null:
		row.add_child(icon_rect(icon, Vector2(size, size)))
	var text_label := label(" ".join(text.to_upper().split("")), size, Color(0.9, 0.94, 1.0), true)
	text_label.add_theme_constant_override("outline_size", 0)
	row.add_child(text_label)
	return row


## Encabezado blanco tipo etiqueta con ícono (p. ej. "◉ POKÉMON").
static func header_chip(text: String, icon: Texture2D = null) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := card_style(20)
	style.content_margin_left = 16
	style.content_margin_right = 22
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	chip.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	chip.add_child(row)
	if icon != null:
		row.add_child(icon_rect(icon, Vector2(28, 28)))
	row.add_child(label(text.to_upper(), 22, INK, true))
	return chip


static func icon_rect(texture: Texture2D, size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


# --- Botones ----------------------------------------------------------------------------

## Botón de la barra lateral: ícono + texto; al tener foco o estar elegido se vuelve blanco.
static func side_button(text: String, icon: Texture2D, selected: bool) -> Button:
	var button := Button.new()
	button.text = "  " + text
	button.icon = icon
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", 34)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_font_override("font", font(true))
	button.add_theme_font_size_override("font_size", 22)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.08)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 18
	normal.content_margin_right = 12
	normal.border_width_left = 0
	var active := normal.duplicate() as StyleBoxFlat
	active.bg_color = WHITE
	active.border_color = MINT
	active.border_width_left = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1, 1, 1, 0.2)
	button.add_theme_stylebox_override("normal", active if selected else normal)
	button.add_theme_stylebox_override("hover", active if selected else hover)
	button.add_theme_stylebox_override("focus", active)
	button.add_theme_stylebox_override("pressed", active)
	for state in ["font_color", "font_hover_color"]:
		button.add_theme_color_override(state, INK if selected else Color(0.85, 0.9, 1.0))
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	_sounds(button)
	return button


## Sonidos de la interfaz de BW2: mover el foco y decidir.
static func _sounds(button: Button) -> void:
	button.focus_entered.connect(func() -> void:
		if button.is_visible_in_tree() and Input.get_last_mouse_velocity().length() < 1.0:
			AudioBus.play_sfx("ui_select"))
	button.pressed.connect(func() -> void: AudioBus.play_sfx("ui_decide"))


## Botón en paralelogramo (movimientos, acciones), con color de borde opcional.
static func slant_button(text: String, accent: Color = Color(1, 1, 1, 0.3), size: int = 19, selected: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", font(true))
	button.add_theme_font_size_override("font_size", size)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.24, 0.46, 0.95) if not selected else Color(0.3, 0.42, 0.7, 0.98)
	normal.skew = Vector2(0.28, 0)
	normal.set_corner_radius_all(4)
	normal.border_color = accent
	normal.set_border_width_all(2)
	normal.border_width_left = 6
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = WHITE
	hover.border_color = MINT
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	_sounds(button)
	return button


## Botón principal (acciones grandes del inicio, confirmar…).
static func big_button(text: String, icon: Texture2D = null) -> Button:
	var button := side_button(text, icon, false)
	button.custom_minimum_size = Vector2(420, 66)
	button.add_theme_font_size_override("font_size", 26)
	return button


# --- Datos de Pokémon -----------------------------------------------------------------

## Píldora del tipo: color del tipo, ícono y nombre en mayúsculas.
static func type_chip(type: int) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = AttackProjectile.TYPE_COLORS.get(type, Color.GRAY)
	style.set_corner_radius_all(4)
	style.skew = Vector2(0.2, 0)
	style.content_margin_left = 10
	style.content_margin_right = 12
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	chip.add_child(row)
	row.add_child(icon_rect(UiIcons.type_icon(type), Vector2(18, 18)))
	var text := label(MenuStyle.TYPE_NAMES[type].to_upper() if type >= 0 and type < 18 else "?", 15, WHITE, true)
	row.add_child(text)
	return chip


## Barra redondeada (vida, estadísticas).
static func bar(ratio: float, width: float, color: Color = HP_GREEN, height: float = 12.0) -> ProgressBar:
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(width, height)
	progress.show_percentage = false
	progress.value = clampf(ratio, 0.0, 1.0) * 100.0
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.08, 0.16, 0.7)
	background.set_corner_radius_all(int(height * 0.5))
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(int(height * 0.5))
	progress.add_theme_stylebox_override("background", background)
	progress.add_theme_stylebox_override("fill", fill)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return progress


static func hp_color(ratio: float) -> Color:
	return HP_GREEN if ratio > 0.5 else (Color(0.98, 0.8, 0.25) if ratio > 0.2 else Color(0.95, 0.3, 0.25))


## Retrato de un Pokémon en recuadro claro con su vida debajo (tira del equipo y cajas).
static func portrait_card(entry: Dictionary, selected: bool, compact: bool = false) -> Button:
	var species := MenuStyle.species(entry["species"])
	var button := Button.new()
	button.custom_minimum_size = Vector2(118, 150) if not compact else Vector2(96, 96)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.82, 0.86, 0.95, 0.92) if not selected else WHITE
	normal.set_corner_radius_all(10)
	normal.border_color = MINT if selected else Color(1, 1, 1, 0.0)
	normal.set_border_width_all(4 if selected else 0)
	normal.shadow_color = Color(0, 0, 0, 0.3)
	normal.shadow_size = 5
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = WHITE
	hover.border_color = MINT
	hover.set_border_width_all(4)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6
	box.offset_right = -6
	box.offset_top = 4
	box.offset_bottom = -6
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var portrait := icon_rect(MenuStyle.front_sprite(species, entry.get("shiny", false)) if species != null else null, Vector2(0, 92 if not compact else 72))
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(portrait)
	if not compact:
		var ratio := float(entry.get("hp_ratio", 1.0))
		box.add_child(bar(ratio, 0, hp_color(ratio), 8))
		var bond := bar(float(entry.get("bond", 1)) / 10.0, 0, Color(0.4, 0.7, 1.0), 5)
		box.add_child(bond)
		var info := label("Vínc. %d%s" % [int(entry.get("bond", 1)), "  ✦" if entry.get("shiny", false) else ""], 14, INK, true)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(info)
	return button


## Botón vacío de caja/equipo.
static func empty_slot(size: Vector2) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.05)
	style.border_color = Color(1, 1, 1, 0.12)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	slot.add_theme_stylebox_override("panel", style)
	return slot


## Indicación de botón: glifo (teclado o mando) y texto.
static func hint(action: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(InputGlyph.make(action))
	row.add_child(label(text, 17, Color(0.9, 0.93, 1.0)))
	return row


## Margen para centrar contenido con proporción (responsive): márgenes en % del ancho.
static func centered_margin(child: Control, horizontal: float = 0.04, vertical: float = 0.04) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var size := Vector2(1920, 1080)
	margin.add_theme_constant_override("margin_left", int(size.x * horizontal))
	margin.add_theme_constant_override("margin_right", int(size.x * horizontal))
	margin.add_theme_constant_override("margin_top", int(size.y * vertical))
	margin.add_theme_constant_override("margin_bottom", int(size.y * vertical))
	margin.add_child(child)
	return margin


# --- Estilo claro (Pokopia) ------------------------------------------------------------

## Panel claro redondeado con borde de color (tarjetas, diálogo).
static func light_style(border: Color = RED, radius: int = 18, border_width: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_content_margin_all(14)
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style


## Círculo de color con un ícono dentro (categoría de un aviso, retrato).
static func icon_badge(texture: Texture2D, color: Color, diameter: float = 52.0) -> Control:
	var holder := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(diameter * 0.5))
	style.set_content_margin_all(diameter * 0.16)
	holder.add_theme_stylebox_override("panel", style)
	holder.custom_minimum_size = Vector2(diameter, diameter)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon := icon_rect(texture, Vector2(diameter, diameter) * 0.68)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(icon)
	return holder
