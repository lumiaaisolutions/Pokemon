class_name EvolutionScene
extends CanvasLayer
## Animación de evolución estilo BW: fondo oscuro, el Pokémon se vuelve una silueta
## blanca que alterna con la nueva forma cada vez más rápido, destello y "¡Felicidades!".
## Suena bw1_evolution y al final la fanfarria me_evolved. Funciona con el juego en pausa.

signal finished

const DURATION := 4.2


static func play(parent: Node, index: int, to: String) -> EvolutionScene:
	var scene := EvolutionScene.new()
	scene._index = index
	scene._to = to
	parent.add_child(scene)
	return scene


var _index := 0
var _to := ""


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var entry: Dictionary = GameState.party[_index]
	var from := MenuStyle.species(entry["species"])
	var into := MenuStyle.species(_to)
	var shiny: bool = entry.get("shiny", false)
	var root := UiKit.backdrop(0.97)
	add_child(root)
	var title := UiKit.label("¿Eh? ¡%s está evolucionando!" % from.display_name, 34, UiKit.WHITE, true)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 120
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(title)
	var old_sprite := _sprite(MenuStyle.front_sprite(from, shiny))
	var new_sprite := _sprite(MenuStyle.front_sprite(into, shiny))
	root.add_child(old_sprite)
	root.add_child(new_sprite)
	new_sprite.modulate = Color(10, 10, 10, 0)
	old_sprite.modulate = Color(1, 1, 1, 1)
	AudioBus.play_jingle("bw1_evolution")
	# Silueta blanca y alternancia cada vez más rápida.
	var tween := create_tween()
	tween.tween_property(old_sprite, "modulate", Color(10, 10, 10, 1), 0.8)
	var period := 0.5
	var elapsed := 0.8
	while elapsed < DURATION - 0.6:
		tween.tween_callback(func() -> void:
			old_sprite.modulate.a = 0.0
			new_sprite.modulate = Color(10, 10, 10, 1))
		tween.tween_interval(period)
		tween.tween_callback(func() -> void:
			new_sprite.modulate.a = 0.0
			old_sprite.modulate.a = 1.0)
		tween.tween_interval(period)
		elapsed += period * 2.0
		period = maxf(period * 0.72, 0.05)
	tween.tween_callback(func() -> void:
		old_sprite.visible = false
		new_sprite.modulate = Color(10, 10, 10, 1))
	tween.tween_property(new_sprite, "modulate", Color(1, 1, 1, 1), 0.6)
	tween.tween_callback(func() -> void:
		Evolution.apply(_index, _to, get_parent())
		AudioBus.play_jingle("me_evolved")
		title.text = "¡Felicidades! Tu %s evolucionó en %s." % [from.display_name, into.display_name])
	tween.tween_interval(2.4)
	tween.tween_property(root, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free())


func _sprite(texture: Texture2D) -> TextureRect:
	var rect := UiKit.icon_rect(texture, Vector2(320, 320))
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	rect.offset_left = -160
	rect.offset_right = 160
	rect.offset_top = -160
	rect.offset_bottom = 160
	return rect
