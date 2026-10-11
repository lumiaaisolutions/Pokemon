class_name RotomCharacter
extends Control
## El Rotom Teléfono de la app Rotom Móvil (pedido de Fernando, 2026-10-11: "redibujarlo
## en pixel art estilo BW2"; la versión anterior eran vectores lisos con antialiasing,
## ver docs/decisiones_sin_preguntar.md). Se pinta pixel a pixel sobre una Image/
## ImageTexture de baja resolución (GRID) y se muestra en un TextureRect con filtro
## NEAREST, para que se vea con los bordes duros de un sprite en vez de liso. Cuerpo
## naranja-rojo con contorno oscuro, ojos celestes ovalados con borde blanco que
## parpadean solos, rayo arriba y abajo y cámara azul en la esquina; conserva el
## parpadeo, la sonrisa y la entrada flotando del dibujo anterior.

const GRID := Vector2i(36, 44)
const PIXEL_SCALE := 6.0

const OUTLINE := Color(0.22, 0.08, 0.06)
const BODY := Color(0.93, 0.32, 0.16)
const BODY_LIGHT := Color(0.99, 0.5, 0.26)
const EDGE := Color(0.08, 0.07, 0.09)
const EYE_WHITE := Color(0.97, 0.98, 1.0)
const EYE_SKY := Color(0.42, 0.85, 0.98)
const CAM_RING := Color(0.22, 0.26, 0.33)
const CAM_BLUE := Color(0.32, 0.68, 0.92)
const BOLT := Color(0.98, 0.84, 0.25)
const NONE := Color(0, 0, 0, 0)

const BODY_OUTER := Rect2(4, 11, 28, 24)
const BODY_INNER := Rect2(6, 13, 24, 20)
const EDGE_RECT := Rect2(26, 14, 4, 18)
const HIGHLIGHT := Vector2(10, 18)
const CAMERA_AT := Vector2(28, 15)
const EYE_LEFT := Vector2(12, 22)
const EYE_RIGHT := Vector2(24, 22)
const MOUTH_X0 := 13.0
const MOUTH_X1 := 23.0
const MOUTH_Y0 := 28.0
const MOUTH_DIP := 3.0

## Rayos de arriba y abajo (zigzag), en coordenadas de la cuadrícula GRID. static var
## porque Godot no acepta un PackedVector2Array armado con Vector2() como const.
static var BOLT_TOP := PackedVector2Array([Vector2(20, 1), Vector2(15, 7), Vector2(19, 7), Vector2(14, 13), Vector2(24, 13), Vector2(20, 7), Vector2(25, 7)])

## true mientras haya algo que celebrar (actividad cumplida, logro del día…): sonríe y
## los ojos se entrecierran de gusto.
var happy := false:
	set(value):
		if happy != value and value:
			_react_bounce = 1.0
		happy = value
		_dirty = true

var _bob := 0.0
var _eyes_closed := false
var _blink_timer := 0.0
var _blink_next := 0.0
var _react_bounce := 0.0
var _dirty := true
var _view: TextureRect


