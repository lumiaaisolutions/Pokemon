class_name SpeechBubbles
extends Node3D
## Burbujas cortas sobre la cabeza de la gente (decidido con Fernando el 2026-10-10):
## charla entre vecinos, órdenes al pelear ("¡Usa Placaje!") y reacciones a sucesos
## cercanos (inicial, horda, shiny, migración...). Globo claro con contorno, estilo de
## ui/kit/ui_kit.gd, que siempre mira a la cámara, encima del nombre del NPC, y se
## desvanece solo. Como mucho MAX_ACTIVE a la vez en toda la pantalla y con enfriamiento
## por persona para no saturar.

const MAX_ACTIVE := 3
## Enfriamiento por persona (misma "key" o mismo nodo) antes de poder hablar otra vez.
const COOLDOWN := 3.0
## Altura sobre el nodo (encima del nombre y de la marca "¡!" de los retos).
const HEIGHT := 3.3
const SHOW_SECONDS := 2.0
const FADE_SECONDS := 0.35
## Regla acordada: solo aparecen si el jugador está cerca.
const RANGE := 25.0

static var _active: Array[SpeechBubbles] = []
static var _cooldowns: Dictionary = {}
## Texturas del globo cacheadas por ancho en píxeles (para no repetir el dibujo).
static var _textures: Dictionary = {}


## Burbuja sobre node con text. Devuelve false si no se mostró (cupo lleno, en
## enfriamiento, ya tiene una, o node no es válido). key agrupa el enfriamiento (por
## defecto, el propio nodo: dos burbujas del mismo NPC no se pisan).
static func say(node: Node3D, text: String, seconds: float = SHOW_SECONDS, key: String = "") -> bool:
	if node == null or not is_instance_valid(node) or node.get_node_or_null("Bubble") != null:
		return false
	_prune()
	var id := key if key != "" else str(node.get_instance_id())
	var now := Time.get_ticks_msec() * 0.001
	if now < float(_cooldowns.get(id, 0.0)):
		return false
	if _active.size() >= MAX_ACTIVE:
		return false
	_cooldowns[id] = now + COOLDOWN
	var bubble := SpeechBubbles.new()
	bubble.name = "Bubble"
	bubble.position.y = HEIGHT
	node.add_child(bubble)
	bubble._build(text)
	_active.append(bubble)
	bubble.tree_exited.connect(_forget.bind(bubble))
	var tween := bubble.create_tween()
	tween.tween_interval(seconds)
	tween.tween_callback(bubble._fade)
	return true


static func _forget(bubble: SpeechBubbles) -> void:
	_active.erase(bubble)


static func _prune() -> void:
	_active = _active.filter(func(b: SpeechBubbles) -> bool: return is_instance_valid(b))


## ¿node está a menos de range de player? (regla de cercanía antes de llamar a say()).
static func near_player(node: Node3D, player: Node3D, range: float = RANGE) -> bool:
	return node != null and player != null and is_instance_valid(node) and is_instance_valid(player) \
			and node.global_position.distance_to(player.global_position) <= range


## Cuántas burbujas hay ahora en pantalla (pruebas).
static func active_count() -> int:
	_prune()
	return _active.size()


func _build(text: String) -> void:
	var width := clampi(roundi((10.0 * text.length() + 26.0) / 8.0) * 8, 72, 232)
	var panel := Sprite3D.new()
	panel.name = "Panel"
	panel.texture = _bubble_texture(width)
	panel.pixel_size = 0.01
	panel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	panel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	panel.shaded = false
	panel.no_depth_test = true
	panel.layers = 2
	panel.render_priority = 2
	add_child(panel)
	var label := Label3D.new()
	label.name = "Label"
	label.text = text
	label.font_size = 26
	label.outline_size = 6
	label.outline_modulate = Color(1, 1, 1, 0.7)
	label.modulate = UiKit.TEXT
	label.pixel_size = 0.0075
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 3
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)


func _fade() -> void:
	if not is_instance_valid(self):
		return
	var tween := create_tween()
	var label := get_node_or_null("Label") as Label3D
	var panel := get_node_or_null("Panel") as Sprite3D
	if label != null:
		tween.tween_property(label, "modulate:a", 0.0, FADE_SECONDS)
	if panel != null:
		tween.parallel().tween_property(panel, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(queue_free)


## Globo claro con borde (estilo Pokopia de ui_kit.gd) de ese ancho en píxeles, pixel art
## con esquinas redondeadas; se cachea por ancho para no repetir el dibujo.
static func _bubble_texture(width: int) -> Texture2D:
	if not _textures.has(width):
		var h := 48
		var image := Image.create_empty(width, h, false, Image.FORMAT_RGBA8)
		var radius := 13.0
		var fill := UiKit.CREAM
		var border := UiKit.RED_DARK
		for y in h:
			for x in width:
				var dx := maxf(0.0, maxf(radius - x, x - (width - 1 - radius)))
				var dy := maxf(0.0, maxf(radius - y, y - (h - 1 - radius)))
				var inside := true
				if dx > 0.0 and dy > 0.0:
					inside = Vector2(dx, dy).length() <= radius
				if not inside:
					continue
				var edge := dx > 0.0 and dy > 0.0 and Vector2(dx, dy).length() > radius - 2.5
				edge = edge or (dx == 0.0 and (x < 2 or x > width - 3)) or (dy == 0.0 and (y < 2 or y > h - 3))
				image.set_pixel(x, y, border if edge else fill)
		_textures[width] = ImageTexture.create_from_image(image)
	return _textures[width]
