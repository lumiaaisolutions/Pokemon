class_name PropArt
extends RefCounted
## Sprites pixel art generados por código para los biomas nuevos (no hay en el paquete
## de B2W2): cactus, palmera, hongo gigante, hongo luminoso y acacia. Contorno oscuro,
## sombreado en 3 tonos y la misma escala de píxel que el resto (0.057 m/px).

static var _cache := {}


static func texture(kind: String) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	var image: Image
	match kind:
		"cactus":
			image = _cactus()
		"palm":
			image = _palm()
		"mushroom":
			image = _mushroom(Color(0.85, 0.25, 0.25), Color(1, 1, 1))
		"glow_mushroom":
			image = _mushroom(Color(0.45, 0.55, 1.0), Color(0.75, 1.0, 1.0))
		"acacia":
			image = _acacia()
		_:
			image = Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	_outline(image)
	var result := ImageTexture.create_from_image(image)
	_cache[kind] = result
	return result


static func _cactus() -> Image:
	var image := Image.create_empty(28, 44, false, Image.FORMAT_RGBA8)
	var dark := Color(0.2, 0.45, 0.22)
	var mid := Color(0.32, 0.62, 0.3)
	var light := Color(0.5, 0.78, 0.42)
	_rect(image, 11, 4, 7, 40, mid)
	_rect(image, 11, 4, 2, 40, dark)
	_rect(image, 16, 4, 1, 40, light)
	# Brazos.
	_rect(image, 4, 16, 7, 4, mid)
	_rect(image, 4, 8, 4, 10, mid)
	_rect(image, 18, 22, 6, 4, mid)
	_rect(image, 21, 12, 4, 12, mid)
	for y in range(6, 42, 4):
		image.set_pixel(14, y, Color(0.95, 0.95, 0.75))
	return image


static func _palm() -> Image:
	var image := Image.create_empty(52, 72, false, Image.FORMAT_RGBA8)
	var trunk := Color(0.55, 0.4, 0.25)
	var trunk_dark := Color(0.4, 0.28, 0.18)
	for y in range(22, 72):
		var x := 24 + int(sin(y * 0.08) * 3.0)
		_rect(image, x, y, 5, 1, trunk if y % 4 else trunk_dark)
	var leaf := Color(0.3, 0.68, 0.3)
	var leaf_dark := Color(0.2, 0.48, 0.22)
	for i in 6:
		var angle := -PI * 0.9 + i * PI * 0.36
		for r in 22:
			var x := 26 + int(cos(angle) * r)
			var y := 22 + int(sin(angle) * r * 0.55 + r * r * 0.018)
			_rect(image, x, y, 2, 3 if r % 3 else 2, leaf if r < 14 else leaf_dark)
	_rect(image, 22, 22, 4, 4, Color(0.5, 0.35, 0.2))
	return image


static func _mushroom(cap: Color, spots: Color) -> Image:
	var image := Image.create_empty(48, 56, false, Image.FORMAT_RGBA8)
	var stem := Color(0.93, 0.88, 0.78)
	_rect(image, 19, 26, 10, 30, stem)
	_rect(image, 19, 26, 2, 30, stem.darkened(0.25))
	for y in 28:
		var half := int(sqrt(maxf(0.0, 1.0 - pow((y - 24.0) / 24.0, 2.0))) * 23.0)
		_rect(image, 24 - half, y, half * 2, 1, cap if y < 22 else cap.darkened(0.25))
	for spot: Vector2i in [Vector2i(14, 8), Vector2i(28, 5), Vector2i(34, 14), Vector2i(20, 15), Vector2i(8, 16)]:
		_rect(image, spot.x, spot.y, 4, 3, spots)
	return image


static func _acacia() -> Image:
	var image := Image.create_empty(64, 60, false, Image.FORMAT_RGBA8)
	var trunk := Color(0.45, 0.32, 0.2)
	_rect(image, 30, 24, 5, 36, trunk)
	for i in 14:
		image.set_pixel(30 - i, 24 - i / 2, trunk)
		image.set_pixel(34 + i, 24 - i / 2, trunk)
	var crown := Color(0.55, 0.62, 0.25)
	var crown_dark := Color(0.4, 0.48, 0.18)
	for x in range(4, 60):
		var top := 6 + int(absf(x - 32) * 0.12)
		_rect(image, x, top, 1, 10, crown if (x / 3) % 2 else crown_dark)
	return image


static func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < image.get_width() and yy < image.get_height():
				image.set_pixel(xx, yy, color)


## Contorno oscuro de 1 px alrededor de lo pintado (estilo de los sprites de B2W2).
static func _outline(image: Image) -> void:
	var copy := image.duplicate() as Image
	for y in image.get_height():
		for x in image.get_width():
			if copy.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx >= 0 and ny >= 0 and nx < image.get_width() and ny < image.get_height() and copy.get_pixel(nx, ny).a > 0.5:
					image.set_pixel(x, y, Color(0.1, 0.08, 0.08))
					break
