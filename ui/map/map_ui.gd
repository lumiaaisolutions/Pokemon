class_name MapUi
extends CanvasLayer
## Minimapa (esquina superior derecha, gira con la cámara) y mapa completo (M o
## Select, pausa el juego) con niebla de exploración y marcadores.
## Mapa completo (acordado con Fernando el 2026-10-10): zoom con la rueda (o zoom /
## cruceta), arrastrar para moverse (o mover / stick), más detalle al acercar (lugares,
## Centro, tienda y gimnasio), tarjeta al pasar el cursor y clic para marcar un destino
## que se ve como brújula en el minimapa (sin línea guía). Clic derecho quita el destino.

const MINIMAP_SIZE := 200.0
const MINIMAP_RADIUS_M := 150.0
const DOT_RADIUS := 3.0
const REVEAL_INTERVAL := 0.4

@export var player_path: NodePath
@export var world_path: NodePath

var data := WorldMapData.new()
var _player: Player
var _world: WorldBuilder
var _reveal_timer: float = 0.0
## Vista del mapa completo: centro (UV del mundo) y acercamiento (1 = región entera).
var view_center := Vector2(0.5, 0.5)
var zoom := 1.0
const ZOOM_MAX := 12.0
var _drag_from := Vector2.INF
var _dragged := false
var _hover := Vector2.INF
var _card: PanelContainer
var _card_title: Label
var _card_text: Label
var _hints: Label

@onready var _minimap: ColorRect = $Minimap
@onready var _dots: Control = $Minimap/Dots
@onready var _full: Control = $Full
@onready var _full_map: ColorRect = $Full/Map
@onready var _full_markers: Control = $Full/Map/Markers
@onready var _explored: Label = $Full/Explored


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_node(player_path) as Player
	_world = get_node(world_path) as WorldBuilder
	data.build(_world)
	var mini := _minimap.material as ShaderMaterial
	mini.set_shader_parameter("map_tex", data.map_texture)
	mini.set_shader_parameter("fog_tex", data.fog_texture)
	mini.set_shader_parameter("radius_uv", MINIMAP_RADIUS_M / data.size_m)
	var full := _full_map.material as ShaderMaterial
	full.set_shader_parameter("map_tex", data.map_texture)
	full.set_shader_parameter("fog_tex", data.fog_texture)
	_full.visible = false
	_dots.draw.connect(_draw_minimap_markers)
	_full_markers.draw.connect(_draw_full_markers)
	_full_map.gui_input.connect(_on_map_input)
	_full_map.mouse_exited.connect(func() -> void:
		_hover = Vector2.INF
		_card.visible = false)
	_style_full()
	data.reveal(_player.global_position)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		toggle_full_map()
		get_viewport().set_input_as_handled()


func toggle_full_map() -> void:
	_full.visible = not _full.visible
	get_tree().paused = _full.visible
	# Con el mapa abierto, el HUD (avisos, leyenda) no se ve encima.
	layer = 20 if _full.visible else 2
	var hud := get_parent().get_node_or_null("Hud") as CanvasLayer
	if hud != null:
		hud.visible = not _full.visible
	if _full.visible:
		# El mapa ocupa el 80 % del lado más corto de la ventana.
		var viewport := get_viewport().get_visible_rect().size
		var side := minf(viewport.x, viewport.y) * 0.8
		_full_map.offset_left = -side * 0.5
		_full_map.offset_right = side * 0.5
		_full_map.offset_top = -side * 0.5
		_full_map.offset_bottom = side * 0.5
		_explored.text = "Explorado: %d %%" % roundi(data.explored_ratio() * 100.0)
		view_center = data.world_to_uv(_player.global_position)
		zoom = maxf(zoom, 1.0)
		_clamp_view()
		_apply_view()


func _process(delta: float) -> void:
	if _player == null:
		return
	data.poll()
	# El minimapa aparece cuando la imagen está lista y se oculta en interiores.
	_minimap.visible = data.is_ready and _player.global_position.x < WorldBuilder.INTERIOR_X
	_reveal_timer -= delta
	if _reveal_timer <= 0.0 and not get_tree().paused:
		_reveal_timer = REVEAL_INTERVAL
		data.reveal(_player.global_position)
	if _full.visible:
		_pan_with_input(delta)
	var mini := _minimap.material as ShaderMaterial
	mini.set_shader_parameter("center_uv", data.world_to_uv(_player.global_position))
	mini.set_shader_parameter("rotation", _camera_yaw())
	_dots.queue_redraw()


## Giro de la cámara: el minimapa muestra "adelante" de la cámara hacia arriba.
func _camera_yaw() -> float:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return 0.0
	var forward := -camera.global_basis.z
	return atan2(forward.x, -forward.z)


