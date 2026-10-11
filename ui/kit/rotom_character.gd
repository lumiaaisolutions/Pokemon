class_name RotomCharacter
extends Control
## El Rotom Teléfono de la app Rotom Móvil (pedido de Fernando, 2026-10-11): dibujado en
## vectores (mismo estilo que MenuIcon, nítido a cualquier tamaño: no hay sprite de BW2
## de este modelo para descargar sin pedir permiso por lote; ver
## docs/decisiones_sin_preguntar.md). Cuerpo naranja-rojo, ojos celestes ovalados con
## borde blanco que parpadean solos, cara redonda, un rayo arriba y otro abajo, cámara
## azul en una esquina y una franja oscura en el borde derecho (la "pantalla" que de
## lado se ve negra). Flota con un vaivén y sonríe cuando `happy` es true.

const OUTLINE := Color(0.32, 0.12, 0.08)
const BODY := Color(0.93, 0.38, 0.22)
const BODY_LIGHT := Color(0.98, 0.52, 0.3)
const EYE := Color(0.55, 0.9, 1.0)

## true mientras haya algo que celebrar (actividad cumplida, logro del día…): sonríe y
## los ojos se entrecierran de gusto.
var happy := false:
	set(value):
		if happy != value and value:
			_react_bounce = 1.0
		happy = value
		queue_redraw()

var _bob := 0.0
var _blink := 0.0
var _blink_next := 0.0
var _react_bounce := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(220, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blink_next = randf_range(1.5, 4.0)
	# Entra flotando: cae suave desde arriba con un rebote.
	modulate.a = 0.0
	position.y -= 40.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.45)
	tween.tween_property(self, "position:y", position.y + 40.0, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_bob += delta
	if _blink > 0.0:
		_blink = maxf(_blink - delta * 6.0, 0.0)
	else:
		_blink_next -= delta
		if _blink_next <= 0.0:
			_blink = 1.0
			_blink_next = randf_range(2.0, 5.0)
	if _react_bounce > 0.0:
		_react_bounce = maxf(_react_bounce - delta * 1.4, 0.0)
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var lift := sin(_bob * 1.6) * s * 0.035 + _react_bounce * sin(_bob * 14.0) * s * 0.05
	draw_set_transform(c + Vector2(0, lift), 0.0, Vector2.ONE * s / 100.0)
	# Franja del borde (la pantalla que de lado se ve negra).
	draw_colored_polygon(PackedVector2Array([Vector2(34, -30), Vector2(40, -26), Vector2(40, 26), Vector2(34, 30)]), Color(0.08, 0.07, 0.09))
	# Cuerpo redondeado.
	var body := StyleBoxFlat.new()
	body.bg_color = BODY
	body.set_corner_radius_all(30)
	body.border_color = OUTLINE
	body.set_border_width_all(4)
	body.anti_aliasing = true
	draw_style_box(body, Rect2(-38, -42, 76, 84))
	draw_circle(Vector2(-10, -24), 20, BODY_LIGHT)
	# Rayo de arriba.
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -42), Vector2(10, -42), Vector2(-2, -58), Vector2(14, -58), Vector2(-6, -78), Vector2(-4, -58), Vector2(-16, -58)]), Color(0.98, 0.84, 0.25))
	# Rayo de abajo (invertido).
	draw_colored_polygon(PackedVector2Array([Vector2(8, 42), Vector2(-10, 42), Vector2(2, 58), Vector2(-14, 58), Vector2(6, 78), Vector2(4, 58), Vector2(16, 58)]), Color(0.98, 0.84, 0.25))
	# Cámara azul (esquina superior derecha).
	draw_circle(Vector2(22, -28), 8, Color(0.25, 0.3, 0.38))
	draw_circle(Vector2(22, -28), 5, Color(0.35, 0.72, 0.95))
	draw_circle(Vector2(20, -30), 2, Color(1, 1, 1, 0.8))
	_face()
	draw_set_transform(Vector2.ZERO)


func _face() -> void:
	var blink := _blink > 0.0
	var squint := happy
	for side in [-1, 1]:
		var at := Vector2(14.0 * side, -6)
		if blink:
			draw_rect(Rect2(at - Vector2(10, 1.5), Vector2(20, 3)), Color.WHITE)
			draw_rect(Rect2(at - Vector2(10, 1.5), Vector2(20, 3)), OUTLINE, false, 2.0)
			continue
		var h := 11.0 if not squint else 6.0
		draw_circle(at, 12.5, OUTLINE)
		draw_circle(at, 11.0, Color.WHITE)
		var eye := StyleBoxFlat.new()
		eye.bg_color = EYE
		eye.set_corner_radius_all(int(h))
		draw_style_box(eye, Rect2(at.x - 8.5, at.y - h, 17, h * (0.6 if squint else 2.0)))
		draw_circle(at + Vector2(-3, -h * 0.5), 2.3, Color(1, 1, 1, 0.85))
	if happy:
		# Sonrisa pequeña.
		var points := PackedVector2Array()
		for i in 9:
			var t := i / 8.0
			points.append(Vector2(-9 + t * 18, 10 + sin(t * PI) * 5))
		for i in points.size() - 1:
			draw_line(points[i], points[i + 1], OUTLINE, 2.4)
