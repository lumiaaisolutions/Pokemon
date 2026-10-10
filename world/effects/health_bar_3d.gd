class_name HealthBar3D
extends Node3D
## Recuadro de vida flotante sobre un actor, al estilo de los combates de B2W2: el
## nombre del Pokémon encima y, debajo, un recuadro con la etiqueta "PS" (puntos de
## salud) y la barra verde, amarilla o roja según lo que le queda. Se dibuja en pixel
## art y solo se ve si no está llena.

## Tamaño del recuadro en píxeles y metros por píxel.
const PANEL_W := 56
const PANEL_H := 11
const PIXEL := 0.032
const BAR_X := 15
const BAR_W := 38
## Muy cerca de la cámara taparía la vista: se oculta.
const HIDE_NEAR_CAMERA := 4.5

const FRAME := Color(0.1, 0.1, 0.13)
const PANEL := Color(0.97, 0.96, 0.9)
const TAG := Color(0.95, 0.6, 0.15)
const EMPTY := Color(0.3, 0.3, 0.34)
const GREEN := Color(0.3, 0.85, 0.4)
const YELLOW := Color(0.98, 0.8, 0.2)
const RED := Color(0.92, 0.27, 0.22)
## Letras de 3×5 para "PS".
const LETTER_P := ["XX.", "X.X", "XX.", "X..", "X.."]
const LETTER_S := [".XX", "X..", ".X.", "..X", "XX."]

var _panel: Sprite3D
var _name: Label3D
var _ratio := 1.0
var _shown_step := -1


static func create(height: float, display_name: String = "") -> HealthBar3D:
	var bar := HealthBar3D.new()
	bar.name = "HealthBar"
	bar.position.y = height
	bar._build(display_name)
	bar.visible = false
	return bar


func _build(display_name: String) -> void:
	_panel = Sprite3D.new()
	_panel.pixel_size = PIXEL
	_panel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_panel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_panel.shaded = false
	_panel.no_depth_test = true
	_panel.render_priority = 2
	_panel.layers = 2
	add_child(_panel)
	_name = Label3D.new()
	_name.text = display_name
	_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name.font_size = 56
	_name.outline_size = 10
	_name.pixel_size = 0.005
	_name.no_depth_test = true
	_name.render_priority = 3
	_name.position.y = PANEL_H * PIXEL * 0.5 + 0.13
	_name.visible = display_name != ""
	add_child(_name)
	_redraw()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var near := camera != null and camera.global_position.distance_to(global_position) < HIDE_NEAR_CAMERA
	visible = _ratio < 0.999 and not near


## ratio en [0, 1].
func set_ratio(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	visible = _ratio < 0.999
	_redraw()


func _redraw() -> void:
	var filled := int(round(BAR_W * _ratio))
	if filled == _shown_step:
		return
	_shown_step = filled
	var image := Image.create_empty(PANEL_W, PANEL_H, false, Image.FORMAT_RGBA8)
	# Marco oscuro con esquinas redondeadas y fondo claro.
	for y in PANEL_H:
		for x in PANEL_W:
			var corner := (x == 0 or x == PANEL_W - 1) and (y == 0 or y == PANEL_H - 1)
			if corner:
				continue
			var border := x == 0 or y == 0 or x == PANEL_W - 1 or y == PANEL_H - 1
			image.set_pixel(x, y, FRAME if border else PANEL)
	# Etiqueta "PS" en naranja.
	for y in range(2, PANEL_H - 2):
		for x in range(2, BAR_X - 2):
			image.set_pixel(x, y, TAG)
	_letter(image, LETTER_P, 3, 3)
	_letter(image, LETTER_S, 7, 3)
	# Barra: hueco oscuro, relleno por color y un brillo arriba.
	var color := GREEN if _ratio > 0.5 else (YELLOW if _ratio > 0.2 else RED)
	for y in range(3, PANEL_H - 3):
		for x in BAR_W:
			var c := color if x < filled else EMPTY
			if y == 3 and x < filled:
				c = c.lightened(0.35)
			image.set_pixel(BAR_X + x, y, c)
	for x in range(BAR_X - 1, BAR_X + BAR_W + 1):
		image.set_pixel(x, 2, FRAME)
		image.set_pixel(x, PANEL_H - 3, FRAME)
	for y in range(2, PANEL_H - 2):
		image.set_pixel(BAR_X - 1, y, FRAME)
		image.set_pixel(BAR_X + BAR_W, y, FRAME)
	_panel.texture = ImageTexture.create_from_image(image)


func _letter(image: Image, rows: Array, x0: int, y0: int) -> void:
	for y in rows.size():
		for x in 3:
			if rows[y][x] == "X":
				image.set_pixel(x0 + x, y0 + y, Color.WHITE)