## Punto del mundo -> posición en el minimapa (o Vector2.INF si queda fuera).
func _to_minimap(point: Vector3) -> Vector2:
	var offset := Vector2(point.x - _player.global_position.x, point.z - _player.global_position.z)
	var yaw := -_camera_yaw()
	var rotated := Vector2(cos(yaw) * offset.x - sin(yaw) * offset.y, sin(yaw) * offset.x + cos(yaw) * offset.y)
	var scaled := rotated / MINIMAP_RADIUS_M * (MINIMAP_SIZE * 0.5 * 0.93)
	if scaled.length() > MINIMAP_SIZE * 0.5 * 0.9:
		return Vector2.INF
	return scaled + Vector2.ONE * MINIMAP_SIZE * 0.5


func _draw_minimap_markers() -> void:
	for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
		var actor := node as PokemonActor
		var pos := _to_minimap(actor.global_position)
		if pos != Vector2.INF:
			var color := Color(1.0, 0.85, 0.2) if actor.shiny else (Color(0.95, 0.3, 0.25) if actor.state == PokemonActor.State.CHASE or actor.state == PokemonActor.State.FIGHT else Color.WHITE)
			_dots.draw_rect(Rect2(pos - Vector2.ONE * DOT_RADIUS, Vector2.ONE * DOT_RADIUS * 2.0), color)
	var start := _to_minimap(GameState.respawn_point)
	if start != Vector2.INF:
		_draw_pin(_dots, start, Color(0.3, 0.6, 1.0))
	# Destino: bandera en el minimapa; si está lejos, en el borde (como brújula).
	var target := waypoint()
	if target != Vector3.INF:
		var pos := _to_minimap(target)
		if pos == Vector2.INF:
			var offset := Vector2(target.x - _player.global_position.x, target.z - _player.global_position.z)
			var yaw := -_camera_yaw()
			var dir := Vector2(cos(yaw) * offset.x - sin(yaw) * offset.y, sin(yaw) * offset.x + cos(yaw) * offset.y).normalized()
			pos = Vector2.ONE * MINIMAP_SIZE * 0.5 + dir * MINIMAP_SIZE * 0.5 * 0.86
		_draw_flag(_dots, pos)
	# Nate: flecha hacia arriba (adelante de la cámara), en el centro.
	_draw_arrow(_dots, Vector2.ONE * MINIMAP_SIZE * 0.5, 0.0, Color(1.0, 0.3, 0.3))


# --- Mapa completo con zoom -------------------------------------------------------------

func _style_full() -> void:
	var backdrop := _full.get_node("Backdrop") as ColorRect
	backdrop.color = Color(0.04, 0.05, 0.1, 0.78)
	var title := _full.get_node("Title") as Label
	title.text = "MAPA DE LA REGIÓN"
	title.add_theme_font_override("font", UiKit.font(true))
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_explored.add_theme_font_override("font", UiKit.font(true))
	_explored.offset_top -= 34
	_explored.offset_bottom -= 34
	# Marco rojo redondeado alrededor del mapa (estilo claro del juego).
	var frame := Panel.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = UiKit.RED
	style.set_border_width_all(10)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 12
	frame.add_theme_stylebox_override("panel", style)
	_full_map.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = -8
	frame.offset_top = -8
	frame.offset_right = 8
	frame.offset_bottom = 8
	_full_map.clip_contents = true
	# Tarjeta al pasar el cursor.
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiKit.light_style(UiKit.RED, 14, 3))
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	_card.add_child(column)
	_card_title = UiKit.label("", 20, UiKit.RED_DARK, true)
	_card_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	column.add_child(_card_title)
	_card_text = UiKit.label("", 16, UiKit.TEXT, true)
	_card_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	column.add_child(_card_text)
	_card.visible = false
	_full.add_child(_card)
	# Ayudas abajo.
	_hints = UiKit.label("", 18, Color(0.92, 0.94, 1.0), true)
	_hints.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hints.offset_top = -44
	_hints.offset_bottom = -14
	_hints.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_full.add_child(_hints)


## Ancho visible en UV del mundo.
func view_size() -> float:
	return 1.0 / zoom


func _clamp_view() -> void:
	zoom = clampf(zoom, 1.0, ZOOM_MAX)
	var half := view_size() * 0.5
	view_center.x = clampf(view_center.x, minf(half, 0.5), maxf(1.0 - half, 0.5))
	view_center.y = clampf(view_center.y, minf(half, 0.5), maxf(1.0 - half, 0.5))


