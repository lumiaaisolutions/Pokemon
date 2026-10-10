class_name Items
extends RefCounted
## Catálogo de objetos (creatures/data/items.json) más las megapiedras, que salen del
## catálogo de megas. Cada objeto es un diccionario con id, name, pocket, desc, price
## y su efecto (ball, heal_companion, heal_hearts, repel, lure, boost…).

const CATALOG_PATH := "res://creatures/data/items.json"
const ICON_DIR := "res://art/items/"

static var _items := {}
static var _pockets: Array = []
static var _recipes: Array = []
static var _start := {}
static var _icons := {}


static func _ensure() -> void:
	if not _items.is_empty():
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	_pockets = data["pockets"]
	_recipes = data["recipes"]
	_start = data["start"]
	for item: Dictionary in data["items"]:
		_items[item["id"]] = item
	# Megapiedras: una por mega (Rayquaza no usa).
	var megas := MegaCatalog.load_catalog()
	if megas != null:
		for mega in megas.megas:
			if mega.stone == "":
				continue
			var id := "stone-" + mega.identifier
			_items[id] = {"id": id, "name": mega.stone, "pocket": "megapiedras", "price": 0, "key": true,
					"mega": mega.identifier, "desc": "Permite que %s megaevolucione a %s (con la Piedra Llave)." % [mega.base_species.capitalize(), mega.display_name]}


static func get_item(id: String) -> Dictionary:
	_ensure()
	return _items.get(id, {})


static func exists(id: String) -> bool:
	_ensure()
	return _items.has(id)


static func pockets() -> Array:
	_ensure()
	return _pockets


static func recipes() -> Array:
	_ensure()
	return _recipes


## Objetos con que empieza la partida: id -> cantidad.
static func starting_bag() -> Dictionary:
	_ensure()
	return _start.duplicate()


static func display_name(id: String) -> String:
	return get_item(id).get("name", id)


## Ids de las balls del catálogo, en orden.
static func ball_ids() -> Array[String]:
	_ensure()
	var result: Array[String] = []
	for id: String in _items:
		if _items[id].has("ball"):
			result.append(id)
	return result


## Ícono del objeto (24 px). Las megapiedras y la Piedra Llave se dibujan aquí.
static func icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var path := ICON_DIR + id + ".png"
	var texture: Texture2D
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	elif id == "mystic-fragment":
		texture = _orb_icon(Color(0.72, 0.5, 1.0))
	elif id.begins_with("stone-") or id == "key-stone":
		texture = _orb_icon(Color(0.95, 0.55, 0.85) if id.begins_with("stone-") else Color(0.5, 0.75, 1.0))
	else:
		texture = _orb_icon(Color(0.7, 0.7, 0.7))
	_icons[id] = texture
	return texture


## Esfera pixel art con el símbolo de la megaevolución (doble hélice estilizada).
static func _orb_icon(color: Color) -> Texture2D:
	var image := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 24:
			var d := Vector2(x - 11.5, y - 11.5).length()
			if d <= 8.5:
				var c := color.darkened(0.35) if d > 7.5 else color.lerp(Color.WHITE, clampf((8.0 - d) / 16.0, 0.0, 0.4))
				image.set_pixel(x, y, c)
	for i in 9:
		image.set_pixel(8 + i, 12 + int(round(sin(i * 0.8) * 2.0)), Color(1, 1, 1))
		image.set_pixel(8 + i, 12 - int(round(sin(i * 0.8) * 2.0)), Color(0.35, 0.2, 0.45))
	image.set_pixel(9, 8, Color.WHITE)
	image.set_pixel(10, 8, Color.WHITE)
	image.set_pixel(9, 9, Color.WHITE)
	return ImageTexture.create_from_image(image)
