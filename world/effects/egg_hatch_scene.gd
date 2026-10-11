class_name EggHatchScene
extends CanvasLayer
## Animación de eclosión del huevo de la guardería (pedido de Fernando, 2026-10-11:
## "nace tras caminar un rato (pasos/distancia, ~1-2 km)… con animación de eclosión;
## usa EvolutionScene o una escena similar"). Mismo estilo que EvolutionScene (fondo
## oscuro, destello y "¡Felicidades!"), pero el huevo se dibuja por código (sin sprite
## de BW2 para descargar sin permiso, ver docs/decisiones_sin_preguntar.md): tiembla
## cada vez más fuerte, un destello blanco lo agrieta y revela al bebé. Reusa la
## fanfarria `me_evolved` que ya existe en vez de pedir un sonido nuevo. Funciona con
## el juego en pausa.

signal finished

const SHAKE_SECONDS := 2.0


static func play(parent: Node, species: SpeciesData) -> EggHatchScene:
	var scene := EggHatchScene.new()
	scene._species = species
	parent.add_child(scene)
	return scene


var _species: SpeciesData


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := UiKit.backdrop(0.97)
	add_child(root)
	var title := UiKit.label("¡Oh! ¡El huevo se mueve!", 34, UiKit.WHITE, true)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 120
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(title)
	var egg := _EggShape.new()
	egg.custom_minimum_size = Vector2(140, 170)
	root.add_child(egg)
	egg.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	egg.offset_left = -70
	egg.offset_right = 70
	egg.offset_top = -85
	egg.offset_bottom = 85
	egg.pivot_offset = egg.size * 0.5
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(flash)
	var sprite := UiKit.icon_rect(MenuStyle.front_sprite(_species, false), Vector2(320, 320))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sprite.offset_left = -160
	sprite.offset_right = 160
	sprite.offset_top = -160
	sprite.offset_bottom = 160
	sprite.modulate.a = 0.0
	root.add_child(sprite)
	var tween := create_tween()
	var elapsed := 0.0
	var wobble := 0.08
	while elapsed < SHAKE_SECONDS:
		tween.tween_property(egg, "rotation", wobble, 0.12)
		tween.tween_property(egg, "rotation", -wobble, 0.12)
		elapsed += 0.24
		wobble = minf(wobble + 0.03, 0.4)
	tween.tween_property(egg, "rotation", 0.0, 0.05)
	tween.tween_callback(func() -> void:
		egg.visible = false
		flash.color.a = 1.0
		sprite.modulate.a = 1.0
		AudioBus.play_jingle("me_evolved"))
	tween.tween_property(flash, "color:a", 0.0, 0.5)
	tween.tween_callback(func() -> void:
		title.text = "¡Felicidades! ¡Nació %s!" % _species.display_name)
	tween.tween_interval(2.2)
	tween.tween_property(root, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free())


## Óvalo crema con manchas (más angosto arriba, como un huevo real), dibujado por
## código con el mismo estilo vectorial que el resto de la interfaz (MenuIcon, Rotom).
class _EggShape:
	extends Control

	func _draw() -> void:
		var c := size * 0.5
		draw_set_transform(c, 0.0, Vector2.ONE)
		var points := PackedVector2Array()
		for i in 32:
			var t := TAU * i / 32.0
			var rx: float = size.x * 0.46 * (0.82 if sin(t) > 0.0 else 1.0)
			points.append(Vector2(cos(t) * rx, sin(t) * size.y * 0.48))
		draw_colored_polygon(points, Color(0.95, 0.9, 0.78))
		draw_polyline(points, Color(0.55, 0.42, 0.3), 3.0, true)
		for spot: Vector2 in [Vector2(-18, -14), Vector2(16, 8), Vector2(-6, 34), Vector2(12, -34)]:
			draw_circle(spot, 7.0, Color(0.72, 0.58, 0.4))
		draw_set_transform(Vector2.ZERO)