func _apply_view() -> void:
	var full := _full_map.material as ShaderMaterial
	full.set_shader_parameter("view_center", view_center)
	full.set_shader_parameter("view_size", view_size())
	_hints.text = "Rueda / %s: acercar · Arrastra o %s: mover · Clic: marcar destino · Clic derecho: quitarlo · %s: cerrar   ·   Zoom ×%.1f" % [
			InputHints.hint("zoom_in"), InputHints.hint("move_forward"), InputHints.hint("map"), zoom]
	_full_markers.queue_redraw()


## UV del mundo -> punto dentro del mapa en pantalla.
func uv_to_screen(uv: Vector2) -> Vector2:
	return ((uv - view_center) / view_size() + Vector2(0.5, 0.5)) * _full_map.size


func screen_to_uv(point: Vector2) -> Vector2:
	return view_center + (point / _full_map.size - Vector2(0.5, 0.5)) * view_size()


func uv_to_world(uv: Vector2) -> Vector3:
	return Vector3((uv.x - 0.5) * data.size_m, 0.0, (uv.y - 0.5) * data.size_m)


## Acerca o aleja manteniendo fijo el punto bajo el cursor.
func zoom_at(point: Vector2, factor: float) -> void:
	var before := screen_to_uv(point)
	zoom *= factor
	_clamp_view()
	var after := screen_to_uv(point)
	view_center += before - after
	_clamp_view()
	_apply_view()


func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(button.position, 1.2)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(button.position, 1.0 / 1.2)
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_drag_from = button.position
				_dragged = false
			else:
				if not _dragged:
					set_waypoint(uv_to_world(screen_to_uv(button.position)))
				_drag_from = Vector2.INF
		elif button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
			clear_waypoint()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _drag_from != Vector2.INF and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if motion.position.distance_to(_drag_from) > 4.0:
				_dragged = true
			view_center -= motion.relative / _full_map.size * view_size()
			_clamp_view()
			_apply_view()
		_hover = motion.position
		_update_card()


## Teclado y mando: mover con las flechas de movimiento, acercar con zoom.
func _pan_with_input(delta: float) -> void:
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var changed := false
	if move.length() > 0.1:
		view_center += move * view_size() * 0.8 * delta
		changed = true
	if Input.is_action_pressed("zoom_in"):
		zoom *= 1.0 + 1.5 * delta
		changed = true
	if Input.is_action_pressed("zoom_out"):
		zoom /= 1.0 + 1.5 * delta
		changed = true
	if changed:
		_clamp_view()
		_apply_view()


# --- Destino (brújula del minimapa) ---------------------------------------------------

func set_waypoint(point: Vector3) -> void:
	GameState.world_flags["waypoint"] = [point.x, point.z]
	AudioBus.play_sfx("ui_decide")
	_full_markers.queue_redraw()


func clear_waypoint() -> void:
	GameState.world_flags.erase("waypoint")
	AudioBus.play_sfx("ui_cancel")
	_full_markers.queue_redraw()


func waypoint() -> Vector3:
	var stored: Variant = GameState.world_flags.get("waypoint")
	if stored == null:
		return Vector3.INF
	return Vector3(float(stored[0]), 0.0, float(stored[1]))


# --- Marcadores ---------------------------------------------------------------------------

