class_name MenuIcon
extends Control
## Ícono grande del menú al estilo Pokopia (acordado con Fernando el 2026-10-10):
## dibujado con vectores (formas redondeadas, colores vivos y contorno oscuro), nítido a
## cualquier tamaño. Al tener el foco se dibuja un halo amarillo y rebota.

const OUTLINE := Color(0.22, 0.2, 0.26)

var icon_name := ""
var focused := false:
	set(value):
		focused = value
		queue_redraw()
var _bounce := 0.0


static func make(name: String, size: float = 96.0) -> MenuIcon:
	var icon := MenuIcon.new()
	icon.icon_name = name
	icon.custom_minimum_size = Vector2(size, size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _process(delta: float) -> void:
	if focused:
		_bounce += delta
		queue_redraw()
	elif _bounce != 0.0:
		_bounce = 0.0
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	if focused:
		draw_circle(c, s * 0.5, Color(1.0, 0.84, 0.2))
		draw_circle(c, s * 0.46, Color(1.0, 0.9, 0.45))
	var lift := -absf(sin(_bounce * 6.0)) * s * 0.05 if focused else 0.0
	draw_set_transform(c + Vector2(0, lift), 0.0, Vector2.ONE * s / 100.0)
	match icon_name:
		"Equipo", "Pokémon":
			_ball(Color(0.9, 0.2, 0.22))
		"Mochila":
			_bag()
		"Pokédex":
			_dex()
		"Caja", "Cajas":
			_chest()
		"Rotom":
			_rotom()
		"Foto":
			_camera()
		"Mapa":
			_map()
		"Logros":
			_trophy()
		"Dinero":
			_coin()
		"Ficha":
			_card()
		"Controles":
			_pad()
		"Opciones":
			_gears()
		"Guardar":
			_book()
		_:
			_ball(Color(0.5, 0.5, 0.6))
	draw_set_transform(Vector2.ZERO)


# Todas las formas en un cuadro de -50..50 (centro en 0, 0).

func _round_rect(rect: Rect2, radius: float, color: Color, outline := true) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	if outline:
		style.border_color = OUTLINE
		style.set_border_width_all(4)
	style.anti_aliasing = true
	draw_style_box(style, rect)


func _disc(at: Vector2, radius: float, color: Color, outline := true) -> void:
	if outline:
		draw_circle(at, radius + 3.5, OUTLINE)
	draw_circle(at, radius, color)


func _ball(top: Color) -> void:
	_disc(Vector2.ZERO, 38, Color(0.97, 0.97, 0.97))
	var arc := PackedVector2Array()
	for i in 33:
		var a := PI + PI * i / 32.0
		arc.append(Vector2(cos(a), sin(a)) * 38)
	draw_colored_polygon(arc, top)
	draw_rect(Rect2(-38, -4, 76, 8), OUTLINE)
	_disc(Vector2.ZERO, 11, Color(0.97, 0.97, 0.97))
	draw_circle(Vector2(-14, -22), 7, Color(1, 1, 1, 0.55))


func _bag() -> void:
	_round_rect(Rect2(-34, -24, 68, 62), 18, Color(0.95, 0.55, 0.2))
	_round_rect(Rect2(-20, -40, 40, 22), 10, Color(0.0, 0, 0, 0), true)
	_round_rect(Rect2(-24, 6, 48, 24), 8, Color(0.98, 0.72, 0.35))
	draw_rect(Rect2(-5, 2, 10, 10), Color(1.0, 0.85, 0.3))
	draw_rect(Rect2(-5, 2, 10, 10), OUTLINE, false, 3.0)


func _dex() -> void:
	_round_rect(Rect2(-30, -40, 60, 80), 14, Color(0.9, 0.22, 0.25))
	_round_rect(Rect2(-20, -26, 40, 30), 6, Color(0.6, 0.9, 0.95))
	_disc(Vector2(-14, -33), 4, Color(0.5, 0.85, 1.0), false)
	_disc(Vector2(-12, 22), 6, Color(1.0, 0.85, 0.3))
	_round_rect(Rect2(0, 16, 18, 10), 4, Color(0.3, 0.3, 0.35), false)


func _chest() -> void:
	_round_rect(Rect2(-40, -14, 80, 50), 10, Color(0.95, 0.55, 0.3))
	_round_rect(Rect2(-40, -36, 80, 28), 14, Color(0.98, 0.65, 0.35))
	draw_rect(Rect2(-40, -10, 80, 6), OUTLINE)
	_disc(Vector2(0, -4), 9, Color(0.45, 0.45, 0.55))
	_disc(Vector2(0, -4), 4, Color(0.85, 0.85, 0.9), false)


func _rotom() -> void:
	_round_rect(Rect2(-28, -40, 56, 80), 16, Color(0.95, 0.4, 0.3))
	_round_rect(Rect2(-20, -30, 40, 50), 8, Color(0.75, 0.92, 1.0))
	_disc(Vector2(-8, -10), 5, Color(0.25, 0.55, 0.95), false)
	_disc(Vector2(8, -10), 5, Color(0.25, 0.55, 0.95), false)
	draw_arc(Vector2(0, 2), 8, 0.2, PI - 0.2, 12, OUTLINE, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(28, -30), Vector2(44, -38), Vector2(36, -20)]), Color(0.6, 0.9, 1.0))


