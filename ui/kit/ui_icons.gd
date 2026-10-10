class_name UiIcons
extends RefCounted
## Íconos pixel art de la interfaz (32 × 32, generados en código para no depender de
## sprites con derechos): secciones del menú, bolsillos de la mochila, tipos y acciones.
## Cuando hay un sprite del juego que sirve (Poké Ball, mapa, monedas…) se usa ese.

static var _cache := {}

const SECTION_ITEMS := {"Mochila": "", "Dinero": "nugget", "Mapa": "town-map", "Logros": "star-piece"}


## Ícono de una sección del menú o del inicio.
static func section(name: String) -> Texture2D:
	if _cache.has("s:" + name):
		return _cache["s:" + name]
	var texture: Texture2D
	match name:
		"Equipo", "Pokémon":
			texture = Items.icon("poke-ball")
		"Mapa":
			texture = Items.icon("town-map")
		"Dinero":
			texture = Items.icon("nugget")
		"Logros":
			texture = _draw(_trophy)
		"Mochila":
			texture = _draw(_bag)
		"Pokédex":
			texture = _draw(_dex)
		"Caja", "Cajas":
			texture = _draw(_box)
		"Rotom":
			var rotom := MenuStyle.species("rotom")
			texture = MenuStyle.front_sprite(rotom) if rotom != null else _draw(_dex)
		"Ficha":
			texture = _draw(_card)
		"Controles":
			texture = _draw(_pad)
		"Opciones":
			texture = _draw(_gear)
		"Guardar":
			texture = _draw(_save)
		"Continuar":
			texture = _draw(_play)
		"Nueva partida":
			texture = _draw(_star)
		"Salir":
			texture = _draw(_exit)
		_:
			texture = _draw(_dot)
	_cache["s:" + name] = texture
	return texture


## Ícono de un bolsillo de la mochila (el primer objeto típico del bolsillo).
static func pocket(id: String) -> Texture2D:
	var sample: String = {"pokeballs": "poke-ball", "curacion": "potion", "bayas": "oran-berry", "senuelos": "repel", "exploracion": "escape-rope",
			"recoleccion": "red-apricorn", "fabricacion": "", "evolucion": "fire-stone", "megapiedras": "key-stone", "equipables": "leftovers",
			"potenciadores": "x-speed", "tesoros": "nugget", "clave": "bicycle", "coleccionables": "comet-shard", "mts": "tm-fire"}.get(id, "")
	if sample == "":
		return _draw(_gear) if id == "fabricacion" else section("Mochila")
	return Items.icon(sample)


## Ícono pequeño de un tipo: círculo de su color con su inicial.
static func type_icon(type: int) -> Texture2D:
	var key := "t:%d" % type
	if _cache.has(key):
		return _cache[key]
	var image := Image.create_empty(18, 18, false, Image.FORMAT_RGBA8)
	var color: Color = AttackProjectile.TYPE_COLORS.get(type, Color.GRAY)
	for y in 18:
		for x in 18:
			var d := Vector2(x - 8.5, y - 8.5).length()
			if d <= 8.5:
				image.set_pixel(x, y, Color.WHITE if d > 6.5 else color.lightened(0.15))
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


static func _draw(painter: Callable) -> Texture2D:
	var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	painter.call(image)
	_outline(image)
	return ImageTexture.create_from_image(image)


static func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < 32 and yy < 32:
				image.set_pixel(xx, yy, color)


static func _circle(image: Image, cx: float, cy: float, r: float, color: Color) -> void:
	for y in 32:
		for x in 32:
			if Vector2(x - cx, y - cy).length() <= r:
				image.set_pixel(x, y, color)


static func _outline(image: Image) -> void:
	var copy := image.duplicate() as Image
	for y in 32:
		for x in 32:
			if copy.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx >= 0 and ny >= 0 and nx < 32 and ny < 32 and copy.get_pixel(nx, ny).a > 0.5:
					image.set_pixel(x, y, Color(0.08, 0.1, 0.2))
					break


static func _bag(image: Image) -> void:
	_rect(image, 6, 10, 20, 18, Color(0.95, 0.55, 0.25))
	_rect(image, 6, 10, 20, 5, Color(0.85, 0.4, 0.2))
	_rect(image, 11, 5, 10, 3, Color(0.6, 0.35, 0.2))
	_rect(image, 11, 5, 2, 6, Color(0.6, 0.35, 0.2))
	_rect(image, 19, 5, 2, 6, Color(0.6, 0.35, 0.2))
	_rect(image, 14, 16, 4, 4, Color(1.0, 0.9, 0.5))


