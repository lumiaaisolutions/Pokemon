class_name TownTransport
extends RefCounted
## Transporte entre pueblos visitados (mundo más lleno, acordado con Fernando
## 2026-10-10: "carruaje, bote o Pokémon taxi"). Cada pueblo y ciudad tiene una parada
## junto a su plaza principal; desde ahí se puede viajar a cualquier otro asentamiento
## que ya hayas visitado, por un precio según la distancia (ver docs/decisiones_sin_preguntar.md
## para el porqué de un solo modelo visual con texto distinto por tema).

const COST_PER_KM := 120
const MIN_COST := 150


## Marca como visitado el asentamiento donde esté el jugador ahora mismo. Se llama cada
## cuadro desde Structures._process (que ya recorre el mundo entero cada cuadro).
static func update_visited(world: WorldBuilder, player: Node3D) -> void:
	if player == null or not is_instance_valid(player):
		return
	var pos := Vector2(player.global_position.x, player.global_position.z)
	for settlement: Dictionary in world.layout.settlements:
		var name: String = settlement["name"]
		var visited: Dictionary = GameState.world_flags.get("visited_towns", {})
		if visited.has(name):
			continue
		if pos.distance_to(Vector2(float(settlement["x"]), float(settlement["z"]))) < float(settlement["radius"]):
			visited[name] = true
			GameState.world_flags["visited_towns"] = visited


static func visited_names() -> Array:
	return (GameState.world_flags.get("visited_towns", {}) as Dictionary).keys()


## Parada de transporte junto a la plaza (carruaje sencillo, igual en todos los temas;
## solo cambia el texto del cochero según el tema).
static func place_booth(structures: Structures, parent: Node3D, settlement: Dictionary) -> void:
	var cx := float(settlement["x"])
	var cz := float(settlement["z"])
	var radius := float(settlement["radius"])
	var root := Node3D.new()
	root.name = "Transport_" + String(settlement["name"]).replace(" ", "")
	parent.add_child(root)
	var at := Vector3(cos(-0.9) * radius * 0.26, 0, sin(-0.9) * radius * 0.26)
	root.position = Vector3(cx, float(settlement["height"]) - 0.05, cz) + at
	structures._box(root, Vector3(2.2, 1.0, 1.4), Vector3(0, 0.75, 0), Color(0.5, 0.35, 0.22))
	structures._box(root, Vector3(2.4, 0.15, 1.6), Vector3(0, 1.3, 0), Color(0.8, 0.3, 0.3))
	for side in [-1.0, 1.0]:
		var wheel := structures._cylinder(root, 0.45, 0.12, Vector3(side * 0.9, 0.45, 0.85), Color(0.25, 0.22, 0.2), -1.0, 10)
		wheel.rotation.x = PI * 0.5
	structures._collider(root, Vector3(2.4, 1.6, 1.6), Vector3(0, 0.8, 0), false)
	structures._furniture(Vector2(root.position.x, root.position.z), 1.6)
	structures.add_point(root.position + Vector3(0, 0.7, 1.2), "Viajar a otro pueblo", _open.bind(structures, settlement), 2.6)


static func _vehicle_name(settlement: Dictionary) -> String:
	match TownIdentity.theme_of(settlement):
		"fishing":
			return "bote"
		"alpine":
			return "trineo"
		_:
			return "carruaje"


static func _open(structures: Structures, settlement: Dictionary) -> void:
	var dialog := structures.get_tree().get_first_node_in_group(&"dialog_box") as DialogBox
	if dialog == null:
		return
	var here: String = settlement["name"]
	var options: Array[String] = []
	var targets: Array[Dictionary] = []
	for other: Dictionary in structures.world.layout.settlements:
		if other["name"] == here or other["kind"] not in ["city", "town", "village"]:
			continue
		if not visited_names().has(other["name"]):
			continue
		var distance := Vector2(float(other["x"]) - float(settlement["x"]), float(other["z"]) - float(settlement["z"])).length()
		var cost := maxi(int(distance * 0.001 * COST_PER_KM), MIN_COST)
		options.append("%s ($%d)" % [other["name"], cost])
		targets.append(other)
	options.append("No, gracias")
	var cochero := "Cochero" if _vehicle_name(settlement) == "carruaje" else ("Pescador" if _vehicle_name(settlement) == "bote" else "Guía")
	if targets.is_empty():
		dialog.open(cochero, ["Todavía no conoces otro pueblo al que llevarte. Explora la región y vuelve."])
		return
	dialog.open(cochero, ["¿A qué pueblo quieres viajar en %s?" % _vehicle_name(settlement)], null, options, func(choice: int) -> void:
		if choice < 0 or choice >= targets.size():
			return
		_travel(structures, settlement, targets[choice]))


static func _travel(structures: Structures, from: Dictionary, to: Dictionary) -> void:
	var distance := Vector2(float(to["x"]) - float(from["x"]), float(to["z"]) - float(from["z"])).length()
	var cost := maxi(int(distance * 0.001 * COST_PER_KM), MIN_COST)
	if GameState.money < cost:
		GameState.notice.emit("El viaje a %s cuesta $%d y no tienes suficiente dinero." % [to["name"], cost])
		return
	GameState.add_money(-cost, "Viaje a %s" % to["name"])
	var x := float(to["x"]) + 2.0
	var z := float(to["z"]) + 2.0
	structures.world.ensure_area(Vector3(x, 0, z))
	structures.services.move_party_to(Vector3(x, structures.world.height_at(x, z) + 0.5, z))
	GameState.notice.emit("Llegaste a %s en %s." % [to["name"], _vehicle_name(to)])
