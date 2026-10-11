class_name SleepSkyOverlay
extends CanvasLayer
## Capa 2D sobre toda la pantalla para la escena de Dormir (pedido de Fernando el
## 2026-10-10, ronda 3: "el cielo pasa de noche a amanecer en ~4 s: estrellas, luna que
## baja, sol que sale"). El reloj del juego ya saltó a las 7:00 al llamar a
## GameState.sleep_until_morning() (CampManager.sleep); esta capa es un adorno encima de
## la cámara que simula ese amanecer sin tocar el ciclo real de día y noche de DayNight.
## Se puede saltar (CampManager mata el tween y llama a finish()).

const DURATION := 4.0

var _tint: ColorRect
var _moon: Control
var _sun: Control
var _stars: Array[ColorRect] = []
var _tween: Tween


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_tint = ColorRect.new()
	_tint.color = Color(0.03, 0.05, 0.14, 0.55)
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_tint)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 46:
		var star := ColorRect.new()
		star.color = Color(1, 1, 0.95, rng.randf_range(0.35, 0.95))
		star.size = Vector2.ONE * rng.randf_range(1.5, 3.0)
		star.position = Vector2(rng.randf_range(0.0, 1920.0), rng.randf_range(0.0, 500.0))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(star)
		_stars.append(star)
	_moon = _disc(Color(0.95, 0.93, 0.75), 46.0)
	_moon.position = Vector2(300, 90)
	root.add_child(_moon)
	_sun = _disc(Color(1.0, 0.75, 0.35), 54.0)
	_sun.position = Vector2(1600, 620)
	_sun.modulate.a = 0.0
	root.add_child(_sun)


func _disc(color: Color, diameter: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2.ONE * diameter
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.draw.connect(func() -> void: holder.draw_circle(Vector2.ONE * diameter * 0.5, diameter * 0.5, color))
	return holder


## Arranca la transición de ~4 s (estrellas que se apagan, luna que baja, sol que sube).
func start() -> void:
	_tween = create_tween()
	_tween.tween_property(_moon, "position:y", 90.0 + 260.0, DURATION * 0.65).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(_moon, "modulate:a", 0.0, DURATION * 0.65)
	_tween.parallel().tween_property(_sun, "position:y", 620.0 - 280.0, DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_sun, "modulate:a", 1.0, DURATION * 0.8)
	for star in _stars:
		_tween.parallel().tween_property(star, "modulate:a", 0.0, DURATION * 0.55).set_delay(DURATION * 0.2)
	_tween.parallel().tween_property(_tint, "color", Color(0.98, 0.78, 0.5, 0.0), DURATION)
	_tween.tween_callback(queue_free)


## Termina ya (saltar con E): deja la pantalla limpia y se borra.
func finish() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	if not is_queued_for_deletion():
		queue_free()
