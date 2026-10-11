class_name HouseFurniture
extends RefCounted
## Catálogo de muebles 3D estilo BW2 para decorar la casa comprada (completar lo
## simplificado del mundo, 2026-10-11: "catálogo de muebles... que se compran y se
## colocan donde quieras dentro de tu casa"). Pocas caras con color plano, como el resto
## del mobiliario del pueblo (Structures._box/_cylinder); los peluches son la excepción
## permitida a "nada de sprites" (reglas_calidad #8): un Pokémon con su sprite de mundo
## (nunca de frente) sobre una base redonda. Se compran y colocan desde el modo Decorar
## de la propia casa (ver Interiors.place_furniture, TownServices.decorate_furniture_menu)
## y persisten en la partida (GameState.world_flags["house_furniture"][house_id]).

const CATALOG := {
	"bed": {"name": "Cama", "price": 1800, "footprint": Vector2(1.6, 2.4)},
	"table": {"name": "Mesa", "price": 700, "footprint": Vector2(1.4, 1.0)},
	"chair": {"name": "Silla", "price": 300, "footprint": Vector2(0.6, 0.6)},
	"rug": {"name": "Alfombra", "price": 350, "footprint": Vector2(1.8, 1.2)},
	"plant": {"name": "Planta", "price": 250, "footprint": Vector2(0.5, 0.5)},
	"poster": {"name": "Póster", "price": 180, "footprint": Vector2(0.9, 0.3)},
	"lamp": {"name": "Lámpara de pie", "price": 320, "footprint": Vector2(0.4, 0.4)},
	"plush_pikachu": {"name": "Peluche de Pikachu", "price": 500, "footprint": Vector2(0.5, 0.5), "species": "pikachu"},
	"plush_eevee": {"name": "Peluche de Eevee", "price": 500, "footprint": Vector2(0.5, 0.5), "species": "eevee"},
	"plush_snorlax": {"name": "Peluche de Snorlax", "price": 700, "footprint": Vector2(0.9, 0.9), "species": "snorlax"},
}
## Orden fijo del catálogo (menú de compra).
const ORDER := ["bed", "table", "chair", "rug", "plant", "poster", "lamp", "plush_pikachu", "plush_eevee", "plush_snorlax"]


static func price(item: String) -> int:
	return int((CATALOG.get(item, {}) as Dictionary).get("price", 0))


static func display_name(item: String) -> String:
	return String((CATALOG.get(item, {}) as Dictionary).get("name", item))


## Tamaño aproximado en el piso (ancho × profundidad), para su colisión.
static func footprint(item: String) -> Vector2:
	return (CATALOG.get(item, {}) as Dictionary).get("footprint", Vector2(0.6, 0.6))


## Modelo de pocas caras con color plano (o, en los peluches, el sprite de mundo del
## Pokémon sobre una base).
static func build(item: String) -> Node3D:
	var node := Node3D.new()
	node.name = "Furniture_%s" % item
	match item:
		"bed":
			_box(node, Vector3(1.5, 0.5, 2.3), Vector3(0, 0.25, 0), Color(0.55, 0.35, 0.22))
			_box(node, Vector3(1.4, 0.3, 2.1), Vector3(0, 0.58, 0.05), Color(0.9, 0.92, 0.95))
			_box(node, Vector3(1.4, 0.25, 0.4), Vector3(0, 0.68, -0.95), Color(0.75, 0.3, 0.35))
		"table":
			_box(node, Vector3(1.3, 0.08, 0.9), Vector3(0, 0.75, 0), Color(0.5, 0.33, 0.2))
			for sx: float in [-0.55, 0.55]:
				for sz: float in [-0.35, 0.35]:
					_box(node, Vector3(0.08, 0.75, 0.08), Vector3(sx, 0.375, sz), Color(0.4, 0.26, 0.16))
		"chair":
			_box(node, Vector3(0.5, 0.06, 0.5), Vector3(0, 0.45, 0), Color(0.5, 0.33, 0.2))
			_box(node, Vector3(0.5, 0.55, 0.06), Vector3(0, 0.72, -0.22), Color(0.45, 0.28, 0.18))
			for sx: float in [-0.2, 0.2]:
				for sz: float in [-0.2, 0.2]:
					_box(node, Vector3(0.05, 0.45, 0.05), Vector3(sx, 0.22, sz), Color(0.38, 0.24, 0.15))
		"rug":
			_box(node, Vector3(1.8, 0.03, 1.2), Vector3(0, 0.02, 0), Color(0.75, 0.3, 0.3))
			_box(node, Vector3(1.5, 0.01, 0.9), Vector3(0, 0.035, 0), Color(0.9, 0.85, 0.3))
		"plant":
			_cylinder(node, 0.22, 0.32, Vector3(0, 0.16, 0), Color(0.5, 0.32, 0.22))
			_cylinder(node, 0.3, 0.55, Vector3(0, 0.6, 0), Color(0.25, 0.55, 0.3), 0.05, 8)
		"poster":
			_box(node, Vector3(0.9, 1.2, 0.06), Vector3(0, 0.95, 0), Color(0.85, 0.2, 0.25))
			_box(node, Vector3(0.78, 1.05, 0.03), Vector3(0, 0.95, 0.045), Color(0.95, 0.9, 0.8))
		"lamp":
			_cylinder(node, 0.18, 0.04, Vector3(0, 0.02, 0), Color(0.3, 0.28, 0.25))
			_cylinder(node, 0.03, 1.3, Vector3(0, 0.67, 0), Color(0.3, 0.28, 0.25))
			_cylinder(node, 0.22, 0.3, Vector3(0, 1.35, 0), Color(0.95, 0.9, 0.7), 0.12, 10)
		_:
			# Peluches (plush_*): base redonda + sprite de mundo del Pokémon, quieto
			# (nunca se anima: frame 0, la pose de pie, ver DirectionalSprite.animate()).
			var species_id: String = (CATALOG.get(item, {}) as Dictionary).get("species", "")
			_cylinder(node, 0.3, 0.1, Vector3(0, 0.05, 0), Color(0.85, 0.8, 0.7))
			var species := MenuStyle.species(species_id)
			if species != null and species.overworld_sheet != null:
				var sprite := DirectionalSprite.new()
				sprite.position = Vector3(0, 0.1, 0)
				node.add_child(sprite)
				sprite.setup(species.overworld_sheet, 2, 4, PokemonActor.PIXEL_SIZE * species.size_scale * 32.0 / species.overworld_cell, species.foot_offset_px)
	return node


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


static func _box(parent: Node3D, size: Vector3, center: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	instance.material_override = _material(color)
	parent.add_child(instance)


static func _cylinder(parent: Node3D, radius: float, height: float, center: Vector3, color: Color, top_radius: float = -1.0, segments: int = 12) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	instance.material_override = _material(color)
	parent.add_child(instance)
