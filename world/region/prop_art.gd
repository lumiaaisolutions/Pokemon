class_name PropArt
extends RefCounted
## Sprites pixel art generados por código para los biomas nuevos (no hay en el paquete
## de B2W2): cactus, palmera, hongo gigante, hongo luminoso y acacia. Contorno oscuro,
## sombreado en 3 tonos y la misma escala de píxel que el resto (0.057 m/px).

static var _cache := {}
## Textura -> kind (para que PropModels3D sepa qué malla 3D de pocas caras armar, ver
## world/region/prop_models.gd y _build_props en world/world_builder.gd).
static var _kind_of := {}

## Rocas: reusan la malla de BreakableRock.rock_mesh con color plano.
const ROCK_KINDS := ["boulder", "mossy_rock", "lava_rock", "snow_pile"]
## Troncos/madera: cilindro tumbado.
const LOG_KINDS := ["log", "mossy_log", "driftwood"]
const BONES_KINDS := ["bones"]
const SHELL_KINDS := ["shell", "shell_blue"]
## El resto (follaje, flores, hierba, cactus, hongos, coral, cristal...) usa la cruz de
## 2 planos con su textura pixel (PropModels3D.cross_mesh).


static func kind_of(texture_to_check: Texture2D) -> String:
	return _kind_of.get(texture_to_check, "")


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
		"coral":
			image = _coral(Color(1.0, 0.45, 0.55))
		"coral_blue":
			image = _coral(Color(0.4, 0.7, 1.0))
		# Kit de biomas (acordado con Fernando el 2026-10-10).
		"reeds":
			image = _reeds(false)
		"cattails":
			image = _reeds(true)
		"lily_pad":
			image = _lily_pad(false)
		"lily_flower":
			image = _lily_pad(true)
		"log":
			image = _log(false)
		"mossy_log":
			image = _log(true)
		"mossy_rock":
			image = _rock(Color(0.5, 0.5, 0.48), Color(0.35, 0.6, 0.3))
		"boulder":
			image = _rock(Color(0.58, 0.55, 0.5), Color(0, 0, 0, 0))
		"lava_rock":
			image = _rock(Color(0.25, 0.2, 0.22), Color(1.0, 0.45, 0.1))
		"toxic_mushroom":
			image = _small_mushroom(Color(0.6, 0.25, 0.75), Color(0.85, 1.0, 0.4))
		"brown_mushroom":
			image = _small_mushroom(Color(0.62, 0.42, 0.25), Color(0.95, 0.9, 0.8))
		"bones":
			image = _bones()
		"shell":
			image = _shell(Color(1.0, 0.8, 0.75))
		"shell_blue":
			image = _shell(Color(0.7, 0.85, 1.0))
		"driftwood":
			image = _driftwood()
		"ice_crystal":
			image = _crystal(Color(0.7, 0.9, 1.0))
		"snow_pile":
			image = _rock(Color(0.95, 0.97, 1.0), Color(0, 0, 0, 0))
		"old_fence":
			image = _fence()
		"flowers_pink":
			image = _flowers(Color(1.0, 0.55, 0.75))
		"flowers_blue":
			image = _flowers(Color(0.5, 0.65, 1.0))
		"flowers_white":
			image = _flowers(Color(0.98, 0.98, 0.92))
		"dry_bush":
			image = _dry_bush()
		"tuft_green":
			image = _grass_tuft(Color(0.36, 0.62, 0.3))
		"tuft_light":
			image = _grass_tuft(Color(0.5, 0.74, 0.36))
		"tuft_dry":
			image = _grass_tuft(Color(0.7, 0.62, 0.35))
		_:
			image = Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	if not kind.begins_with("tuft"):
		_outline(image)
	var result := ImageTexture.create_from_image(image)
	_cache[kind] = result
	_kind_of[result] = kind
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