static func _dex(image: Image) -> void:
	_rect(image, 6, 4, 20, 24, Color(0.9, 0.2, 0.25))
	_rect(image, 9, 7, 14, 10, Color(0.55, 0.85, 1.0))
	_circle(image, 11, 22, 2.5, Color(1, 1, 1))
	_rect(image, 16, 21, 7, 2, Color(0.3, 0.1, 0.1))


static func _box(image: Image) -> void:
	_rect(image, 5, 9, 22, 18, Color(0.55, 0.65, 0.85))
	_rect(image, 4, 7, 24, 5, Color(0.7, 0.8, 0.95))
	_rect(image, 13, 13, 6, 3, Color(0.25, 0.3, 0.45))


static func _trophy(image: Image) -> void:
	_rect(image, 9, 5, 14, 12, Color(1.0, 0.82, 0.3))
	_rect(image, 5, 7, 4, 6, Color(1.0, 0.82, 0.3))
	_rect(image, 23, 7, 4, 6, Color(1.0, 0.82, 0.3))
	_rect(image, 14, 17, 4, 6, Color(0.9, 0.7, 0.25))
	_rect(image, 9, 23, 14, 4, Color(0.75, 0.55, 0.2))


static func _card(image: Image) -> void:
	_rect(image, 3, 8, 26, 17, Color(0.95, 0.95, 1.0))
	_circle(image, 10, 15, 3.5, Color(0.9, 0.5, 0.3))
	_rect(image, 16, 12, 10, 2, Color(0.4, 0.45, 0.6))
	_rect(image, 16, 17, 8, 2, Color(0.4, 0.45, 0.6))


static func _pad(image: Image) -> void:
	_rect(image, 4, 11, 24, 12, Color(0.3, 0.35, 0.5))
	_rect(image, 4, 15, 4, 10, Color(0.3, 0.35, 0.5))
	_rect(image, 24, 15, 4, 10, Color(0.3, 0.35, 0.5))
	_rect(image, 8, 15, 6, 2, Color(0.9, 0.9, 1.0))
	_rect(image, 10, 13, 2, 6, Color(0.9, 0.9, 1.0))
	_circle(image, 21, 15, 1.5, Color(0.4, 0.8, 1.0))
	_circle(image, 24, 17, 1.5, Color(1.0, 0.4, 0.4))


static func _gear(image: Image) -> void:
	for i in 8:
		var angle := TAU * i / 8.0
		_circle(image, 16 + cos(angle) * 10, 16 + sin(angle) * 10, 3, Color(0.75, 0.8, 0.9))
	_circle(image, 16, 16, 9, Color(0.75, 0.8, 0.9))
	_circle(image, 16, 16, 4, Color(0.25, 0.3, 0.45))


static func _save(image: Image) -> void:
	_rect(image, 5, 5, 22, 22, Color(0.3, 0.5, 0.9))
	_rect(image, 9, 5, 14, 8, Color(0.9, 0.92, 1.0))
	_rect(image, 9, 17, 14, 10, Color(0.85, 0.88, 0.95))


static func _play(image: Image) -> void:
	for y in range(6, 26):
		var w := 18 - absi(y - 16) * 18 / 10
		_rect(image, 9, y, w, 1, Color(0.72, 0.95, 0.45))


static func _star(image: Image) -> void:
	for i in 5:
		var angle := -PI / 2 + TAU * i / 5.0
		_circle(image, 16 + cos(angle) * 9, 16 + sin(angle) * 9, 3.5, Color(1.0, 0.85, 0.3))
	_circle(image, 16, 16, 7, Color(1.0, 0.85, 0.3))


static func _exit(image: Image) -> void:
	_rect(image, 6, 5, 12, 22, Color(0.6, 0.65, 0.8))
	_rect(image, 16, 14, 12, 4, Color(0.95, 0.4, 0.4))
	_rect(image, 24, 11, 3, 10, Color(0.95, 0.4, 0.4))


static func _dot(image: Image) -> void:
	_circle(image, 16, 16, 7, Color(0.8, 0.85, 1.0))
