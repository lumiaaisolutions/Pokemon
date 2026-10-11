class_name PixelShapes
extends RefCounted
## Formas pixel art de los ataques (pedido de Fernando, 2026-10-10: estilo pixel art como
## el mundo). Se dibujan por código en lienzos pequeños con contorno oscuro y sombreado,
## y se guardan en caché por nombre y color. Ver docs/sistemas/animaciones_ataques.md.

static var _cache := {}


## Textura de la forma (name) con su color principal (base).
static func get_texture(name: String, base: Color = Color.WHITE, frame: int = 0) -> ImageTexture:
	var key := "%s:%s:%d" % [name, base.to_html(), frame]
	if _cache.has(key):
		return _cache[key]
	var image: Image
	match name:
		"shuriken":
			image = _shuriken(base, frame)
		"fire_star":
			image = _fire_star()
		"flame":
			image = _flame()
		"drop":
			image = _drop(base)
		"vine":
			image = _vine()
		"leaf":
			image = _leaf(base)
		"jaw_top":
			image = _jaw(base, true)
		"jaw_bottom":
			image = _jaw(base, false)
		"mound":
			image = _mound()
		"rock":
			image = _rock(base)
		"crack":
			image = _crack()
		"scorch":
			image = _scorch()
		"puddle":
			image = _puddle(base)
		"star":
			image = _star(base)
		"orb":
			image = _orb(base)
		_:
			image = _orb(base)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


# --- Ayudas de dibujo ------------------------------------------------------------------