static func _coral(color: Color) -> Image:
	var image := Image.create_empty(30, 30, false, Image.FORMAT_RGBA8)
	# Ramas que suben desde la base.
	for branch in 5:
		var x := 6 + branch * 4.5
		var lean := (branch - 2) * 0.35
		for y in range(29, 6 + (branch % 2) * 5, -1):
			var px := int(x + (29 - y) * lean * 0.3)
			_rect(image, px, y, 3, 1, color if y % 5 else color.lightened(0.3))
			if y % 7 == 0:
				_rect(image, px - 2, y, 2, 2, color.darkened(0.2))
	return image


static func _reeds(tops: bool) -> Image:
	var image := Image.create_empty(22, 34, false, Image.FORMAT_RGBA8)
	for i in 6:
		var x := 2 + i * 3 + (i % 2)
		var top := 4 + (i * 7) % 12
		var lean := (i - 2.5) * 0.12
		for y in range(top, 34):
			_rect(image, x + int((34 - y) * lean), y, 1, 1, Color(0.4, 0.62, 0.28) if y % 6 else Color(0.3, 0.5, 0.22))
		if tops and i % 2 == 0:
			_rect(image, x + int((34 - top) * lean) - 1, top - 1, 3, 6, Color(0.45, 0.28, 0.16))
	return image


static func _lily_pad(flower: bool) -> Image:
	var image := Image.create_empty(20, 20, false, Image.FORMAT_RGBA8)
	for y in 20:
		for x in 20:
			var v := Vector2(x - 9.5, y - 9.5)
			if v.length() < 9.0 and not (v.angle() > -0.35 and v.angle() < 0.15):
				image.set_pixel(x, y, Color(0.3, 0.6, 0.3) if (x + y) % 5 else Color(0.38, 0.7, 0.36))
	if flower:
		_rect(image, 7, 7, 6, 6, Color(1.0, 0.7, 0.85))
		_rect(image, 9, 9, 2, 2, Color(1.0, 0.9, 0.4))
	return image


static func _log(moss: bool) -> Image:
	var image := Image.create_empty(36, 14, false, Image.FORMAT_RGBA8)
	_rect(image, 2, 3, 32, 10, Color(0.48, 0.32, 0.2))
	_rect(image, 2, 3, 32, 2, Color(0.58, 0.4, 0.26))
	_rect(image, 2, 3, 5, 10, Color(0.72, 0.56, 0.38))
	_rect(image, 3, 6, 3, 4, Color(0.55, 0.4, 0.26))
	if moss:
		for x in range(8, 34, 3):
			_rect(image, x, 2, 3, 2, Color(0.35, 0.6, 0.28))
	return image


static func _rock(base: Color, accent: Color) -> Image:
	var image := Image.create_empty(28, 20, false, Image.FORMAT_RGBA8)
	for y in 20:
		var half := int(sqrt(maxf(0.0, 1.0 - pow((y - 14.0) / 14.0, 2.0))) * 13.0)
		_rect(image, 14 - half, y, half * 2, 1, base.lightened(0.15) if y < 8 else (base if y < 15 else base.darkened(0.2)))
	if accent.a > 0.0:
		for x in range(5, 23, 3):
			_rect(image, x, 3 + (x % 4), 3, 2, accent)
	return image


static func _small_mushroom(cap: Color, spots: Color) -> Image:
	var image := Image.create_empty(22, 18, false, Image.FORMAT_RGBA8)
	for i in 3:
		var cx := 4 + i * 7
		var height := 8 + (i % 2) * 4
		_rect(image, cx, 18 - height + 4, 2, height - 4, Color(0.92, 0.88, 0.8))
		_rect(image, cx - 3, 18 - height, 8, 4, cap)
		_rect(image, cx - 1, 18 - height + 1, 2, 1, spots)
	return image


static func _bones() -> Image:
	var image := Image.create_empty(26, 12, false, Image.FORMAT_RGBA8)
	var bone := Color(0.92, 0.9, 0.82)
	_rect(image, 3, 6, 18, 2, bone)
	_rect(image, 1, 4, 3, 6, bone)
	_rect(image, 20, 4, 3, 6, bone)
	_rect(image, 14, 1, 8, 7, bone)
	_rect(image, 16, 3, 2, 2, Color(0.2, 0.18, 0.18))
	return image


