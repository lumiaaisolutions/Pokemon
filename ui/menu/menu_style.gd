class_name MenuStyle
extends RefCounted
## Estilo compartido del menú: ventanas con borde pixel al estilo B2W2, etiquetas con
## contorno, botones que se iluminan con el foco y colores por tipo.

const ACCENT := Color(0.72, 0.95, 0.45)
const TEXT := Color(0.96, 0.96, 0.98)
const MUTED := Color(0.75, 0.8, 0.9)
const TYPE_NAMES := ["Normal", "Lucha", "Volador", "Veneno", "Tierra", "Roca", "Bicho", "Fantasma", "Acero",
		"Fuego", "Agua", "Planta", "Eléctrico", "Psíquico", "Hielo", "Dragón", "Siniestro", "Hada"]
const TEMPERAMENT_NAMES := ["Tranquilo", "Curioso", "Tímido", "Agresivo", "Territorial"]


static func panel(border: Color = Color(1, 1, 1, 0.14), background: Color = UiKit.NAVY_SOFT) -> StyleBoxFlat:
	var style := UiKit.panel_style(false, 14, Color(border.r, border.g, border.b, 0.35) if border != Color(1, 1, 1, 0.14) else border)
	if not UiKit.light or background != UiKit.NAVY_SOFT:
		style.bg_color = background
	return style


static func panel_container(border: Color = Color(1, 1, 1, 0.14)) -> PanelContainer:
	var container := PanelContainer.new()
	container.add_theme_stylebox_override("panel", panel(border))
	return container


static func label(text: String, size: int = 20, color: Color = TEXT) -> Label:
	return UiKit.label(text, size, color, size >= 24 or color == ACCENT)


static func wrapped(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var result := label(text, size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result


static func button(text: String, size: int = 20) -> Button:
	var result := Button.new()
	result.text = text
	result.add_theme_font_override("font", UiKit.font(true))
	result.add_theme_font_size_override("font_size", size)
	style_button(result)
	result.pressed.connect(func() -> void: AudioBus.play_sfx("ui_decide"))
	return result


## Botón redondeado: translúcido; elegido, con foco o encima del mouse se vuelve blanco
## con borde verde (como en Z-A).
static func style_button(target: Button, selected: bool = false) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.1) if not selected else Color(0.86, 0.92, 1.0)
	normal.set_corner_radius_all(8)
	normal.border_color = UiKit.MINT if selected else Color(1, 1, 1, 0.18)
	normal.set_border_width_all(2)
	normal.border_width_left = 6 if selected else 2
	normal.set_content_margin_all(10)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = UiKit.WHITE
	hover.border_color = UiKit.MINT
	hover.border_width_left = 6
	target.add_theme_stylebox_override("normal", normal)
	target.add_theme_stylebox_override("hover", hover)
	target.add_theme_stylebox_override("focus", hover)
	target.add_theme_stylebox_override("pressed", hover)
	var text := UiKit.INK if selected else Color(0.92, 0.95, 1.0)
	target.add_theme_color_override("font_color", text)
	target.add_theme_color_override("font_hover_color", UiKit.INK)
	target.add_theme_color_override("font_focus_color", UiKit.INK)
	target.add_theme_color_override("font_pressed_color", UiKit.INK)
	target.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	if UiKit.light:
		normal.bg_color = Color(0, 0, 0, 0.05) if not selected else Color(1.0, 0.9, 0.78)
		normal.border_color = UiKit.RED if selected else Color(0, 0, 0, 0.14)
		hover.bg_color = UiKit.RED
		hover.border_color = UiKit.GOLD
		target.add_theme_color_override("font_color", UiKit.TEXT)
		for state in ["font_hover_color", "font_focus_color", "font_pressed_color"]:
			target.add_theme_color_override(state, Color.WHITE)
		target.add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0.3))
	# Se agranda un poco al pasar el cursor o enfocarlo (pedido de Fernando el
	# 2026-10-10, ronda 3: botones de toda la interfaz).
	UiKit._grow_on_focus(target)


## Píldora con el nombre del tipo en su color.
static func type_pill(type: int) -> PanelContainer:
	return UiKit.type_chip(type)


## Barra de color (estadísticas, vida) con su ancho máximo.
static func bar(ratio: float, width: float, color: Color, height: float = 12.0) -> Control:
	var progress := UiKit.bar(ratio, width, color, height)
	progress.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return progress


static func texture_rect(texture: Texture2D, size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.custom_minimum_size = size
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return rect


## Sprite de frente Gen 5 de la especie (o su cuadro del overworld si no hay).
static func front_sprite(species: SpeciesData, shiny: bool = false) -> Texture2D:
	var path := "res://art/pokemon/%s/%s.png" % [species.identifier, "front_shiny" if shiny else "front"]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return overworld_icon(species, shiny)


## Primer cuadro (de frente) de la hoja del overworld, como ícono de lista.
static func overworld_icon(species: SpeciesData, shiny: bool = false) -> Texture2D:
	var sheet := species.overworld_sheet_shiny if shiny and species.overworld_sheet_shiny != null else species.overworld_sheet
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(0, 0, species.overworld_cell, species.overworld_cell)
	return atlas


static func species(identifier: String) -> SpeciesData:
	var path := "res://creatures/data/species/%s.tres" % identifier
	return load(path) as SpeciesData if ResourceLoader.exists(path) else null


## Estadística base comprimida hacia el promedio (equilibrio sin niveles):
## 70 + (base − 70) × 0.5. Ver docs/sistemas/movimientos_y_crecimiento.md.
static func effective_stat(base: int) -> float:
	return 70.0 + (base - 70.0) * 0.5