func _camera() -> void:
	_round_rect(Rect2(-42, -24, 84, 58), 14, Color(0.4, 0.5, 0.95))
	_round_rect(Rect2(-16, -36, 30, 16), 6, Color(0.35, 0.42, 0.85))
	_disc(Vector2(0, 5), 20, Color(0.25, 0.25, 0.35))
	_disc(Vector2(0, 5), 13, Color(0.55, 0.85, 1.0), false)
	draw_circle(Vector2(-5, 0), 4, Color(1, 1, 1, 0.8))
	_disc(Vector2(30, -14), 4, Color(1.0, 0.85, 0.3), false)


func _map() -> void:
	var panels := [Color(0.55, 0.85, 0.5), Color(0.98, 0.9, 0.6), Color(0.55, 0.85, 0.5)]
	for i in 3:
		var x := -42 + i * 28
		var shift := -6 if i % 2 == 0 else 6
		_round_rect(Rect2(x, -32 + shift, 28, 66), 4, panels[i])
	draw_circle(Vector2(6, -2), 9, Color(0.9, 0.25, 0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(-2, 2), Vector2(14, 2), Vector2(6, 16)]), Color(0.9, 0.25, 0.3))
	draw_circle(Vector2(6, -2), 3.5, Color.WHITE)


func _trophy() -> void:
	_round_rect(Rect2(-26, -38, 52, 44), 18, Color(1.0, 0.8, 0.2))
	draw_arc(Vector2(-28, -18), 12, PI * 0.5, PI * 1.5, 12, OUTLINE, 5.0)
	draw_arc(Vector2(28, -18), 12, -PI * 0.5, PI * 0.5, 12, OUTLINE, 5.0)
	_round_rect(Rect2(-7, 4, 14, 18), 2, Color(0.95, 0.7, 0.15))
	_round_rect(Rect2(-24, 22, 48, 16), 6, Color(0.6, 0.4, 0.25))
	draw_circle(Vector2(-10, -26), 5, Color(1, 1, 1, 0.6))


func _coin() -> void:
	_disc(Vector2(6, 6), 30, Color(0.95, 0.7, 0.15))
	_disc(Vector2(-6, -6), 30, Color(1.0, 0.85, 0.3))
	draw_circle(Vector2(-6, -6), 20, Color(1.0, 0.78, 0.2))
	draw_string(UiKit.font(true), Vector2(-17, 7), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, OUTLINE)


func _card() -> void:
	_round_rect(Rect2(-44, -30, 88, 60), 10, Color(0.97, 0.95, 0.9))
	_round_rect(Rect2(-36, -20, 28, 36), 6, Color(0.6, 0.8, 1.0))
	_disc(Vector2(-22, -8), 7, Color(0.95, 0.75, 0.6), false)
	for i in 3:
		draw_rect(Rect2(0, -16 + i * 12, 34 - i * 8, 5), Color(0.6, 0.6, 0.66))
	draw_rect(Rect2(-44, 18, 88, 6), Color(0.9, 0.25, 0.3))


func _pad() -> void:
	_round_rect(Rect2(-44, -22, 88, 46), 22, Color(0.55, 0.55, 0.65))
	draw_rect(Rect2(-30, -4, 22, 8), OUTLINE)
	draw_rect(Rect2(-23, -11, 8, 22), OUTLINE)
	_disc(Vector2(18, -6), 5, Color(0.95, 0.35, 0.35), false)
	_disc(Vector2(30, 4), 5, Color(0.35, 0.65, 0.95), false)


func _gears() -> void:
	_gear(Vector2(-12, -8), 24, Color(0.7, 0.72, 0.8))
	_gear(Vector2(22, 20), 16, Color(0.6, 0.62, 0.7))


func _gear(at: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		var r := radius + (6.0 if (i / 3) % 2 == 0 else 0.0)
		points.append(at + Vector2(cos(a), sin(a)) * r)
	var outline := PackedVector2Array()
	for p in points:
		outline.append(at + (p - at) * ((p - at).length() + 3.5) / (p - at).length())
	draw_colored_polygon(outline, OUTLINE)
	draw_colored_polygon(points, color)
	_disc(at, radius * 0.38, Color(0.97, 0.97, 0.97))


func _book() -> void:
	_round_rect(Rect2(-34, -40, 68, 80), 8, Color(0.4, 0.75, 0.45))
	_round_rect(Rect2(-22, -26, 44, 26), 6, Color(0.95, 0.95, 0.88))
	draw_rect(Rect2(-34, -40, 10, 80), Color(0.3, 0.6, 0.35))
	draw_colored_polygon(PackedVector2Array([Vector2(12, -40), Vector2(24, -40), Vector2(24, -24), Vector2(18, -30), Vector2(12, -24)]), Color(0.95, 0.3, 0.3))
