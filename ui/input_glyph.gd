class_name InputGlyph
extends RefCounted
## Íconos de botón para la UI según el último dispositivo (InputHints): símbolos de
## PlayStation dibujados en pixel art (✕ ○ □ △ con sus colores), gatillos y cruceta
## como píldoras, teclas como teclado y el mouse con el botón resaltado.

const SCALE := 3
const PS_COLORS := {
	JOY_BUTTON_A: Color(0.45, 0.65, 1.0), JOY_BUTTON_B: Color(1.0, 0.4, 0.45),
	JOY_BUTTON_X: Color(0.95, 0.55, 0.85), JOY_BUTTON_Y: Color(0.4, 0.9, 0.7),
}
const PS_SHAPES := {
	JOY_BUTTON_A: ["X.....X", ".X...X.", "..X.X..", "...X...", "..X.X..", ".X...X.", "X.....X"],
	JOY_BUTTON_B: ["..XXX..", ".X...X.", "X.....X", "X.....X", "X.....X", ".X...X.", "..XXX.."],
	JOY_BUTTON_X: ["XXXXXXX", "X.....X", "X.....X", "X.....X", "X.....X", "X.....X", "XXXXXXX"],
	JOY_BUTTON_Y: ["...X...", "..X.X..", "..X.X..", ".X...X.", ".X...X.", "X.....X", "XXXXXXX"],
}
const MOUSE_SHAPE := [".XXXXX.", "XLLXRRX", "XLLXRRX", "XXXXXXX", "X.....X", "X.....X", "X.....X", ".XXXXX."]

static var _cache := {}


## Control con el ícono del botón de action en el dispositivo actual.
## pad: -1 = el último dispositivo usado, 0 = teclado y mouse, 1 = mando.
static func make(action: StringName, pad: int = -1) -> Control:
	var event := _event_for(action, pad)
	if event is InputEventJoypadButton and PS_SHAPES.has((event as InputEventJoypadButton).button_index):
		return _image_glyph(_ps_texture((event as InputEventJoypadButton).button_index), Color(0.12, 0.12, 0.16), true)
	if event is InputEventMouseButton:
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT:
			return _image_glyph(_mouse_texture(button == MOUSE_BUTTON_LEFT), Color(0.92, 0.92, 0.95), false)
	return _text_glyph(InputHints.hint(action, pad), event is InputEventKey or event is InputEventMouseButton)


## Ícono de texto libre (p. ej. "WASD" o "Stick izq.").
static func text(label: String, keycap: bool) -> Control:
	return _text_glyph(label, keycap)


## Fila "[ícono] texto" para leyendas y tarjetas.
## action puede ser una acción del Input Map o un Control ya hecho (ícono libre).
static func row(action: Variant, text: String, font_size: int = 20, pad: int = -1) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(action if action is Control else make(action, pad))
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(label)
	return box


static func _event_for(action: StringName, pad: int = -1) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	var use_pad := InputHints.gamepad if pad < 0 else pad == 1
	for event in InputMap.action_get_events(action):
		if use_pad and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			return event
		if not use_pad and (event is InputEventKey or event is InputEventMouseButton):
			return event
	return null


static func _image_glyph(texture: Texture2D, background: Color, round: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(14 if round else 5)
	style.set_border_width_all(2)
	style.border_color = Color(0, 0, 0, 0.8)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := TextureRect.new()
	rect.texture = texture
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.custom_minimum_size = texture.get_size() * SCALE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(rect)
	return panel


static func _text_glyph(text: String, keycap: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.9, 0.92) if keycap else Color(0.12, 0.12, 0.16)
	style.set_corner_radius_all(5 if keycap else 12)
	style.set_border_width_all(2)
	style.border_width_bottom = 5 if keycap else 2
	style.border_color = Color(0.35, 0.35, 0.4) if keycap else Color(0, 0, 0, 0.8)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12) if keycap else Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


static func _ps_texture(button: int) -> Texture2D:
	var key := "ps%d" % button
	if not _cache.has(key):
		_cache[key] = _pixels(PS_SHAPES[button], {"X": PS_COLORS[button]})
	return _cache[key]


static func _mouse_texture(left: bool) -> Texture2D:
	var key := "mouse%s" % left
	if not _cache.has(key):
		var on := Color(1.0, 0.75, 0.2)
		var off := Color(0.75, 0.75, 0.8)
		_cache[key] = _pixels(MOUSE_SHAPE, {"X": Color(0.2, 0.2, 0.25), "L": on if left else off, "R": off if left else on})
	return _cache[key]


static func _pixels(rows: Array, palette: Dictionary) -> Texture2D:
	var width: int = (rows[0] as String).length()
	var image := Image.create_empty(width, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in width:
			var c: String = rows[y][x]
			if palette.has(c):
				image.set_pixel(x, y, palette[c])
	return ImageTexture.create_from_image(image)
