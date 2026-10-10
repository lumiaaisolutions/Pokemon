class_name RadarChart
extends Control
## Gráfica de estadísticas en hexágono (PS arriba, luego Ataque, Defensa, Velocidad,
## Def. Esp. y At. Esp. en sentido horario, como en Escarlata/Púrpura y Z-A). Cada eje
## muestra su nombre y una calificación (Bajo, Bueno, Notable, Inmejorable).

const AXES := ["PS", "Ataque", "Defensa", "Velocidad", "Def. Esp.", "At. Esp."]
const KEYS := ["hp", "attack", "defense", "speed", "sp_defense", "sp_attack"]

## Valores de 0 a 1 por eje (en el orden de AXES).
var values: Array[float] = [0, 0, 0, 0, 0, 0]
## Textos bajo cada nombre (p. ej. "Notable" o "77").
var notes: Array[String] = ["", "", "", "", "", ""]
var fill_color := Color(0.72, 0.95, 0.45, 0.75)


static func grade(value: float) -> String:
	if value >= 0.78:
		return "Inmejorable"
	if value >= 0.66:
		return "Notable"
	if value >= 0.55:
		return "Bueno"
	return "Normal"


func _init() -> void:
	custom_minimum_size = Vector2(380, 330)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5 + Vector2(0, 8)
	var radius := minf(size.x, size.y) * 0.3
	var font := UiKit.font(true)
	# Anillos de fondo.
	for ring in [1.0, 0.66, 0.33]:
		draw_colored_polygon(_points(center, radius * ring, [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]), _tone(0.06 if ring < 1.0 else 0.1))
	var outline := _points(center, radius, [1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
	draw_polyline(outline + PackedVector2Array([outline[0]]), _tone(0.3), 2.0)
	for p in outline:
		draw_line(center, p, _tone(0.12), 1.0)
	# Valores.
	var shape := _points(center, radius, values)
	draw_colored_polygon(shape, Color(0.95, 0.35, 0.35, 0.55) if UiKit.light else fill_color)
	draw_polyline(shape + PackedVector2Array([shape[0]]), UiKit.RED if UiKit.light else Color(0.9, 1.0, 0.7), 2.5)
	# Nombres y calificaciones.
	for i in 6:
		var angle := -PI / 2 + TAU * i / 6.0
		var at := center + Vector2(cos(angle), sin(angle)) * (radius + 46)
		var name: String = AXES[i]
		var width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_string(font, at + Vector2(-width * 0.5, -4), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UiKit.ink(Color(0.92, 0.95, 1.0)))
		var note: String = notes[i]
		var note_width := font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(font, at + Vector2(-note_width * 0.5, 18), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UiKit.RED_DARK if UiKit.light else UiKit.MINT)


## Líneas de fondo: blancas sobre oscuro, grises sobre el estilo claro.
func _tone(alpha: float) -> Color:
	return Color(0, 0, 0, alpha) if UiKit.light else Color(1, 1, 1, alpha)


func _points(center: Vector2, radius: float, scales: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		var angle := -PI / 2 + TAU * i / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius * clampf(float(scales[i]), 0.05, 1.0))
	return points


## Llena la gráfica con las estadísticas de un Pokémon (base equilibrada + entrenamiento).
func set_species(species: SpeciesData, training: Dictionary = {}) -> void:
	for i in 6:
		var base := float(species.get(KEYS[i]))
		var effective := MenuStyle.effective_stat(int(base)) + float(training.get(KEYS[i], 0))
		values[i] = clampf(effective / 120.0, 0.05, 1.0)
		notes[i] = "%d · %s" % [int(effective), grade(values[i])]
	queue_redraw()