## Lo que hay en el mapa con su tipo, para dibujar y para la tarjeta del cursor:
## [{uv, kind, title, text, color, min_zoom}].
func _markers() -> Array:
	var result: Array = []
	for settlement: Dictionary in _world.layout.settlements:
		var point := Vector3(float(settlement["x"]), 0, float(settlement["z"]))
		if not data.is_revealed(point):
			result.append({"uv": data.world_to_uv(point), "kind": "unknown_town", "title": "¿?", "text": "Un asentamiento sin explorar.", "color": Color(0.7, 0.7, 0.75), "min_zoom": 1.0})
			continue
		var kinds := {"city": "Ciudad", "town": "Pueblo", "village": "Aldea", "cabins": "Cabañas"}
		var services := PackedStringArray()
		for building: Dictionary in settlement["buildings"]:
			var label: String = {"center": "Centro Pokémon", "mart": "Tienda", "gym": "Gimnasio", "lab": "Laboratorio", "contest": "Concursos"}.get(building["kind"], "")
			if label != "" and not services.has(label):
				services.append(label)
			if label != "":
				var b_point := Vector3(float(building["x"]), 0, float(building["z"]))
				result.append({"uv": data.world_to_uv(b_point), "kind": building["kind"], "title": label, "text": "En %s" % settlement["name"],
						"color": {"center": Color(0.95, 0.35, 0.4), "mart": Color(0.3, 0.55, 0.95), "gym": Color(0.95, 0.7, 0.2), "lab": Color(0.35, 0.8, 0.6), "contest": Color(0.85, 0.45, 0.85)}[building["kind"]], "min_zoom": 4.0})
		result.append({"uv": data.world_to_uv(point), "kind": "town", "title": settlement["name"],
				"text": "%s · %s" % [kinds.get(settlement["kind"], "Pueblo"), ", ".join(services) if not services.is_empty() else "sin servicios"],
				"color": UiKit.RED if settlement["kind"] == "city" else Color(0.98, 0.95, 0.9), "min_zoom": 1.0})
	# Puntos de interés descubiertos.
	for poi: Dictionary in PointsOfInterest.seen_list():
		result.append({"uv": data.world_to_uv(Vector3(poi["x"], 0, poi["z"])), "kind": "place", "title": PointsOfInterest.TITLES.get(poi["kind"], "?"),
				"text": "Punto de interés", "color": Color(0.55, 0.85, 0.45), "min_zoom": 2.0})
	# El profesor de viaje (la asistente dice dónde).
	var professor := get_parent().get_node_or_null("Professor") as Professor
	if professor != null and not professor.trip_place().is_empty():
		var trip := professor.trip_place()
		result.append({"uv": data.world_to_uv(Vector3(float(trip["x"]), 0, float(trip["z"]))), "kind": "hero", "title": "✚ " + Professor.title(),
				"text": "Investigando en %s (8:00–19:00)" % Structures.place_title(trip), "color": Color(0.55, 0.85, 1.0), "min_zoom": 1.0})
	# Líderes fuera del gimnasio que el guía te marcó hoy.
	var leaders := get_parent().get_node_or_null("GymLeaders") as GymLeaders
	if leaders != null:
		for mark: Dictionary in leaders.map_marks():
			result.append({"uv": data.world_to_uv(Vector3(float(mark["x"]), 0, float(mark["z"]))), "kind": "hero", "title": "◆ Líder " + Leaders.name_of(mark["id"]),
					"text": mark["text"], "color": Color(1.0, 0.6, 0.25), "min_zoom": 1.0})
	# Héroes con rumor hoy (el Rotom dice dónde se vieron).
	var heroes := get_parent().get_node_or_null("Heroes") as Heroes
	if heroes != null:
		for id: String in heroes.rumored_today():
			var spot := heroes.location(id)
			if not spot.is_empty():
				result.append({"uv": data.world_to_uv(Vector3(float(spot["x"]), 0, float(spot["z"]))), "kind": "hero", "title": "★ " + String(PlayerCharacters.find(id)["name"]),
						"text": "Rumor de hoy: anda por %s (8:00–20:00)" % spot["name"], "color": Color(1.0, 0.8, 0.2), "min_zoom": 1.0})
	for place: Dictionary in _world.layout.places:
		var point := Vector3(float(place["x"]), 0, float(place["z"]))
		if not data.is_revealed(point):
			continue
		var mystic: bool = place["kind"] in ["portal", "floating_ruins", "sanctuary"]
		result.append({"uv": data.world_to_uv(point), "kind": "place", "title": Structures.place_title(place), "text": "Lugar especial",
				"color": Color(0.7, 0.5, 1.0) if mystic else Color(1.0, 0.82, 0.3), "min_zoom": 1.8})
	# Desfiladeros: igual que los demás lugares, solo al descubrirlos (plan de pulido).
	for pass_entry: Dictionary in _world.layout.passes:
		var mid := Vector3(float(pass_entry["mid_x"]), 0, float(pass_entry["mid_z"]))
		if not data.is_revealed(mid):
			continue
		var is_open := BreakableRock.boulder_broken(String(pass_entry["id"]))
		result.append({"uv": data.world_to_uv(mid), "kind": "place", "title": "Desfiladero",
				"text": "Atajo abierto" if is_open else "Atajo tapado por una roca enorme",
				"color": Color(0.55, 0.85, 0.45) if is_open else Color(0.75, 0.6, 0.5), "min_zoom": 1.8})
	return result


