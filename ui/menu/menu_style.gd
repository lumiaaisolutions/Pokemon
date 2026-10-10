class_name MenuStyle
extends RefCounted
## Estilo compartido del menú: ventanas con borde pixel al estilo B2W2, etiquetas con
## contorno, botones que se iluminan con el foco y colores por tipo.

const ACCENT := Color(1.0, 0.85, 0.3)
const TEXT := Color(0.96, 0.96, 0.98)
const MUTED := Color(0.75, 0.8, 0.9)
const TYPE_NAMES := ["Normal", "Lucha", "Volador", "Veneno", "Tierra", "Roca", "Bicho", "Fantasma", "Acero",
		"Fuego", "Agua", "Planta", "Eléctrico", "Psíquico", "Hielo", "Dragón", "Siniestro", "Hada"]
const TEMPERAMENT_NAMES := ["Tranquilo", "Curioso", "Tímido", "Agresivo", "Territorial"]


static func panel(border: Color = Color(0.85, 0.88, 0.95), background: Color = Color(0.08, 0.1, 0.14, 0.94)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_border_width_all(4)
	style.border_color = border
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	return style


static func panel_container(border: Color = Color(0.85, 0.88, 0.95)) -> PanelContainer:
	var container := PanelContainer.new()
	container.add_theme_stylebox_override("panel", panel(border))
	return container


static func label(text: String, size: int = 20, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_outline_color", Color.BLACK)
	result.add_theme_constant_override("outline_size", 5)
	return result


static func wrapped(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var result := label(text, size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result


static func button(text: String, size: int = 20) -> Button:
	var result := Button.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	style_button(result)
	return result


static func style_button(target: Button, selected: bool = false) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.2, 0.32, 0.5, 0.95) if selected else Color(0.12, 0.15, 0.2, 0.95)
	normal.set_border_width_all(3)
	normal.border_color = ACCENT if selected else Color(0.55, 0.6, 0.7)
	normal.set_corner_radius_all(5)
	normal.set_content_margin_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.36, 0.56, 0.98)
	hover.border_color = ACCENT
	target.add_theme_stylebox_override("normal", normal)
	target.add_theme_stylebox_override("hover", hover)
	target.add_theme_stylebox_override("focus", hover)
	target.add_theme_stylebox_override("pressed", hover)


## Píldora con el nombre del tipo en su color.
static func type_pill(type: int) -> PanelContainer:
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = AttackProjectile.TYPE_COLORS.get(type, Color.GRAY).darkened(0.1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", style)
	pill.add_child(label(TYPE_NAMES[type] if type >= 0 and type < TYPE_NAMES.size() else "?", 16))
	return pill


## Barra de color (estadísticas, vida) con su ancho máximo.
static func bar(ratio: float, width: float, color: Color, height: float = 12.0) -> Control:
	var back := ColorRect.new()
	back.color = Color(0.2, 0.2, 0.25)
	back.custom_minimum_size = Vector2(width, height)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := ColorRect.new()
	fill.color = color
	fill.size = Vector2(width * clampf(ratio, 0.0, 1.0), height)
	back.add_child(fill)
	return back


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
