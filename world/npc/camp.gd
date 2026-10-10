class_name Camp
extends Node3D
## Campamento de un viajero (acordado con Fernando el 2026-10-10): carpa y fogata en
## pixel art con el estilo del mundo, solo fuera de los pueblos. Al anochecer el viajero
## la arma (se agacha, la carpa se levanta con rebote, enciende el fuego) y al amanecer
## la recoge (apaga el fuego con humo, la carpa se pliega) y sigue su camino.

const PIXEL := 0.06
const TENT_COLORS := [Color(0.3, 0.62, 0.38), Color(0.32, 0.5, 0.82), Color(0.9, 0.55, 0.25), Color(0.75, 0.35, 0.4)]

## Armándose o recogiéndose (el viajero espera).
var busy := false
var _tent: Sprite3D
var _fire: Sprite3D
var _light: OmniLight3D
var _logs: Sprite3D
var _time := 0.0
var _lit := false


static func create(parent: Node, at: Vector3, color_index: int) -> Camp:
	var camp := Camp.new()
	camp.name = "Camp"
	parent.add_child(camp)
	camp.global_position = at
	camp._build(color_index)
	return camp


func _build(color_index: int) -> void:
	_tent = _sprite(_tent_texture(TENT_COLORS[absi(color_index) % TENT_COLORS.size()]), Vector3.ZERO)
	_tent.offset = Vector2(0, 18)
	_tent.scale = Vector3(1, 0.02, 1)
	_logs = _sprite(_logs_texture(), Vector3(-2.0, 0, 1.0))
	_logs.offset = Vector2(0, 5)
	_logs.modulate.a = 0.0
	_fire = _sprite(_flame_texture(0), Vector3(-2.0, 0.25, 1.0))
	_fire.offset = Vector2(0, 8)
	_fire.visible = false
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.omni_range = 6.5
	_light.light_energy = 0.0
	_light.position = Vector3(-2.0, 0.8, 1.0)
	add_child(_light)


func _sprite(texture: Texture2D, at: Vector3) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = PIXEL
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.position = at
	add_child(sprite)
	return sprite


## Arma el campamento; actor (el sprite del viajero) se agacha mientras tanto.
func pitch(actor: Node3D = null) -> void:
	busy = true
	var tween := create_tween()
	if actor != null:
		tween.tween_property(actor, "scale", Vector3(1.1, 0.8, 1.0), 0.25)
	tween.tween_property(_logs, "modulate:a", 1.0, 0.3)
	tween.tween_callback(func() -> void: PixelBurst.spawn(get_parent(), global_position + Vector3.UP * 0.3, PixelBurst.Kind.DUST, 0.6))
	tween.tween_property(_tent, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_fire.visible = true
		_lit = true)
	tween.tween_property(_light, "light_energy", 1.5, 0.5)
	if actor != null:
		tween.parallel().tween_property(actor, "scale", Vector3.ONE, 0.25)
	tween.tween_callback(func() -> void: busy = false)


## Recoge el campamento y se borra al terminar.
func pack(actor: Node3D = null) -> void:
	busy = true
	var tween := create_tween()
	if actor != null:
		tween.tween_property(actor, "scale", Vector3(1.1, 0.8, 1.0), 0.25)
	tween.tween_callback(func() -> void:
		_lit = false
		_fire.visible = false
		PixelBurst.spawn(get_parent(), global_position + Vector3(-2.0, 0.4, 1.0), PixelBurst.Kind.SMOKE, 0.7))
	tween.tween_property(_light, "light_energy", 0.0, 0.3)
	tween.tween_property(_tent, "scale", Vector3(1, 0.02, 1), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_logs, "modulate:a", 0.0, 0.3)
	if actor != null:
		tween.tween_property(actor, "scale", Vector3.ONE, 0.2)
	tween.tween_callback(func() -> void:
		busy = false
		queue_free())


func _process(delta: float) -> void:
	if not _lit:
		return
	_time += delta
	_fire.texture = _flame_texture(int(_time * 8.0) % 3)
	_light.light_energy = 1.4 + sin(_time * 13.0) * 0.12 + sin(_time * 7.0) * 0.08


# --- Pixel art ---------------------------------------------------------------------------

static var _flames := {}
static var _logs_tex: Texture2D


static func _tent_texture(color: Color) -> Texture2D:
	var w := 40
	var h := 30
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var outline := color.darkened(0.6)
	for y in h:
		var half := int((y + 1) * (w * 0.5) / h)
		for x in range(w / 2 - half, w / 2 + half):
			var c := color
			if x < w / 2:
				c = color.darkened(0.12)
			if (x - (w / 2 - half)) % 8 < 2 and y > 4:
				c = c.lightened(0.15)
			# Puerta.
			if y > h * 0.45 and absi(x - w / 2) < int((y - h * 0.45) * 0.55):
				c = Color(0.12, 0.1, 0.12)
			image.set_pixel(x, y, c)
		if w / 2 - half >= 0:
			image.set_pixel(w / 2 - half, y, outline)
			image.set_pixel(mini(w / 2 + half - 1, w - 1), y, outline)
	for x in w:
		image.set_pixel(x, h - 1, outline)
	# Palo de la punta.
	image.set_pixel(w / 2, 0, Color(0.45, 0.3, 0.2))
	return ImageTexture.create_from_image(image)


static func _logs_texture() -> Texture2D:
	if _logs_tex == null:
		var image := Image.create_empty(16, 8, false, Image.FORMAT_RGBA8)
		for x in 16:
			for y in range(3, 8):
				var stone := (x < 3 or x > 12) and y > 4
				image.set_pixel(x, y, Color(0.55, 0.55, 0.58) if stone else (Color(0.42, 0.26, 0.15) if (x + y) % 5 != 0 else Color(0.3, 0.18, 0.1)))
		_logs_tex = ImageTexture.create_from_image(image)
	return _logs_tex


static func _flame_texture(frame: int) -> Texture2D:
	if _flames.has(frame):
		return _flames[frame]
	var image := Image.create_empty(12, 16, false, Image.FORMAT_RGBA8)
	var sway: int = [0, 1, -1][frame]
	for y in 16:
		var t := float(y) / 15.0
		var half := int(lerpf(1.0, 5.5, t))
		var cx := 6 + int(round(sway * (1.0 - t)))
		for x in range(cx - half, cx + half):
			if x < 0 or x >= 12:
				continue
			var inner := absi(x - cx) < half * 0.5 and y > 5
			image.set_pixel(x, y, Color(1.0, 0.95, 0.55) if inner else (Color(1.0, 0.55, 0.15) if y > 3 else Color(0.95, 0.3, 0.1)))
	_flames[frame] = ImageTexture.create_from_image(image)
	return _flames[frame]
