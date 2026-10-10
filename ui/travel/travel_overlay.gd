class_name TravelOverlay
extends CanvasLayer
## Animación corta del viaje entre regiones: el barco cruza el mar o el avión vuela sobre
## las nubes, con el nombre de la región de destino. Vive en la raíz del árbol para seguir
## visible mientras carga el mundo nuevo, y se desvanece al llegar (finish).

var boat := true
var destination := ""
var _time := 0.0
var _fading := -1.0
var _canvas: Control
var _title: Label


func _ready() -> void:
	layer = 90
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_scene)
	add_child(_canvas)
	_title = UiKit.label(("Rumbo a la %s…" if boat else "Volando a la %s…") % destination, 40, Color.WHITE, true)
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(-400, 70)
	_title.size = Vector2(800, 60)
	_title.add_theme_color_override("font_outline_color", Color(0.1, 0.15, 0.3))
	_title.add_theme_constant_override("outline_size", 10)
	add_child(_title)
	AudioBus.play_sfx("save")


func finish() -> void:
	_fading = 0.0


func _process(delta: float) -> void:
	_time += delta
	if _fading >= 0.0:
		_fading += delta
		# Espera a que cargue el mundo (el primer cuadro tras la carga) y se desvanece.
		var alpha := clampf(1.0 - (_fading - 0.6) / 1.0, 0.0, 1.0)
		_canvas.modulate.a = alpha
		_title.modulate.a = alpha
		if alpha <= 0.0:
			queue_free()
	_canvas.queue_redraw()


func _draw_scene() -> void:
	var size := _canvas.size
	var t := _time
	if boat:
		_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.55)), Color(0.55, 0.78, 0.98))
		_canvas.draw_circle(Vector2(size.x * 0.8, size.y * 0.2), 46.0, Color(1.0, 0.92, 0.55))
		_canvas.draw_rect(Rect2(0, size.y * 0.55, size.x, size.y * 0.45), Color(0.15, 0.42, 0.72))
		# Olas.
		for row in 6:
			var y := size.y * (0.6 + row * 0.07)
			for k in 14:
				var x := fmod(k * 160.0 + t * (60.0 + row * 25.0), size.x + 160.0) - 80.0
				_canvas.draw_arc(Vector2(x, y), 22.0, PI * 1.1, PI * 1.9, 8, Color(0.75, 0.9, 1.0, 0.8), 4.0)
		# Barco: casco, cabina, chimenea y estela.
		var bx := lerpf(-260.0, size.x + 60.0, clampf(t / 4.0, 0.0, 1.0))
		var by := size.y * 0.58 + sin(t * 3.0) * 6.0
		for k in 5:
			_canvas.draw_circle(Vector2(bx - 40.0 - k * 34.0, by + 22.0), 10.0 - k, Color(1, 1, 1, 0.6 - k * 0.1))
		var hull := PackedVector2Array([Vector2(bx - 20, by - 10), Vector2(bx + 230, by - 10), Vector2(bx + 200, by + 34), Vector2(bx + 10, by + 34)])
		_canvas.draw_colored_polygon(hull, Color(0.9, 0.2, 0.22))
		_canvas.draw_rect(Rect2(bx + 10, by - 6, 210, 8), Color(0.98, 0.98, 0.98))
		_canvas.draw_rect(Rect2(bx + 50, by - 62, 120, 52), Color(0.98, 0.97, 0.94))
		for w in 4:
			_canvas.draw_rect(Rect2(bx + 60 + w * 28, by - 50, 16, 14), Color(0.35, 0.6, 0.9))
		_canvas.draw_rect(Rect2(bx + 130, by - 100, 26, 40), Color(0.2, 0.22, 0.3))
		_canvas.draw_rect(Rect2(bx + 130, by - 100, 26, 10), Color(0.9, 0.2, 0.22))
		for k in 3:
			_canvas.draw_circle(Vector2(bx + 143 - k * 18 - fmod(t * 20.0, 18.0), by - 112 - k * 16), 10.0 + k * 3, Color(0.85, 0.85, 0.9, 0.7 - k * 0.2))
	else:
		_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.45, 0.7, 0.98))
		_canvas.draw_rect(Rect2(0, size.y * 0.5, size.x, size.y * 0.5), Color(0.62, 0.82, 1.0))
		# Nubes que pasan.
		for k in 10:
			var speed := 120.0 + (k % 3) * 80.0
			var x := size.x + 200.0 - fmod(k * 260.0 + t * speed, size.x + 400.0)
			var y := size.y * (0.15 + (k * 37 % 70) / 100.0)
			for c in 4:
				_canvas.draw_circle(Vector2(x + c * 34.0, y + (12.0 if c % 2 == 0 else 0.0)), 30.0 + (c % 2) * 10.0, Color(1, 1, 1, 0.9))
		# Avión: fuselaje, alas, cola y ventanas.
		var px := lerpf(-260.0, size.x + 60.0, clampf(t / 4.0, 0.0, 1.0))
		var py := size.y * 0.42 + sin(t * 2.0) * 10.0
		_canvas.draw_rect(Rect2(px, py - 18, 220, 36), Color(0.98, 0.98, 0.98))
		_canvas.draw_circle(Vector2(px + 220, py), 18.0, Color(0.98, 0.98, 0.98))
		_canvas.draw_colored_polygon(PackedVector2Array([Vector2(px + 90, py), Vector2(px + 150, py), Vector2(px + 90, py + 70), Vector2(px + 60, py + 70)]), Color(0.85, 0.3, 0.3))
		_canvas.draw_colored_polygon(PackedVector2Array([Vector2(px + 100, py), Vector2(px + 150, py), Vector2(px + 110, py - 50), Vector2(px + 85, py - 50)]), Color(0.75, 0.25, 0.25))
		_canvas.draw_colored_polygon(PackedVector2Array([Vector2(px, py - 18), Vector2(px + 30, py - 18), Vector2(px + 5, py - 62), Vector2(px - 15, py - 62)]), Color(0.85, 0.3, 0.3))
		_canvas.draw_rect(Rect2(px, py + 6, 220, 6), Color(0.85, 0.3, 0.3))
		for w in 7:
			_canvas.draw_circle(Vector2(px + 50 + w * 22, py - 4), 5.0, Color(0.3, 0.55, 0.85))