func _ready() -> void:
	custom_minimum_size = Vector2(220, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blink_next = randf_range(1.5, 4.0)
	_view = TextureRect.new()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_view)
	_redraw()
	# Entra flotando: cae suave desde arriba con un rebote.
	modulate.a = 0.0
	position.y -= 40.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.45)
	tween.tween_property(self, "position:y", position.y + 40.0, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_bob += delta
	var changed := false
	if _eyes_closed:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_eyes_closed = false
			_blink_next = randf_range(2.0, 5.0)
			changed = true
	else:
		_blink_next -= delta
		if _blink_next <= 0.0:
			_eyes_closed = true
			_blink_timer = 0.17
			changed = true
	if _react_bounce > 0.0:
		_react_bounce = maxf(_react_bounce - delta * 1.4, 0.0)
	if changed or _dirty:
		_dirty = false
		_redraw()
	# El vaivén y el rebote al reaccionar mueven el sprite ya pintado (no hace falta
	# regenerar la imagen por esto: es más barato mover el nodo).
	_view.position.y = sin(_bob * 1.6) * 3.0 + _react_bounce * sin(_bob * 14.0) * 5.0


## Pinta la Image pixel por pixel (estilo sprite, sin antialiasing) y la sube a un
## ImageTexture que el TextureRect muestra con filtro NEAREST.
func _redraw() -> void:
	var img := Image.create(GRID.x, GRID.y, false, Image.FORMAT_RGBA8)
	for y in GRID.y:
		for x in GRID.x:
			img.set_pixel(x, y, _pixel_color(Vector2(x + 0.5, y + 0.5)))
	_view.texture = ImageTexture.create_from_image(img)


func _pixel_color(p: Vector2) -> Color:
	# Ojos (van encima del cuerpo).
	for eye_center in [EYE_LEFT, EYE_RIGHT]:
		var eye := _eye_pixel(p, eye_center)
		if eye.a > 0.0:
			return eye
	# Rayos de arriba y abajo (fuera del cuerpo).
	if _point_in_poly(p, BOLT_TOP) or _point_in_poly(p, _mirror_bolt()):
		return BOLT
	# Cámara (esquina superior derecha, fuera del cuerpo).
	var cam_d := p.distance_to(CAMERA_AT)
	if cam_d <= 3.2:
		return Color(1, 1, 1, 0.85) if p.distance_to(CAMERA_AT + Vector2(-0.8, -0.8)) <= 0.9 else CAM_BLUE
	elif cam_d <= 4.4:
		return CAM_RING
	# Cuerpo (borde oscuro, relleno, franja oscura, brillo y sonrisa).
	if _rounded_rect_contains(p, BODY_OUTER, 6.0):
		if not _rounded_rect_contains(p, BODY_INNER, 4.0):
			return OUTLINE
		if BODY_INNER.grow(-0.0).has_point(p) and EDGE_RECT.has_point(p):
			return EDGE
		if happy and _on_smile(p):
			return OUTLINE
		if p.distance_to(HIGHLIGHT) <= 5.0:
			return BODY_LIGHT
		return BODY
	return NONE


func _eye_pixel(p: Vector2, center: Vector2) -> Color:
	var d := p.distance_to(center)
	if d > 5.2:
		return NONE
	if _eyes_closed:
		if absf(p.y - center.y) <= 1.0 and absf(p.x - center.x) <= 4.6:
			return OUTLINE
		return NONE
	if d > 4.3:
		return OUTLINE
	var squint := 1.8 if happy else 4.0
	if absf(p.y - center.y) <= squint and absf(p.x - center.x) <= 3.4:
		if p.distance_to(center + Vector2(-1.3, -squint * 0.5 - 0.3)) <= 1.0:
			return Color(1, 1, 1, 0.9)
		return EYE_SKY
	return EYE_WHITE


func _on_smile(p: Vector2) -> bool:
	if p.x < MOUTH_X0 or p.x > MOUTH_X1:
		return false
	var t := (p.x - MOUTH_X0) / (MOUTH_X1 - MOUTH_X0)
	var mouth_y := MOUTH_Y0 + MOUTH_DIP * sin(PI * t)
	return absf(p.y - mouth_y) <= 0.9


func _mirror_bolt() -> PackedVector2Array:
	var mirrored := PackedVector2Array()
	for point in BOLT_TOP:
		mirrored.append(Vector2(point.x, float(GRID.y) - point.y))
	return mirrored


## Rectángulo con esquinas redondeadas (igual que StyleBoxFlat.set_corner_radius_all,
## pero evaluado pixel a pixel para pintar la Image).
func _rounded_rect_contains(p: Vector2, rect: Rect2, r: float) -> bool:
	if not rect.has_point(p):
		return false
	var inner := rect.grow(-r)
	if inner.has_point(p):
		return true
	var cx := clampf(p.x, inner.position.x, inner.position.x + inner.size.x)
	var cy := clampf(p.y, inner.position.y, inner.position.y + inner.size.y)
	return p.distance_to(Vector2(cx, cy)) <= r


## Punto dentro de polígono (ray casting), para los rayos.
func _point_in_poly(p: Vector2, poly: PackedVector2Array) -> bool:
	var inside := false
	var j := poly.size() - 1
	for i in poly.size():
		var a := poly[i]
		var b := poly[j]
		if (a.y > p.y) != (b.y > p.y):
			var slope := (p.y - a.y) / (b.y - a.y)
			if p.x < a.x + slope * (b.x - a.x):
				inside = not inside
		j = i
	return inside
