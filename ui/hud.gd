class_name Hud
extends CanvasLayer
## HUD de exploración: barra de stamina del jugador. Solo se muestra mientras
## no está llena, y se pone roja cuando está agotada.

@export var player_path: NodePath

@onready var _bar: ProgressBar = $Stamina/Bar
@onready var _panel: Control = $Stamina

var _player: Player
var _fill: StyleBoxFlat


func _ready() -> void:
	_player = get_node(player_path) as Player
	_fill = _bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	_bar.add_theme_stylebox_override("fill", _fill)


func _process(_delta: float) -> void:
	if _player == null:
		return
	var ratio := _player.stamina / _player.config.stamina_max
	_bar.value = ratio * 100.0
	_panel.visible = ratio < 0.999
	_fill.bg_color = Color(0.85, 0.25, 0.2) if _player.exhausted else Color(0.35, 0.8, 0.4)
