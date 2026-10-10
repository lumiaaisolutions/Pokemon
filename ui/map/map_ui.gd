class_name MapUi
extends CanvasLayer
## Minimapa (esquina superior derecha, gira con la cámara) y mapa completo (M o
## Select, pausa el juego) con niebla de exploración y marcadores.

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
	data.reveal(_player.global_position)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		toggle_full_map()
		get_viewport().set_input_as_handled()


func toggle_full_map() -> void:
	_full.visible = not _full.visible
	get_tree().paused = _full.visible
	if _full.visible:
		# El mapa ocupa el 80 % del lado más corto de la ventana.
		var viewport := get_viewport().get_visible_rect().size
		var side := minf(viewport.x, viewport.y) * 0.8
		_full_map.offset_left = -side * 0.5
		_full_map.offset_right = side * 0.5
		_full_map.offset_top = -side * 0.5
		_full_map.offset_bottom = side * 0.5
		_explored.text = "Explorado: %d %%" % roundi(data.explored_ratio() * 100.0)
		_full_markers.queue_redraw()


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
	# Nate: flecha hacia arriba (adelante de la cámara), en el centro.
	_draw_arrow(_dots, Vector2.ONE * MINIMAP_SIZE * 0.5, 0.0, Color(1.0, 0.3, 0.3))


func _draw_full_markers() -> void:
	var size := _full_map.size
	var start_uv := data.world_to_uv(GameState.respawn_point)
	_draw_pin(_full_markers, start_uv * size, Color(0.3, 0.6, 1.0))
	# Pueblos y ciudades (siempre) y lugares especiales ya descubiertos.
	var font := ThemeDB.fallback_font
	for settlement: Dictionary in _world.layout.settlements:
		var at := data.world_to_uv(Vector3(float(settlement["x"]), 0, float(settlement["z"]))) * size
		_full_markers.draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), Color(0.95, 0.3, 0.3) if settlement["kind"] == "city" else Color(1, 1, 1))
		_full_markers.draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), Color.BLACK, false, 1.5)
		if data.is_revealed(Vector3(float(settlement["x"]), 0, float(settlement["z"]))):
			_full_markers.draw_string_outline(font, at + Vector2(7, -5), settlement["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
			_full_markers.draw_string(font, at + Vector2(7, -5), settlement["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	for place: Dictionary in _world.layout.places:
		var point := Vector3(float(place["x"]), 0, float(place["z"]))
		if not data.is_revealed(point):
			continue
		var at := data.world_to_uv(point) * size
		_full_markers.draw_circle(at, 3.5, Color(0.7, 0.5, 1.0) if place["kind"] in ["portal", "floating_ruins", "sanctuary"] else Color(1.0, 0.85, 0.3))
		_full_markers.draw_string_outline(font, at + Vector2(5, 4), Structures.place_title(place), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
		_full_markers.draw_string(font, at + Vector2(5, 4), Structures.place_title(place), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.95, 0.8))
	var uv := data.world_to_uv(_player.global_position)
	_draw_arrow(_full_markers, uv * size, _camera_yaw(), Color(1.0, 0.3, 0.3))


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
