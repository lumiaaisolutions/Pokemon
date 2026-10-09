class_name Hud
extends CanvasLayer
## HUD de exploración: corazones de vida (estilo Minecraft), burbujas de aire (solo
## bajo el agua), barra de stamina (solo si no está llena), tinte azul al bucear y
## pantalla negra al desmayarse.

const HEARTS := 10
const BUBBLES := 10
const ICON_SCALE := 3

@export var player_path: NodePath

@onready var _bar: ProgressBar = $Stamina/Bar
@onready var _panel: Control = $Stamina
@onready var _hearts_box: HBoxContainer = $Hearts
@onready var _bubbles_box: HBoxContainer = $Bubbles
@onready var _underwater: ColorRect = $Underwater
@onready var _blackout: ColorRect = $Blackout
@onready var _blackout_label: Label = $Blackout/Label

var _player: Player
var _fill: StyleBoxFlat
var _heart_full: Texture2D
var _heart_half: Texture2D
var _heart_empty: Texture2D
var _bubble: Texture2D
var _world: WorldBuilder


func _ready() -> void:
	_player = get_node(player_path) as Player
	_fill = _bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	_bar.add_theme_stylebox_override("fill", _fill)
	_heart_full = _heart_texture(Color(0.9, 0.15, 0.2), 1.0)
	_heart_half = _heart_texture(Color(0.9, 0.15, 0.2), 0.5)
	_heart_empty = _heart_texture(Color(0.25, 0.1, 0.12), 1.0)
	_bubble = _bubble_texture()
	for i in HEARTS:
		_hearts_box.add_child(_icon(_heart_full))
	for i in BUBBLES:
		_bubbles_box.add_child(_icon(_bubble))
	_blackout.visible = false


func _process(_delta: float) -> void:
	if _player == null:
		return
	var ratio := _player.stamina / _player.config.stamina_max
	_bar.value = ratio * 100.0
	_panel.visible = ratio < 0.999
	_fill.bg_color = Color(0.85, 0.25, 0.2) if _player.exhausted else Color(0.35, 0.8, 0.4)
	# Corazones: cada uno vale 2 de vida (medios corazones).
	var per_heart := _player.config.health_max / HEARTS
	for i in HEARTS:
		var heart_health := _player.health - i * per_heart
		var rect := _hearts_box.get_child(i) as TextureRect
		rect.texture = _heart_full if heart_health >= per_heart else (_heart_half if heart_health > 0.0 else _heart_empty)
	# Burbujas: solo cuando le falta aire.
	var air_ratio := _player.air / _player.config.air_max
	_bubbles_box.visible = air_ratio < 0.999
	for i in BUBBLES:
		(_bubbles_box.get_child(i) as TextureRect).visible = air_ratio > float(i) / BUBBLES
	# Tinte azul si la cámara está bajo el agua.
	if _world == null:
		_world = get_tree().get_first_node_in_group(WorldBuilder.WORLD_GROUP) as WorldBuilder
	var camera := get_viewport().get_camera_3d()
	_underwater.visible = camera != null and _world != null \
			and camera.global_position.y < _world.water_level_at(camera.global_position.x, camera.global_position.z)


## Pantalla negra de desmayo con el mensaje; dura seconds.
func show_blackout(message: String, seconds: float) -> void:
	_blackout_label.text = message
	_blackout.visible = true
	_blackout.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_blackout, "modulate:a", 1.0, 0.6)
	tween.tween_interval(seconds)
	tween.tween_property(_blackout, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void: _blackout.visible = false)


func _icon(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.custom_minimum_size = Vector2(9, 9) * ICON_SCALE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	return rect


## Corazón pixel art de 9×9; fill = 0.5 deja vacía la mitad derecha (medio corazón).
func _heart_texture(color: Color, fill: float) -> Texture2D:
	var rows := [".XX...XX.", "XooX.XooX", "XoooXoooX", "XoooooooX", ".XoooooX.", "..XoooX..", "...XoX...", "....X....", "........."]
	var image := Image.create_empty(9, 9, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 9:
			var c: String = rows[y][x]
			if c == "X":
				image.set_pixel(x, y, Color(0.08, 0.02, 0.03))
			elif c == "o":
				var filled := x < 4.5 or fill >= 1.0
				image.set_pixel(x, y, color if filled else Color(0.25, 0.1, 0.12))
	return ImageTexture.create_from_image(image)


func _bubble_texture() -> Texture2D:
	var rows := ["..XXXXX..", ".XoooooX.", "XoWoooooX", "XoWoooooX", "XoooooooX", "XoooooooX", ".XoooooX.", "..XXXXX..", "........."]
	var image := Image.create_empty(9, 9, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 9:
			match rows[y][x]:
				"X":
					image.set_pixel(x, y, Color(0.1, 0.25, 0.5))
				"o":
					image.set_pixel(x, y, Color(0.45, 0.75, 1.0))
				"W":
					image.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(image)