static func _canvas(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


static func _disc(image: Image, cx: float, cy: float, r: float, color: Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r:
				image.set_pixel(x, y, color)


static func _poly(image: Image, points: PackedVector2Array, color: Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
				image.set_pixel(x, y, color)


## Contorno oscuro de un píxel alrededor de lo dibujado (como los sprites de la DS).
static func _outline(image: Image, color: Color) -> Image:
	var out := image.duplicate() as Image
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < image.get_width() and n.y < image.get_height() and image.get_pixel(n.x, n.y).a > 0.0:
					out.set_pixel(x, y, color)
					break
	return out


# --- Formas --------------------------------------------------------------------------

## Shuriken de agua: estrella de 4 puntas que gira (azul con brillo blanco); frame 0–3
## la gira de 22.5° en 22.5° (la estrella se repite cada 90°).
static func _shuriken(base: Color, frame: int) -> Image:
	var image := _canvas(17, 17)
	var c := Vector2(8.5, 8.5)
	var points := PackedVector2Array()
	for i in 8:
		var angle := TAU * i / 8.0 - PI * 0.5 + frame * PI / 8.0
		points.append(c + Vector2.from_angle(angle) * (8.0 if i % 2 == 0 else 2.6))
	_poly(image, points, base)
	_disc(image, 8.5, 8.5, 2.2, base.lightened(0.5))
	_disc(image, 7.5, 7.5, 1.0, Color.WHITE)
	return _outline(image, base.darkened(0.55))


## Estrella de fuego de Llamarada (cinco brazos, como el kanji 大 de los juegos).
static func _fire_star() -> Image:
	var image := _canvas(25, 25)
	var c := Vector2(12.5, 13.0)
	var arms := [Vector2(0, -1), Vector2(-1, -0.25), Vector2(1, -0.25), Vector2(-0.7, 1), Vector2(0.7, 1)]
	for arm: Vector2 in arms:
		var dir := arm.normalized()
		var side := Vector2(-dir.y, dir.x)
		_poly(image, PackedVector2Array([c + side * 2.6, c + dir * 11.0 + side * 1.6, c + dir * 11.0 - side * 1.6, c - side * 2.6]), Color(1.0, 0.45, 0.1))
		_poly(image, PackedVector2Array([c + side * 1.2, c + dir * 9.0 + side * 0.6, c + dir * 9.0 - side * 0.6, c - side * 1.2]), Color(1.0, 0.85, 0.25))
	_disc(image, c.x, c.y, 3.5, Color(1.0, 0.95, 0.6))
	return _outline(image, Color(0.55, 0.08, 0.05))


## Llama de chorro (Lanzallamas): gota de fuego amarilla, naranja y roja.
static func _flame() -> Image:
	var image := _canvas(9, 13)
	_poly(image, PackedVector2Array([Vector2(4.5, 0), Vector2(8.5, 8), Vector2(7, 12.5), Vector2(2, 12.5), Vector2(0.5, 8)]), Color(0.95, 0.25, 0.08))
	_poly(image, PackedVector2Array([Vector2(4.5, 3), Vector2(7, 9), Vector2(6, 12), Vector2(3, 12), Vector2(2, 9)]), Color(1.0, 0.6, 0.12))
	_disc(image, 4.5, 9.5, 1.8, Color(1.0, 0.92, 0.45))
	return image


static func _drop(base: Color) -> Image:
	var image := _canvas(7, 9)
	_poly(image, PackedVector2Array([Vector2(3.5, 0), Vector2(6.5, 5), Vector2(5, 8.5), Vector2(2, 8.5), Vector2(0.5, 5)]), base)
	image.set_pixel(2, 4, Color.WHITE)
	return _outline(image, base.darkened(0.5))


## Tramo de liana con una hoja (Látigo Cepa): se repite a lo largo.
static func _vine() -> Image:
	var image := _canvas(8, 8)
	for x in 8:
		var y := 3 + int(round(sin(x * 0.9)))
		image.set_pixel(x, y, Color(0.22, 0.62, 0.18))
		image.set_pixel(x, y + 1, Color(0.14, 0.42, 0.12))
	_poly(image, PackedVector2Array([Vector2(4, 3), Vector2(7, 0.5), Vector2(6, 3)]), Color(0.45, 0.82, 0.3))
	return _outline(image, Color(0.08, 0.25, 0.08))


static func _leaf(base: Color) -> Image:
	var image := _canvas(9, 9)
	_poly(image, PackedVector2Array([Vector2(1, 8), Vector2(2, 3), Vector2(8, 1), Vector2(6, 6)]), base)
	for i in 6:
		image.set_pixel(2 + i, 7 - i, base.darkened(0.3))
	return _outline(image, base.darkened(0.6))


## Mandíbula (Mordisco, Triturar, Colmillos): arco con dientes; tint colorea los colmillos de tipo.
static func _jaw(tint: Color, top: bool) -> Image:
	var image := _canvas(27, 12)
	var gum := Color(0.75, 0.22, 0.3)
	for x in 27:
		var t := absf(x - 13.0) / 13.0
		var depth := int(round(4.0 - t * t * 3.0))
		for k in depth:
			image.set_pixel(x, k if top else 11 - k, gum)
	# Dientes en zigzag (blancos, o del color del tipo en los colmillos).
	var teeth := tint if tint != Color.WHITE else Color(0.98, 0.98, 0.95)
	for i in 6:
		var x0 := 2 + i * 4
		for k in 6:
			var w := maxi(3 - k / 2, 0)
			for dx in range(-w + 1, w):
				var px := x0 + 2 + dx
				var py := (3 + k) if top else (8 - k)
				if px >= 0 and px < 27:
					image.set_pixel(px, py, teeth)
	return _outline(image, Color(0.18, 0.08, 0.1))


## Montículo de tierra que avanza bajo el suelo (Excavar).
static func _mound() -> Image:
	var image := _canvas(17, 8)
	for x in 17:
		var t := absf(x - 8.0) / 8.5
		var h := int(round((1.0 - t * t) * 6.0))
		for k in h:
			image.set_pixel(x, 7 - k, Color(0.52, 0.36, 0.2) if k < h - 1 else Color(0.68, 0.5, 0.3))
	for i in 5:
		image.set_pixel(3 + i * 3, 5 - (i % 2), Color(0.38, 0.26, 0.14))
	return _outline(image, Color(0.22, 0.14, 0.08))


static func _rock(base: Color) -> Image:
	var image := _canvas(10, 9)
	_poly(image, PackedVector2Array([Vector2(1, 6), Vector2(2, 2), Vector2(6, 0.5), Vector2(9.5, 3), Vector2(9, 8), Vector2(3, 8.5)]), base)
	_poly(image, PackedVector2Array([Vector2(3, 3), Vector2(6, 1.5), Vector2(7, 4), Vector2(4, 5)]), base.lightened(0.25))
	return _outline(image, base.darkened(0.6))


## Marcas en el suelo (duran unos segundos): grietas, quemadura y charco.
static func _crack() -> Image:
	var image := _canvas(32, 32)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for branch in 6:
		var p := Vector2(16, 16)
		var dir := Vector2.from_angle(TAU * branch / 6.0 + rng.randf_range(-0.3, 0.3))
		for step in 14:
			p += dir
			dir = dir.rotated(rng.randf_range(-0.5, 0.5))
			if p.x >= 0 and p.y >= 0 and p.x < 32 and p.y < 32:
				image.set_pixel(int(p.x), int(p.y), Color(0.15, 0.1, 0.06, 0.9))
	return image


static func _scorch() -> Image:
	var image := _canvas(28, 28)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for y in 28:
		for x in 28:
			var d := Vector2(x - 14, y - 14).length() + rng.randf_range(-2.0, 2.0)
			if d < 12.0:
				image.set_pixel(x, y, Color(0.12, 0.08, 0.06, 0.85) if d < 8.0 else Color(0.3, 0.16, 0.08, 0.6))
	return image


static func _puddle(base: Color) -> Image:
	var image := _canvas(28, 18)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in 18:
		for x in 28:
			if Vector2((x - 14) / 13.0, (y - 9) / 8.0).length() + rng.randf_range(-0.08, 0.08) < 1.0:
				image.set_pixel(x, y, Color(base.r, base.g, base.b, 0.7))
	_disc(image, 9, 6, 2.0, Color(1, 1, 1, 0.7))
	return image


static func _star(base: Color) -> Image:
	var image := _canvas(9, 9)
	for i in 9:
		image.set_pixel(4, i, base)
		image.set_pixel(i, 4, base)
	image.set_pixel(3, 3, base)
	image.set_pixel(5, 5, base)
	image.set_pixel(3, 5, base)
	image.set_pixel(5, 3, base)
	image.set_pixel(4, 4, Color.WHITE)
	return image


static func _orb(base: Color) -> Image:
	var image := _canvas(11, 11)
	_disc(image, 5.5, 5.5, 5.0, base)
	_disc(image, 5.5, 5.5, 3.0, base.lightened(0.35))
	_disc(image, 4.0, 4.0, 1.2, Color.WHITE)
	return _outline(image, base.darkened(0.55))