static func _shell(color: Color) -> Image:
	var image := Image.create_empty(12, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		var half := int((y + 1) * 0.6)
		_rect(image, 6 - half, y, half * 2, 1, color if y % 3 else color.darkened(0.2))
	return image


static func _driftwood() -> Image:
	var image := Image.create_empty(34, 10, false, Image.FORMAT_RGBA8)
	for x in 32:
		_rect(image, x + 1, 4 + int(sin(x * 0.4) * 2.0), 1, 4, Color(0.75, 0.68, 0.58) if x % 5 else Color(0.62, 0.55, 0.46))
	return image


static func _crystal(color: Color) -> Image:
	var image := Image.create_empty(20, 30, false, Image.FORMAT_RGBA8)
	for i in 3:
		var cx := 4 + i * 6
		var top := 4 + (i % 2) * 8
		for y in range(top, 30):
			var half := clampi(int((y - top) * 0.35) + 1, 1, 3)
			_rect(image, cx - half, y, half * 2, 1, color.lightened(0.3) if (y - top) < 4 else color)
	return image


static func _fence() -> Image:
	var image := Image.create_empty(36, 20, false, Image.FORMAT_RGBA8)
	var wood := Color(0.55, 0.42, 0.3)
	for x in [2, 16, 30]:
		_rect(image, x, 2, 4, 18, wood)
	_rect(image, 2, 6, 32, 3, wood.lightened(0.1))
	_rect(image, 2, 12, 20, 3, wood.lightened(0.1))
	return image


## Mata de flores: montículo de hojas con flores encima (sin tallos sueltos que se veían
## cortados contra el suelo).
static func _flowers(color: Color) -> Image:
	var image := Image.create_empty(26, 16, false, Image.FORMAT_RGBA8)
	var leaf := Color(0.32, 0.6, 0.3)
	var leaf_dark := Color(0.24, 0.46, 0.24)
	for y in 16:
		var half := int(sqrt(maxf(0.0, 1.0 - pow((y - 15.0) / 10.0, 2.0))) * 12.0)
		for x in range(13 - half, 13 + half):
			image.set_pixel(x, y, leaf if (x + y * 3) % 7 else leaf_dark)
	var spots := [Vector2i(5, 8), Vector2i(10, 6), Vector2i(15, 7), Vector2i(20, 9), Vector2i(8, 11), Vector2i(13, 10), Vector2i(18, 12)]
	for spot: Vector2i in spots:
		_rect(image, spot.x - 1, spot.y - 1, 3, 3, color)
		image.set_pixel(spot.x, spot.y, Color(1.0, 0.9, 0.35))
		image.set_pixel(spot.x - 1, spot.y - 1, color.lightened(0.3))
	return image


## Pasto menudo: hojas finas que se abren hacia los lados, base oscura y puntas claras
## (sin contorno, para que se fundan con el suelo).
static func _grass_tuft(color: Color) -> Image:
	var image := Image.create_empty(16, 12, false, Image.FORMAT_RGBA8)
	var blades := [[7, 11, 0.0], [5, 8, -0.45], [9, 9, 0.4], [3, 6, -0.8], [11, 6, 0.75], [8, 5, 0.15]]
	for blade: Array in blades:
		var base_x: float = blade[0]
		var height: int = blade[1]
		var lean: float = blade[2]
		for step in height:
			var t := float(step) / height
			var x := int(round(base_x + lean * step * 0.6 + 0.5))
			var y := 11 - step
			if x >= 0 and x < 16 and y >= 0:
				image.set_pixel(x, y, color.darkened(0.25).lerp(color.lightened(0.25), t))
	return image


static func _dry_bush() -> Image:
	var image := Image.create_empty(26, 18, false, Image.FORMAT_RGBA8)
	for i in 9:
		var angle := -PI * (0.1 + i * 0.1)
		for r in 12:
			_rect(image, 13 + int(cos(angle) * r), 17 + int(sin(angle) * r), 1, 1, Color(0.62, 0.5, 0.3) if r % 3 else Color(0.5, 0.38, 0.22))
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
