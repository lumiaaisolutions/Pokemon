class_name TravelTerminal
extends Node3D
## Viaje entre regiones (acordado con Fernando el 2026-10-10): una taquilla en el pueblo
## inicial de cada región, de barco (capitán) o de avión (piloto) según la región (al azar
## al generarse). Eliges una región abierta, ves una animación corta del viaje y llegas al
## pueblo inicial de la otra. Las regiones se abren con el Boleto del profesor.

const TRAVEL_SECONDS := 4.0

var _world: WorldBuilder
var _player: Player
var _main: Node
var booth_position := Vector3.INF
var _point: Dictionary = {}


func _ready() -> void:
	add_to_group(&"travel_terminal")
	_main = get_parent()
	_world = _main.get_node("World") as WorldBuilder
	_player = _main.get_node("Player") as Player
	_build.call_deferred()


static func boat() -> bool:
	return Regions.transport() == "boat"


static func operator_title() -> String:
	return "Capitán" if boat() else "Piloto"


## Lugar libre al borde de la plaza del pueblo inicial (lejos de edificios y del monumento).
func _spot(settlement: Dictionary) -> Vector2:
	var plaza := Vector2(float(settlement["x"]), float(settlement["z"]))
	var buildings: Array = settlement["buildings"]
	for ring: float in [15.0, 18.0, 22.0, 26.0]:
		for k in 16:
			var at := plaza + Vector2.from_angle(TAU * k / 16.0 + 0.3) * ring
			# Lejos del monumento y fuera de la línea por donde sale el jugador.
			var start := _world.layout.start
			if at.distance_to(plaza + Vector2(13, 0)) < 7.0 or at.distance_to(start) < 10.0 or absf(at.x - start.x) < 8.0:
				continue
			var free := true
			for b: Dictionary in buildings:
				# Los edificios giran: se usa su lado mayor en ambos ejes.
				var half := Vector2.ONE * (maxf(float(b.get("w", 10.0)), float(b.get("d", 10.0))) * 0.5 + 4.0)
				var rel := at - Vector2(float(b["x"]), float(b["z"]))
				if absf(rel.x) < half.x and absf(rel.y) < half.y:
					free = false
					break
			if free:
				return at
	return plaza + Vector2(-12, 12)


func _build() -> void:
	if _world.layout.settlements.is_empty():
		return
	var settlement: Dictionary = _world.layout.settlements[0]
	var at := _spot(settlement)
	var plaza := Vector2(float(settlement["x"]), float(settlement["z"]))
	var root := Node3D.new()
	root.name = "Terminal"
	add_child(root)
	var y := _world.surface_height_at(at.x, at.y)
	root.global_position = Vector3(at.x, y, at.y)
	# Mira hacia la plaza.
	var to_plaza := (plaza - at).normalized()
	root.rotation.y = atan2(to_plaza.x, to_plaza.y)
	var color := Color(0.2, 0.42, 0.75) if boat() else Color(0.85, 0.3, 0.3)
	# Caseta: base, mostrador, techo a dos colores y poste con el letrero.
	_box(root, Vector3(4.2, 0.25, 3.2), Vector3(0, 0.12, -0.4), Color(0.62, 0.6, 0.56), true)
	_box(root, Vector3(3.6, 2.6, 0.2), Vector3(0, 1.3, -1.8), Color(0.95, 0.94, 0.9), true)
	_box(root, Vector3(0.2, 2.6, 2.4), Vector3(-1.7, 1.3, -0.7), Color(0.95, 0.94, 0.9), true)
	_box(root, Vector3(0.2, 2.6, 2.4), Vector3(1.7, 1.3, -0.7), Color(0.95, 0.94, 0.9), true)
	_box(root, Vector3(3.6, 1.0, 0.5), Vector3(0, 0.5, 0.4), color, true)
	_box(root, Vector3(4.4, 0.3, 3.4), Vector3(0, 2.75, -0.5), color, false)
	_box(root, Vector3(4.6, 0.12, 3.6), Vector3(0, 2.95, -0.5), Color(0.98, 0.98, 0.98), false)
	var sign := Label3D.new()
	sign.text = ("⚓ Muelle\nViajes en barco a otras regiones" if boat() else "✈ Aeropuerto\nVuelos a otras regiones")
	sign.font_size = 46
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.modulate = Color(1, 1, 1)
	sign.outline_modulate = color.darkened(0.4)
	sign.position = Vector3(0, 3.6, -0.3)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(sign)
	# El capitán o el piloto detrás del mostrador.
	var npc := DirectionalSprite.new()
	npc.name = "Operator"
	root.add_child(npc)
	npc.setup(NpcLooks.sheet("marinero" if boat() else "policia"), 3, 8, 0.057)
	npc.position = Vector3(0, 0, -0.6)
	booth_position = root.global_position
	var front := root.global_position + Vector3(to_plaza.x, 0, to_plaza.y) * 1.8
	_point = _world.structures.add_point(front + Vector3.UP * 0.5, "Hablar con el %s (viajes a otras regiones)" % operator_title().to_lower(), talk, 2.4)


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, solid: bool) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh.material_override = material
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = WorldBuilder.LAYER_OBSTACLES
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.position = at
		body.add_child(shape)
		parent.add_child(body)


func _dialog() -> DialogBox:
	return get_tree().get_first_node_in_group(&"dialog_box") as DialogBox


## Regiones a las que se puede ir desde aquí (abiertas, menos la actual).
func destinations() -> Array[int]:
	var result: Array[int] = []
	for i in Regions.unlocked():
		if i != Regions.index():
			result.append(i)
	return result


func talk() -> void:
	var speaker := operator_title()
	var dialog := _dialog()
	var places := destinations()
	var vehicle := "barco" if boat() else "avión"
	if places.is_empty():
		var lines := ["Bienvenido. Desde aquí salen los %ss a otras regiones." % vehicle,
				"Necesitas el Boleto: el Prof. %s te lo da al completar esta región (8 medallas, la Liga y misiones del Rotom)." % GameState.professor]
		if dialog != null:
			dialog.open(speaker, lines, NpcLooks.portrait("marinero" if boat() else "policia"))
		else:
			GameState.notice.emit("%s: %s" % [speaker, lines[1]])
		return
	var options: Array = []
	for i in places:
		options.append(Regions.region_name(i))
	options.append("Ahora no")
	if dialog == null:
		travel_to(places[0])
		return
	dialog.open(speaker, ["¿A qué región quieres viajar en %s?" % vehicle], NpcLooks.portrait("marinero" if boat() else "policia"), options,
			func(choice: int) -> void:
				if choice < places.size():
					travel_to(places[choice]))


## Viaje: animación corta (barco o avión) y la escena se recarga en la otra región.
func travel_to(target: int, animate := true) -> void:
	if target < 0 or target >= Regions.COUNT or not GameState.regions[target]["unlocked"]:
		return
	var vehicle_boat := boat()
	if _main.has_method("sync_companion_to_party"):
		_main.sync_companion_to_party()
	if animate:
		var overlay := TravelOverlay.new()
		overlay.boat = vehicle_boat
		overlay.destination = Regions.region_name(target)
		get_tree().root.add_child(overlay)
		await get_tree().create_timer(TRAVEL_SECONDS).timeout
		overlay.finish()
	Regions.switch_to(target)
	SaveSystem.pending_position = Vector3.INF
	GameState.add_news("%s llegó a la %s." % [GameState.player_name, Regions.region_name()])
	get_tree().change_scene_to_file("res://world/main.tscn")