func _draw_full_markers() -> void:
	var font := UiKit.font(true)
	var size := _full_map.size
	for marker: Dictionary in _markers():
		if zoom < float(marker["min_zoom"]):
			continue
		var at := uv_to_screen(marker["uv"])
		if at.x < -20 or at.y < -20 or at.x > size.x + 20 or at.y > size.y + 20:
			continue
		var color: Color = marker["color"]
		match String(marker["kind"]):
			"town":
				var r := 9.0 + minf(zoom, 4.0)
				_full_markers.draw_circle(at, r + 3.0, Color(0.1, 0.1, 0.14))
				_full_markers.draw_circle(at, r, color)
				_full_markers.draw_rect(Rect2(at - Vector2(r * 0.45, r * 0.1), Vector2(r * 0.9, r * 0.6)), Color(0.35, 0.3, 0.3))
				_full_markers.draw_colored_polygon(PackedVector2Array([at + Vector2(-r * 0.6, -r * 0.05), at + Vector2(0, -r * 0.6), at + Vector2(r * 0.6, -r * 0.05)]), Color(0.75, 0.25, 0.25))
				_label(font, at + Vector2(r + 6, 6), String(marker["title"]), 17 + int(minf(zoom, 4.0)))
			"unknown_town":
				_full_markers.draw_circle(at, 9.0, Color(0.1, 0.1, 0.14))
				_full_markers.draw_circle(at, 7.0, color)
				_label(font, at + Vector2(-4, 6), "?", 15)
			"hero":
				_full_markers.draw_circle(at, 11.0, Color(0.1, 0.1, 0.14))
				_full_markers.draw_circle(at, 9.0, color)
				_full_markers.draw_string(font, at + Vector2(-6, 6), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.25, 0.15, 0.05))
				_label(font, at + Vector2(14, 6), String(marker["title"]), 16)
			"place":
				_full_markers.draw_circle(at, 7.0, Color(0.1, 0.1, 0.14))
				_full_markers.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -6), at + Vector2(6, 0), at + Vector2(0, 6), at + Vector2(-6, 0)]), color)
				if zoom >= 2.5:
					_label(font, at + Vector2(10, 5), String(marker["title"]), 14)
			_:
				# Servicios del pueblo (con zoom alto): círculo de color con su inicial.
				_full_markers.draw_circle(at, 11.0, Color(0.1, 0.1, 0.14))
				_full_markers.draw_circle(at, 9.0, color)
				var letter := {"center": "+", "mart": "$", "gym": "★", "lab": "L", "contest": "♪"}.get(marker["kind"], "·") as String
				_full_markers.draw_string(font, at + Vector2(-5, 6), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	# Inicio, destino y jugador.
	_draw_pin(_full_markers, uv_to_screen(data.world_to_uv(GameState.respawn_point)), Color(0.3, 0.6, 1.0))
	var target := waypoint()
	if target != Vector3.INF:
		_draw_flag(_full_markers, uv_to_screen(data.world_to_uv(target)))
	_draw_arrow(_full_markers, uv_to_screen(data.world_to_uv(_player.global_position)), _camera_yaw(), Color(1.0, 0.3, 0.3))


func _label(font: Font, at: Vector2, text: String, size: int) -> void:
	_full_markers.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0.08, 0.08, 0.12))
	_full_markers.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


func _draw_flag(canvas: CanvasItem, at: Vector2) -> void:
	canvas.draw_line(at, at + Vector2(0, -26), Color(0.1, 0.1, 0.14), 3.0)
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(1, -26), at + Vector2(18, -20), at + Vector2(1, -13)]), Color(1.0, 0.85, 0.2))
	canvas.draw_circle(at, 4.0, Color(1.0, 0.85, 0.2))


## Tarjeta con el marcador más cercano al cursor.
func _update_card() -> void:
	if _hover == Vector2.INF:
		_card.visible = false
		return
	var best: Dictionary = {}
	var best_distance := 18.0
	for marker: Dictionary in _markers():
		if zoom < float(marker["min_zoom"]):
			continue
		var distance := uv_to_screen(marker["uv"]).distance_to(_hover)
		if distance < best_distance:
			best_distance = distance
			best = marker
	_card.visible = not best.is_empty()
	if best.is_empty():
		return
	_card_title.text = String(best["title"])
	_card_text.text = String(best["text"])
	_card.reset_size()
	_card.position = _full_map.position + _hover + Vector2(18, 12)


func _draw_arrow(canvas: CanvasItem, at: Vector2, angle: float, color: Color) -> void:
	var points := PackedVector2Array([Vector2(0, -9), Vector2(6, 7), Vector2(0, 3), Vector2(-6, 7)])
	var transformed := PackedVector2Array()
	for p in points:
		transformed.append(at + p.rotated(angle))
	canvas.draw_colored_polygon(transformed, color)
	canvas.draw_polyline(transformed + PackedVector2Array([transformed[0]]), Color.BLACK, 2.0)


func _draw_pin(canvas: CanvasItem, at: Vector2, color: Color) -> void:
	canvas.draw_circle(at, 5.0, Color.BLACK)
	canvas.draw_circle(at, 3.5, color)
