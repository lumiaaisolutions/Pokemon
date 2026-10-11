class_name StargazeOverlay
extends Control
## "Mirar las estrellas" (extra del campamento, pedido de Fernando el 2026-10-10 ronda 3):
## la cámara mira al cielo (CameraRig.look_at_sky) y aparece esta capa con constelaciones
## sencillas con forma de Pokémon dibujadas con puntos y líneas; algunas dan una pista.
## Se abre desde el menú de la tienda (ver CampManager.stargaze), solo de noche.

## Cada constelación: nombre, puntos (0..1 relativos a la pantalla) y las líneas que los
## unen (pares de índices). hint: si no es "", se muestra como pista al elegirla.
const CONSTELLATIONS: Array[Dictionary] = [
	{
		"name": "Umbreon",
		"points": [Vector2(0.28, 0.22), Vector2(0.24, 0.16), Vector2(0.32, 0.16), Vector2(0.22, 0.3), Vector2(0.34, 0.3), Vector2(0.28, 0.36)],
		"lines": [[0, 1], [0, 2], [0, 3], [0, 4], [3, 5], [4, 5]],
		"hint": "",
	},
	{
		"name": "Staryu",
		"points": [Vector2(0.55, 0.18), Vector2(0.6, 0.28), Vector2(0.7, 0.3), Vector2(0.62, 0.37), Vector2(0.65, 0.47), Vector2(0.55, 0.4), Vector2(0.45, 0.47), Vector2(0.48, 0.37), Vector2(0.4, 0.3), Vector2(0.5, 0.28)],
		"lines": [[0, 1], [1, 2], [1, 3], [3, 4], [3, 5], [5, 6], [5, 7], [7, 8], [1, 9], [9, 0]],
		"hint": "",
	},
	{
		"name": "El dragón dormido",
		"points": [Vector2(0.78, 0.2), Vector2(0.85, 0.24), Vector2(0.9, 0.3), Vector2(0.86, 0.36), Vector2(0.78, 0.36), Vector2(0.73, 0.3)],
		"lines": [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 0]],
		"hint": "Dicen que una sombra enorme solo cruza el cielo en noches muy despejadas como esta: los legendarios casi nunca se dejan ver.",
	},
]

var _hint_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.1, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_sky.bind(canvas))
	add_child(canvas)
	var title := UiKit.label("✦ EL CIELO DE LA REGIÓN ✦", 22, Color(0.95, 0.95, 1.0), true)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	# Columna inferior (pista + botones): se arma con sus hijos primero para que el
	# ancla "pegado abajo" calcule bien su alto y no corte los botones (bug visto en
	# capturas: la fila quedaba a medias fuera de la pantalla).
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label = UiKit.wrapped("Elige una constelación para verla mejor; algunas esconden una pista.", 18, Color(0.85, 0.9, 1.0))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_hint_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	bottom.add_child(row)
	for data: Dictionary in CONSTELLATIONS:
		var button := UiKit.action_button(String(data["name"]), UiIcons.action("stars"), Color(0.32, 0.4, 0.75))
		button.pressed.connect(_choose.bind(data))
		row.add_child(button)
	add_child(bottom)
	# Posición fija (en vez de PRESET_MODE_MINSIZE): el alto mínimo de un VBoxContainer
	# recién creado no siempre está listo en el mismo cuadro y los botones quedaban
	# cortados fuera de la pantalla (visto en capturas). Con un alto reservado fijo
	# siempre caben la pista y la fila de constelaciones.
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 24.0
	bottom.offset_right = -24.0
	bottom.offset_top = -150.0
	bottom.offset_bottom = -24.0
	var close := UiKit.action_button("Salir (%s)" % InputHints.hint("interact"), UiIcons.action("none"), Color(0.5, 0.52, 0.56))
	close.position = Vector2(24, 24)
	close.pressed.connect(_close)
	add_child(close)


func _draw_sky(canvas: Control) -> void:
	var size := get_viewport_rect().size
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 80:
		canvas.draw_circle(Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y)), rng.randf_range(0.8, 2.2), Color(1, 1, 1, rng.randf_range(0.2, 0.7)))
	for data: Dictionary in CONSTELLATIONS:
		var points: Array = data["points"]
		for line: Array in data["lines"]:
			canvas.draw_line((points[line[0]] as Vector2) * size, (points[line[1]] as Vector2) * size, Color(0.6, 0.75, 1.0, 0.55), 1.5)
		for p: Vector2 in points:
			canvas.draw_circle(p * size, 4.0, Color(1.0, 0.95, 0.7))


func _choose(data: Dictionary) -> void:
	AudioBus.play_sfx("ui_decide")
	var hint := String(data.get("hint", ""))
	_hint_label.text = "%s: %s" % [data["name"], hint] if hint != "" else "%s: solo una figura bonita en el cielo de esta noche." % data["name"]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	queue_free()
