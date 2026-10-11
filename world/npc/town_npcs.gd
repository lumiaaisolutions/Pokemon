class_name TownNPCs
extends Node3D
## Habitantes de los pueblos con rutina según la hora y el clima (Fase 2.7):
## - 7:00–9:00 salen de casa y van a la plaza; 9:00–18:00 trabajan (tienda, Centro,
##   laboratorio, gimnasio) o pasean por la plaza; 18:00–21:00 se juntan en la plaza;
##   de 21:00 a 7:00 están en casa (no se ven). Con lluvia fuerte o tormenta se van a casa.
## - Caminan siempre pasando por el centro de la plaza (las puertas miran a la plaza, así
##   que el camino está despejado), con el sprite de 4 direcciones.
## - Se crean al acercarse a un pueblo (a menos de SPAWN_DISTANCE) y se liberan al alejarse.
## - Con "interact" cerca de uno, saluda según la hora, comenta el clima o da un consejo.
## La tienda abre de 8:00 a 21:00 y el gimnasio de 7:00 a 22:00 (el Centro, siempre).
## - Casi la mitad tiene su propio Pokémon, que los sigue.
## - Combates de práctica: cada tanto, dos vecinos con Pokémon que están en la plaza se
##   retan; sus Pokémon se enfrentan con embestidas y efectos y al final uno gana (si
##   estás cerca, sale el aviso). Los viajeros también retan a los vecinos.
## - Viajeros: caminan por los caminos entre pueblos cerca del jugador y de noche acampan
##   (carpa y fogata) donde estén.

const SPAWN_DISTANCE := 260.0
const DESPAWN_DISTANCE := 320.0
const WALK_SPEED := 2.2
const TALK_RADIUS := 2.2
## Menos gente y con oficio (acordado con Fernando el 2026-10-10).
const PER_KIND := {"city": 6, "town": 4, "village": 3, "cabins": 1}
## Distancia mínima entre habitantes (no se amontonan).
const PERSONAL_SPACE := 1.4
## Cuánto pasea cada oficio alrededor de su lugar (0 = se queda en su sitio).
const WANDER := {"niño": 3.0, "vecino": 2.0, "coordinador": 1.5, "abuela": 0.0, "vendedor": 0.0, "enfermera": 0.0, "investigador": 1.0, "entrenador": 2.5}
## Nombres por género (el del sprite): antes una sola lista daba "Mari" a un chico.
const MALE_NAMES := ["Beto", "Fito", "Hugo", "Joel", "Leo", "Nico", "Paco", "Quique", "Santi", "Uri", "Yayo", "Dani", "Iván", "Toño", "Raúl", "Memo"]
const FEMALE_NAMES := ["Ana", "Carla", "Elena", "Gaby", "Inés", "Karla", "Mari", "Olga", "Rosa", "Tere", "Vale", "Wendy", "Ximena", "Zoe", "Lupita", "Sofi"]
const NAMES := MALE_NAMES + FEMALE_NAMES


## Nombre al azar para un personaje de ese género ("male" o "female").
static func name_for(gender: String, rng: RandomNumberGenerator) -> String:
	var list: Array = MALE_NAMES if gender == "male" else FEMALE_NAMES
	return list[rng.randi() % list.size()]
const ROLES := ["vecino", "vendedor", "enfermera", "investigador", "entrenador", "niño", "abuela"]
## Tintes de ropa para que no se vean iguales a los protagonistas.
const PET_POOL := preload("res://creatures/data/basic_pool.tres")
const TRAVELERS := 2
const TRAVELER_SPEED := 1.8
## Charlas entre vecinos (burbujas, acordado con Fernando el 2026-10-10): intercambios de
## 2–3 frases alternadas sobre temas variados (clima, Pokémon, el gimnasio, la hora, chismes).
const CHATS := [
	["¿Viste el clima de hoy?", "Sí, raro para esta época del año."],
	["¿Ya fuiste al gimnasio?", "Voy después, ahorita entreno."],
	["¿Qué hora es?", "Ya casi es hora de comer.", "¡Se me hace tarde!"],
	["Dicen que hay Pokémon nuevos por aquí.", "¡Quiero atrapar uno!"],
	["¿Supiste el chisme del pueblo?", "¡No! Cuéntame todo.", "Luego te digo, shh."],
	["Mi Pokémon aprendió un movimiento.", "¡Qué envidia, el mío no!"],
	["¿Entrenas para el gimnasio?", "Sí, pero me falta mucho todavía."],
	["Hoy se ve bonito el cielo.", "Sí, perfecto para salir a pasear."],
]
## Qué tan cerca deben estar dos vecinos para charlar.
const CHAT_RADIUS := 3.5

@export var world_path: NodePath
@export var player_path: NodePath

var _world: WorldBuilder
var _player: Node3D
## Pueblos con habitantes creados: índice -> Array de habitantes (Dictionary).
var _towns := {}
var _rng := RandomNumberGenerator.new()
var _check_timer := 0.0
## Viajeros de los caminos: {"node", "road", "index", "dir", "camp", "point", "from", "to"}.
var _travelers: Array = []
## Combate de práctica en curso: {"a", "b", "time", "center"} o {}.
var _practice := {}
var _practice_timer := 25.0
## Charlas en curso: cada una {"a", "b", "lines", "index", "timer"}.
var _chats: Array = []
var _chat_timer := 5.0


func _ready() -> void:
	add_to_group(&"town_npcs")
	_rng.randomize()
	_world = get_node(world_path) as WorldBuilder
	_player = get_node(player_path) as Node3D


func _process(delta: float) -> void:
	if _world == null or _player == null:
		return
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 1.0
		_update_towns()
	var hour := GameState.clock_hour()
	var stormy := Weather.current in [Weather.Kind.STORM, Weather.Kind.BLIZZARD, Weather.Kind.SAND]
	for index: int in _towns:
		for npc: Dictionary in _towns[index]:
			_update_npc(npc, hour, stormy, delta)
	for traveler: Dictionary in _travelers:
		_update_traveler(traveler, hour, delta)
	_update_practice(delta)
	_update_chats(delta)


## Crea o libera los habitantes según la distancia del jugador a cada pueblo.
func _update_towns() -> void:
	_update_travelers()
	var settlements := _world.layout.settlements
	var p := _player.global_position
	for i in settlements.size():
		var s: Dictionary = settlements[i]
		var distance := Vector2(p.x - float(s["x"]), p.z - float(s["z"])).length()
		if distance < SPAWN_DISTANCE and not _towns.has(i):
			_towns[i] = _populate(i, s)
		elif distance > DESPAWN_DISTANCE and _towns.has(i):
			for npc: Dictionary in _towns[i]:
				(npc["node"] as Node).queue_free()
				if npc.has("pet"):
					(npc["pet"] as Node).queue_free()
				_world.structures.remove_point(npc["point"])
			_towns.erase(i)


## Habitantes de un pueblo (los mismos para la misma semilla).
func _populate(index: int, settlement: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(settlement["name"])) ^ _world.layout.seed
	var homes: Array = (settlement["buildings"] as Array).filter(func(b: Dictionary) -> bool: return b["kind"] in ["house", "cabin", "tent"])
	var works: Array = (settlement["buildings"] as Array).filter(func(b: Dictionary) -> bool: return b["kind"] in ["center", "mart", "lab", "gym", "contest"])
	var plaza := Vector2(float(settlement["x"]), float(settlement["z"]))
	var npcs: Array = []
	for i in int(PER_KIND.get(settlement["kind"], 3)):
		var home: Dictionary = homes[rng.randi() % homes.size()] if not homes.is_empty() else {}
		var work: Dictionary = works[rng.randi() % works.size()] if not works.is_empty() and rng.randf() < 0.6 else {}
		var role: String = ROLES[rng.randi() % ROLES.size()] if work.is_empty() else {"center": "enfermera", "mart": "vendedor", "lab": "investigador", "gym": "entrenador", "contest": "coordinador"}[work["kind"]]
		# Aspecto según su oficio (clases de BW2); su nombre, según el género del aspecto.
		var look := NpcLooks.for_role(role, rng)
		var npc := {
			"look": look,
			"name": name_for(NpcLooks.gender(look), rng),
			"role": role,
			"town": settlement["name"],
			"town_index": index,
			"home": _door(settlement, home) if not home.is_empty() else plaza + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8)),
			"work": _door(settlement, work) if not work.is_empty() else Vector2.INF,
			"plaza": plaza,
			# Su lugar propio en la plaza: repartidos en círculo para no juntarse.
			"post": Vector2.ZERO,
			"spot": plaza + Vector2.from_angle(TAU * i / float(PER_KIND.get(settlement["kind"], 3)) + rng.randf_range(-0.2, 0.2)) * rng.randf_range(6.0, 9.0),
			"wake": rng.randf_range(7.0, 9.0),
			"sleep": rng.randf_range(20.0, 22.5),
			"route": [] as Array[Vector2],
			"goal": "",
			"wait": rng.randf_range(0.0, 4.0),
		}
		var node := Node3D.new()
		node.name = "NPC_%s_%d" % [String(settlement["name"]).replace(" ", ""), i]
		add_child(node)
		var sprite := DirectionalSprite.new()
		sprite.name = "Sprite"
		sprite.step_cycle = PackedInt32Array([0, 1, 0, 2])
		sprite.walk_fps = 5.0
		node.add_child(sprite)
		sprite.setup(NpcLooks.sheet(look), 3, 8, 0.057)
		sprite.material_override = SpriteMaterials.for_texture(sprite.texture)
		var label := Label3D.new()
		label.text = npc["name"]
		label.font_size = 32
		label.pixel_size = 0.01
		label.outline_size = 8
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position.y = 2.1
		label.visibility_range_end = 14.0
		node.add_child(label)
		npc["node"] = node
		if rng.randf() < 0.45:
			npc["pet"] = _make_pet(rng)
		var start: Vector2 = npc["home"]
		node.global_position = Vector3(start.x, _world.surface_height_at(start.x, start.y), start.y)
		npc["point"] = _world.structures.add_point(node.global_position, "Hablar con %s" % npc["name"], _talk.bind(npc), TALK_RADIUS)
		npcs.append(npc)
	return npcs


## Punto frente a la puerta de un edificio (las puertas miran a la plaza).
func _door(settlement: Dictionary, building: Dictionary) -> Vector2:
	var b := Vector2(float(building["x"]), float(building["z"]))
	var to_center := (Vector2(float(settlement["x"]), float(settlement["z"])) - b).normalized()
	return b + to_center * (float(building["d"]) * 0.5 + 1.6)


## Dónde quiere estar a esta hora: "home", "plaza" o "work".
static func goal_for(npc: Dictionary, hour: float, stormy: bool) -> String:
	if hour < float(npc["wake"]) or hour >= float(npc["sleep"]) or stormy:
		return "home"
	if hour >= 18.0:
		return "plaza"
	if npc["work"] != Vector2.INF and hour >= 9.0:
		return "work"
	return "plaza"


func _update_npc(npc: Dictionary, hour: float, stormy: bool, delta: float) -> void:
	if npc.get("battling", false):
		return
	var node: Node3D = npc["node"]
	var sprite := node.get_node("Sprite") as DirectionalSprite
	# Hablando contigo: se detiene y te mira.
	if npc.get("talking", false) or npc.get("battling_player", false):
		sprite.look_at_point(_player.global_position)
		sprite.animate(Vector3.ZERO, delta)
		return
	# En el pueblo solo retan al verte los peleoneros (oficio "entrenador").
	if npc["role"] == "entrenador" and node.visible and _sight_update(npc, "entrenador", sprite, delta):
		return
	var goal := goal_for(npc, hour, stormy)
	if goal != npc["goal"]:
		npc["goal"] = goal
		if not npc.has("post_set"):
			npc["post"] = npc["spot"]
			npc["post_set"] = true
		var target: Vector2 = {"home": npc["home"], "plaza": npc["spot"], "work": npc["work"]}[goal]
		var here := Vector2(node.global_position.x, node.global_position.z)
		var route: Array[Vector2] = []
		# Siempre por la plaza: las puertas miran a ella.
		if here.distance_to(npc["plaza"]) > 4.0 and target.distance_to(npc["plaza"]) > 4.0:
			route.append(npc["plaza"])
		route.append(target)
		npc["route"] = route
		node.visible = true
	var route: Array[Vector2] = npc["route"]
	var velocity := Vector3.ZERO
	if not route.is_empty():
		var here := Vector2(node.global_position.x, node.global_position.z)
		var to := route[0] - here
		if to.length() < 0.3:
			route.pop_front()
			if route.is_empty() and goal == "home":
				node.visible = false # Entró a su casa.
		else:
			var step := to.normalized() * minf(WALK_SPEED * delta, to.length())
			velocity = Vector3(to.normalized().x, 0, to.normalized().y) * WALK_SPEED
			node.global_position.x += step.x
			node.global_position.z += step.y
	elif goal == "plaza" and node.visible:
		# Pasea solo alrededor de su lugar, según su oficio (la abuela se queda quieta).
		var wander := float(WANDER.get(npc["role"], 2.0))
		npc["wait"] = float(npc["wait"]) - delta
		if wander > 0.0 and float(npc["wait"]) <= 0.0:
			npc["wait"] = _rng.randf_range(5.0, 12.0)
			npc["spot"] = (npc["post"] as Vector2) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, wander)
			npc["route"] = [npc["spot"]] as Array[Vector2]
	# Espacio personal: solo quietos en la plaza (yendo a casa o al trabajo, quienes
	# comparten puerta se empujarían y nadie llegaría).
	if node.visible and goal == "plaza" and route.is_empty():
		for other: Dictionary in _towns.get(npc.get("town_index", -1), []):
			if other == npc or not (other["node"] as Node3D).visible:
				continue
			var away := node.global_position - (other["node"] as Node3D).global_position
			away.y = 0.0
			if away.length() < PERSONAL_SPACE and away.length() > 0.01:
				node.global_position += away.normalized() * (PERSONAL_SPACE - away.length()) * 0.5
	node.global_position.y = _stand_y(node)
	if velocity == Vector3.ZERO and node.visible and _player.global_position.distance_to(node.global_position) < 4.0:
		sprite.look_at_point(_player.global_position)
	sprite.animate(velocity, delta)
	if npc.has("pet"):
		_follow(npc["pet"], node, sprite, velocity, delta)
	var point: Dictionary = npc["point"]
	point["pos"] = node.global_position + Vector3.UP * 0.5
	point["radius"] = TALK_RADIUS if node.visible else 0.0


## Altura donde se para: en el suelo, o nadando (hundido hasta medio cuerpo, con
## ondas) si el agua es profunda.
func _stand_y(node: Node3D) -> float:
	return swim_height(_world, node)


static func swim_height(world: WorldBuilder, node: Node3D) -> float:
	var x := node.global_position.x
	var z := node.global_position.z
	var ground := world.surface_height_at(x, z)
	var depth := world.water_depth_at(x, z)
	var swimming := depth > 0.55
	_set_ripples(node, swimming)
	return world.water_level_at(x, z) - 0.6 if swimming else ground


## Ondas en el agua alrededor de quien nada.
static func _set_ripples(node: Node3D, on: bool) -> void:
	var ripples := node.get_node_or_null("Ripples") as CPUParticles3D
	if ripples == null:
		if not on:
			return
		ripples = CPUParticles3D.new()
		ripples.name = "Ripples"
		var quad := QuadMesh.new()
		quad.size = Vector2(0.9, 0.9)
		quad.orientation = PlaneMesh.FACE_Y
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.vertex_color_use_as_albedo = true
		material.albedo_texture = _ring_texture()
		quad.material = material
		ripples.mesh = quad
		ripples.amount = 3
		ripples.lifetime = 1.2
		ripples.gravity = Vector3.ZERO
		ripples.scale_amount_min = 0.6
		ripples.scale_amount_max = 1.8
		var grow := Curve.new()
		grow.add_point(Vector2(0, 0.4))
		grow.add_point(Vector2(1, 1.6))
		ripples.scale_amount_curve = grow
		var fade := Gradient.new()
		fade.colors = PackedColorArray([Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
		ripples.color_ramp = fade
		ripples.position.y = 0.62
		node.add_child(ripples)
	ripples.emitting = on


static var _ring: Texture2D


static func _ring_texture() -> Texture2D:
	if _ring == null:
		var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length()
				if d > 12.0 and d < 15.0:
					image.set_pixel(x, y, Color(1, 1, 1, 0.9))
		_ring = ImageTexture.create_from_image(image)
	return _ring


## Pokémon pequeño de un habitante (sprite de 4 direcciones que lo sigue).
func _make_pet(rng: RandomNumberGenerator) -> Node3D:
	var species: SpeciesData = null
	for attempt in 20:
		var candidate: SpeciesData = PET_POOL.species[rng.randi() % PET_POOL.species.size()]
		if candidate.size_scale <= 1.0 and candidate.overworld_sheet != null:
			species = candidate
			break
	var pet := Node3D.new()
	pet.name = "Pet"
	add_child(pet)
	if species == null:
		return pet
	var sprite := DirectionalSprite.new()
	sprite.name = "Sprite"
	pet.add_child(sprite)
	sprite.setup(species.overworld_sheet, 2, 4, PokemonActor.PIXEL_SIZE * species.size_scale * 32.0 / species.overworld_cell, species.foot_offset_px)
	pet.set_meta("species", species.identifier)
	return pet


func _follow(pet: Node3D, owner_node: Node3D, owner_sprite: DirectionalSprite, velocity: Vector3, delta: float) -> void:
	pet.visible = owner_node.visible
	var behind := owner_node.global_position - owner_sprite.facing_world * 1.3
	var before := pet.global_position
	if before.distance_to(behind) > 8.0:
		pet.global_position = behind
	else:
		pet.global_position = before.lerp(behind, minf(delta * 3.0, 1.0))
	pet.global_position.y = _stand_y(pet)
	var sprite := pet.get_node_or_null("Sprite") as DirectionalSprite
	if sprite != null:
		sprite.animate((pet.global_position - before) / maxf(delta, 0.001) if velocity != Vector3.ZERO else Vector3.ZERO, delta)


# --- Viajeros de los caminos ------------------------------------------------------------

## Mantiene TRAVELERS viajeros en caminos cercanos (fuera de los pueblos).
func _update_travelers() -> void:
	var p := _player.global_position
	for traveler: Dictionary in _travelers.duplicate():
		var node: Node3D = traveler["node"]
		if node.global_position.distance_to(p) > 220.0 or p.x > WorldBuilder.INTERIOR_X:
			# Su campamento se va con él (antes quedaba la fogata encendida de día).
			if traveler["camp"] != null and is_instance_valid(traveler["camp"]):
				(traveler["camp"] as Node).queue_free()
			if traveler["pet"] != null and is_instance_valid(traveler["pet"]):
				(traveler["pet"] as Node).queue_free()
			node.queue_free()
			_world.structures.remove_point(traveler["point"])
			_travelers.erase(traveler)
	if _travelers.size() >= TRAVELERS or p.x > WorldBuilder.INTERIOR_X or _world.layout.roads.is_empty():
		return
	# Puntos de camino a 50–150 m del jugador y fuera de los pueblos (antes se probaban
	# 12 puntos al azar de toda la región y casi nunca caía uno cerca).
	var candidates: Array = []
	var here := Vector2(p.x, p.z)
	for r in _world.layout.roads.size():
		var road: PackedVector2Array = _world.layout.roads[r]
		for i in road.size():
			var distance := road[i].distance_to(here)
			if distance >= 50.0 and distance <= 150.0:
				candidates.append([r, i])
	candidates.shuffle()
	for candidate: Array in candidates.slice(0, 12):
		var road: PackedVector2Array = _world.layout.roads[candidate[0]]
		var at := road[candidate[1]]
		if not _world.settlement_at(at.x, at.y, 30.0).is_empty():
			continue
		_travelers.append(_make_traveler(candidate[0], candidate[1], at))
		return


func _make_traveler(road_index: int, point_index: int, at: Vector2) -> Dictionary:
	var look := NpcLooks.for_role("viajero", _rng)
	var node := Node3D.new()
	node.name = "Traveler"
	add_child(node)
	var sprite := DirectionalSprite.new()
	sprite.name = "Sprite"
	sprite.step_cycle = PackedInt32Array([0, 1, 0, 2])
	sprite.walk_fps = 5.0
	node.add_child(sprite)
	sprite.setup(NpcLooks.sheet(look), 3, 8, 0.057)
	sprite.material_override = SpriteMaterials.for_texture(sprite.texture)
	node.global_position = Vector3(at.x, _world.surface_height_at(at.x, at.y), at.y)
	var names := _world.layout.settlements.map(func(s: Dictionary) -> String: return s["name"])
	var traveler := {"look": look, "node": node, "road": road_index, "index": point_index, "dir": 1 if _rng.randf() < 0.5 else -1, "camp": null,
			"name": name_for(NpcLooks.gender(look), _rng), "from": names[_rng.randi() % names.size()], "to": names[_rng.randi() % names.size()]}
	traveler["pet"] = _make_pet(_rng) if _rng.randf() < 0.6 else null
	traveler["point"] = _world.structures.add_point(node.global_position, "Hablar con %s (viajero)" % traveler["name"], _talk_traveler.bind(traveler), TALK_RADIUS)
	return traveler


## Camina por el camino; de noche (21:00–6:00) acampa con carpa y fogata.
func _update_traveler(traveler: Dictionary, hour: float, delta: float) -> void:
	var node: Node3D = traveler["node"]
	var sprite := node.get_node("Sprite") as DirectionalSprite
	var velocity := Vector3.ZERO
	if traveler.get("talking", false) or traveler.get("battling_player", false):
		sprite.look_at_point(_player.global_position)
		sprite.animate(Vector3.ZERO, delta)
		return
	# Fuera del pueblo, los viajeros con Pokémon y ganas de pelear te retan al verte.
	if traveler["camp"] == null and _sight_update(traveler, "viajero", sprite, delta):
		return
	var night := hour >= 21.0 or hour < 6.0
	# Nunca acampan dentro de un pueblo: siguen caminando hasta salir.
	if night and traveler["camp"] == null and not _world.settlement_at(node.global_position.x, node.global_position.z, 25.0).is_empty():
		night = false
	var camp := traveler["camp"] as Camp
	if camp != null and not is_instance_valid(camp):
		traveler["camp"] = null
		camp = null
	if night:
		if camp == null:
			# Arma su campamento junto a él (animación: se agacha y la carpa se levanta).
			var at := node.global_position + Vector3(2.0, 0, 0)
			at.y = _world.surface_height_at(at.x, at.z)
			camp = Camp.create(self, at, hash(traveler["name"]))
			camp.pitch(sprite)
			traveler["camp"] = camp
	elif camp != null and not camp.busy and not traveler.get("packing", false):
		# Amanece: apaga el fuego, recoge la carpa y sigue su camino.
		traveler["packing"] = true
		camp.pack(sprite)
		camp.tree_exited.connect(func() -> void:
			traveler["camp"] = null
			traveler["packing"] = false)
	if camp != null and (camp.busy or traveler.get("packing", false)):
		sprite.animate(Vector3.ZERO, delta)
		return
	# De día camina por su camino; de noche se queda junto a su fogata.
	if not night:
		var road: PackedVector2Array = _world.layout.roads[traveler["road"]]
		var target := road[clampi(int(traveler["index"]), 0, road.size() - 1)]
		var here := Vector2(node.global_position.x, node.global_position.z)
		var to := target - here
		if to.length() < 0.5:
			var next := int(traveler["index"]) + int(traveler["dir"])
			if next < 0 or next >= road.size():
				traveler["dir"] = -int(traveler["dir"])
				next = int(traveler["index"]) + int(traveler["dir"])
			traveler["index"] = next
		else:
			var move := to.normalized() * minf(TRAVELER_SPEED * delta, to.length())
			node.global_position.x += move.x
			node.global_position.z += move.y
			velocity = Vector3(to.normalized().x, 0, to.normalized().y) * TRAVELER_SPEED
	node.global_position.y = _stand_y(node)
	if velocity == Vector3.ZERO and _player.global_position.distance_to(node.global_position) < 4.0:
		sprite.look_at_point(_player.global_position)
	sprite.animate(velocity, delta)
	if traveler["pet"] != null:
		_follow(traveler["pet"], node, sprite, velocity, delta)
	(traveler["point"] as Dictionary)["pos"] = node.global_position + Vector3.UP * 0.5


func travelers() -> Array:
	return _travelers


# --- Combates de práctica entre habitantes ----------------------------------------------

func _update_practice(delta: float) -> void:
	if not _practice.is_empty():
		_run_practice(delta)
		return
	_practice_timer -= delta
	if _practice_timer > 0.0:
		return
	_practice_timer = _rng.randf_range(25.0, 50.0)
	# Dos vecinos con Pokémon, visibles y quietos en la plaza, del mismo pueblo.
	for index: int in _towns:
		var ready: Array = (_towns[index] as Array).filter(func(n: Dictionary) -> bool:
			return n.has("pet") and (n["node"] as Node3D).visible and n["goal"] == "plaza" and (n["route"] as Array).is_empty())
		if ready.size() >= 2:
			_start_practice(ready[0], ready[1])
			return


func _start_practice(a: Dictionary, b: Dictionary) -> void:
	var node_a: Node3D = a["node"]
	var node_b: Node3D = b["node"]
	var center := (node_a.global_position + node_b.global_position) * 0.5
	var axis := (node_b.global_position - node_a.global_position)
	axis.y = 0.0
	axis = axis.normalized() if axis.length() > 0.1 else Vector3.RIGHT
	a["battling"] = true
	b["battling"] = true
	node_a.global_position = center - axis * 3.2
	node_b.global_position = center + axis * 3.2
	_practice = {"a": a, "b": b, "time": 0.0, "center": center, "axis": axis, "hits": [0, 0], "next_hit": 0.6}


func _run_practice(delta: float) -> void:
	var a: Dictionary = _practice["a"]
	var b: Dictionary = _practice["b"]
	if not is_instance_valid(a["node"]) or not is_instance_valid(b["node"]) or not is_instance_valid(a["pet"]) or not is_instance_valid(b["pet"]):
		_practice = {}
		return
	_practice["time"] = float(_practice["time"]) + delta
	var center: Vector3 = _practice["center"]
	var axis: Vector3 = _practice["axis"]
	var pet_a: Node3D = a["pet"]
	var pet_b: Node3D = b["pet"]
	var t := float(_practice["time"])
	# Se acercan, se embisten por turnos y retroceden.
	var lunge_a := maxf(sin(t * 3.0), 0.0) * 0.9
	var lunge_b := maxf(-sin(t * 3.0), 0.0) * 0.9
	pet_a.global_position = center - axis * (1.5 - lunge_a)
	pet_b.global_position = center + axis * (1.5 - lunge_b)
	for pet: Node3D in [pet_a, pet_b]:
		pet.global_position.y = _stand_y(pet)
		var sprite := pet.get_node_or_null("Sprite") as DirectionalSprite
		if sprite != null:
			sprite.look_at_point(center)
			sprite.animate(Vector3.ZERO, delta)
	for owner_npc: Dictionary in [a, b]:
		var sprite := (owner_npc["node"] as Node3D).get_node("Sprite") as DirectionalSprite
		sprite.look_at_point(center)
		sprite.animate(Vector3.ZERO, delta)
	_practice["next_hit"] = float(_practice["next_hit"]) - delta
	if float(_practice["next_hit"]) <= 0.0:
		_practice["next_hit"] = _rng.randf_range(0.8, 1.3)
		var hitter := _rng.randi() % 2
		(_practice["hits"] as Array)[hitter] = int(_practice["hits"][hitter]) + 1
		var target: Node3D = pet_b if hitter == 0 else pet_a
		PixelBurst.spawn(self, target.global_position + Vector3.UP * 0.4, PixelBurst.Kind.DUST, 0.5)
	if t >= 9.0:
		var hits: Array = _practice["hits"]
		var winner: Dictionary = a if int(hits[0]) >= int(hits[1]) else b
		var loser: Dictionary = b if winner == a else a
		if _player.global_position.distance_to(center) < 30.0:
			GameState.notice.emit("Combate de práctica: el %s de %s venció al %s de %s." % [_pet_name(winner["pet"]), winner["name"], _pet_name(loser["pet"]), loser["name"]])
		PixelBurst.spawn(self, (loser["pet"] as Node3D).global_position + Vector3.UP * 0.4, PixelBurst.Kind.SMOKE, 0.6)
		a["battling"] = false
		b["battling"] = false
		a["goal"] = ""
		b["goal"] = ""
		_practice = {}


func _pet_name(pet: Node3D) -> String:
	var species := MenuStyle.species(String(pet.get_meta("species", "")))
	return species.display_name if species != null else "Pokémon"


## Hay un combate de práctica ahora (pruebas).
func practice_active() -> bool:
	return not _practice.is_empty()


# --- Burbujas: charlas entre vecinos y comentarios del clima o la hora -----------------

## Avanza las charlas en curso (una burbuja por turno) y, de vez en cuando, intenta
## empezar una nueva (entre dos vecinos juntos en la plaza, o un comentario suelto).
func _update_chats(delta: float) -> void:
	for chat: Dictionary in _chats.duplicate():
		chat["timer"] = float(chat["timer"]) - delta
		if float(chat["timer"]) > 0.0:
			continue
		var lines: Array = chat["lines"]
		var index: int = chat["index"]
		if index >= lines.size():
			_chats.erase(chat)
			continue
		var speaker: Dictionary = chat["a"] if index % 2 == 0 else chat["b"]
		var node := speaker["node"] as Node3D
		if is_instance_valid(node) and node.visible and not speaker.get("talking", false) and not speaker.get("battling", false) and not speaker.get("battling_player", false):
			SpeechBubbles.say(node, lines[index])
		chat["index"] = index + 1
		chat["timer"] = _rng.randf_range(2.6, 3.2)
	_chat_timer -= delta
	if _chat_timer > 0.0:
		return
	_chat_timer = _rng.randf_range(5.0, 9.0)
	if _rng.randf() < 0.4:
		_try_solo_comment()
	else:
		_try_start_chat()


## Dos vecinos libres, cerca entre sí y del jugador, cambian unas frases.
func _try_start_chat() -> void:
	for index: int in _towns:
		var ready: Array = (_towns[index] as Array).filter(func(n: Dictionary) -> bool:
			return n["goal"] == "plaza" and (n["node"] as Node3D).visible and not n.get("battling", false) \
					and not n.get("talking", false) and not n.get("battling_player", false) and not _in_chat(n))
		for a: Dictionary in ready:
			if not SpeechBubbles.near_player(a["node"], _player):
				continue
			for b: Dictionary in ready:
				if b != a and (a["node"] as Node3D).global_position.distance_to((b["node"] as Node3D).global_position) < CHAT_RADIUS:
					_chats.append({"a": a, "b": b, "lines": CHATS[_rng.randi() % CHATS.size()], "index": 0, "timer": 0.0})
					return


func _in_chat(npc: Dictionary) -> bool:
	return _chats.any(func(c: Dictionary) -> bool: return c["a"] == npc or c["b"] == npc)


## Un vecino cercano comenta la hora o el clima (sin necesitar pareja de charla).
func _try_solo_comment() -> bool:
	var lines := _weather_time_lines()
	if lines.is_empty():
		return false
	for index: int in _towns:
		for npc: Dictionary in _towns[index]:
			var node := npc["node"] as Node3D
			if node.visible and not npc.get("talking", false) and not npc.get("battling", false) and not npc.get("battling_player", false) and SpeechBubbles.near_player(node, _player):
				return SpeechBubbles.say(node, lines[_rng.randi() % lines.size()])
	return false


func _weather_time_lines() -> Array:
	match Weather.current:
		Weather.Kind.RAIN, Weather.Kind.STORM:
			return ["Está empezando a llover.", "¡Qué lluvia tan fuerte!"]
		Weather.Kind.SNOW, Weather.Kind.BLIZZARD:
			return ["¡Qué frío! Hoy sí hace fresco.", "Con este frío mejor abrígate."]
		Weather.Kind.SAND:
			return ["¡Esta arena no deja ver nada!"]
	var hour := GameState.clock_hour()
	if hour >= 21.0 or hour < 6.0:
		return ["Ya es tarde, me voy a casa.", "Se me hizo de noche ya."]
	if WildSpawner.current_season() == 1 and hour >= 11.0 and hour < 17.0:
		return ["¡Qué calor hace!", "Hoy sí que aprieta el sol."]
	return []


## Si hay alguien visible cerca de pos (y del jugador), reacciona con una frase al azar
## (sucesos: elegir inicial, horda, shiny, migración...).
func react(pos: Vector3, lines: Array) -> void:
	if lines.is_empty() or _player == null:
		return
	var candidates: Array = []
	for index: int in _towns:
		for npc: Dictionary in _towns[index]:
			var node := npc["node"] as Node3D
			if node.visible and not npc.get("talking", false) and not npc.get("battling", false) and not npc.get("battling_player", false) \
					and node.global_position.distance_to(pos) < SpeechBubbles.RANGE and SpeechBubbles.near_player(node, _player):
				candidates.append(node)
	for traveler: Dictionary in _travelers:
		var node := traveler["node"] as Node3D
		if not traveler.get("talking", false) and not traveler.get("battling_player", false) \
				and node.global_position.distance_to(pos) < SpeechBubbles.RANGE and SpeechBubbles.near_player(node, _player):
			candidates.append(node)
	if candidates.is_empty():
		return
	SpeechBubbles.say(candidates[_rng.randi() % candidates.size()], lines[_rng.randi() % lines.size()])


## Hay al menos una charla de vecinos en curso (pruebas).
func chats_active() -> int:
	return _chats.size()


## Fuerza una charla entre a y b ya mismo (pruebas).
func force_chat(a: Dictionary, b: Dictionary) -> void:
	_chats.append({"a": a, "b": b, "lines": CHATS[0], "index": 0, "timer": 0.0})


## Lo que dice al hablarle: saludo por hora, comentario del clima y algo de su oficio.
func _talk(npc: Dictionary) -> void:
	var hour := GameState.clock_hour()
	var greeting := "¡Buenos días!" if hour < 12.0 else ("¡Buenas tardes!" if hour < 19.0 else "¡Buenas noches!")
	var weather := ""
	match Weather.current:
		Weather.Kind.RAIN, Weather.Kind.STORM:
			weather = "Con esta lluvia salen más Pokémon de tipo Agua."
		Weather.Kind.SNOW, Weather.Kind.BLIZZARD:
			weather = "¡Qué frío! Dicen que con nieve salen Pokémon de Hielo."
		Weather.Kind.FOG:
			weather = "Con niebla aparecen Pokémon Fantasma..."
		Weather.Kind.SAND:
			weather = "La arena trae Pokémon de Tierra y Roca."
	var role_line: String = {
		"vendedor": "La tienda abre de 8:00 a 21:00. Hoy hay MT nuevas.",
		"enfermera": "En el Centro Pokémon curamos a tu equipo a cualquier hora.",
		"investigador": "El Prof. %s busca datos de todas las especies. ¡Llena tu Pokédex!" % GameState.professor,
		"entrenador": "El líder del gimnasio espera retadores de 7:00 a 22:00.",
		"coordinador": "En la Sala de Concursos se luce el dominio de los movimientos.",
		"niño": "¡Un día voy a montar un Pokémon volador como tú!",
		"abuela": "En mis tiempos íbamos a las aguas termales a descansar.",
	}.get(npc["role"], "Vivo aquí en %s. ¿Ya conoces todo el pueblo?" % npc["town"])
	var lines: Array = [greeting + " " + role_line]
	if weather != "":
		lines.append(weather)
	_converse(npc, lines, String(npc["role"]))


func _talk_traveler(traveler: Dictionary) -> void:
	var hour := GameState.clock_hour()
	var lines: Array = ["Voy de %s a %s. ¡Los caminos están llenos de Pokémon!" % [traveler["from"], traveler["to"]] if hour >= 6.0 and hour < 21.0 \
			else "Esta noche acampo aquí. Mañana sigo hacia %s." % traveler["to"]]
	# Un regalo de vez en cuando (una vez al día por viajero).
	var gift_key := "gift:%s:%d" % [traveler["name"], GameState.game_day()]
	if not GameState.world_flags.has(gift_key) and _rng.randf() < 0.3:
		GameState.world_flags[gift_key] = true
		var gift: String = ["oran-berry", "potion", "great-ball", "repel"][_rng.randi() % 4]
		lines.append("Toma, para el camino: %s." % Items.display_name(gift))
		traveler["gift"] = gift
	_converse(traveler, lines, "viajero")


## Ganas de pelear hoy según su oficio (acordado con Fernando): cambia cada día y se
## mantiene ese día.
const FIGHT_MOOD := {"entrenador": 0.8, "viajero": 0.4, "vecino": 0.3, "investigador": 0.3, "coordinador": 0.3,
		"vendedor": 0.1, "abuela": 0.1, "niño": 0.1, "enfermera": 0.05}


static func wants_fight(person: Dictionary, role: String) -> bool:
	# Las pruebas pueden fijar las ganas del día.
	if person.has("mood"):
		return bool(person["mood"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:%d" % [person.get("name", ""), person.get("town", person.get("from", "")), GameState.game_day()])
	return rng.randf() < float(FIGHT_MOOD.get(role, 0.3))


static func person_id(person: Dictionary) -> String:
	return "npc:%s:%s" % [person.get("town", person.get("from", "")), person.get("name", "")]


## Retrato: el cuadro de frente de su aspecto.
static func portrait(look: String) -> Texture2D:
	return NpcLooks.portrait(look)


func _dialog() -> DialogBox:
	return get_tree().get_first_node_in_group(&"dialog_box") as DialogBox


## Conversación: se detiene, te mira, habla en la caja y, si lleva Pokémon y hoy tiene
## ganas, ofrece pelear (premio y revancha como los entrenadores de camino).
func _converse(person: Dictionary, lines: Array, role: String) -> void:
	var dialog := _dialog()
	if dialog == null:
		GameState.notice.emit("%s: %s" % [person["name"], " ".join(lines)])
		return
	person["talking"] = true
	var has_pet: bool = person.get("pet") != null and is_instance_valid(person.get("pet")) and (person["pet"] as Node).has_meta("species")
	var options: Array = []
	var beaten := int(GameState.world_flags.get("trainer_beaten:" + person_id(person), -1)) == GameState.game_day()
	if has_pet and beaten:
		lines.append("¡Qué buen combate tuvimos! Mañana quiero la revancha.")
	elif has_pet and wants_fight(person, role):
		lines.append("Oye, ¿y si peleamos? ¡Mi %s está listo!" % MenuStyle.species(String((person["pet"] as Node).get_meta("species"))).display_name)
		options = ["Retar", "Adiós"]
	var title := "%s (%s)" % [person["name"], role]
	dialog.open(title, lines, portrait(String(person.get("look", "joven_a"))), options, func(index: int) -> void:
		if index == 0:
			_challenge_person(person, role))
	dialog.closed.connect(func() -> void:
		person["talking"] = false
		var gift := String(person.get("gift", ""))
		if gift != "":
			person.erase("gift")
			GameState.add_item(gift, 1)
			AudioBus.play_jingle("me_item")
			GameState.notice.emit("Recibiste %s." % Items.display_name(gift)), CONNECT_ONE_SHOT)


## Retos al verte (acordado con Fernando): si lleva Pokémon, hoy tiene ganas, no lo has
## vencido hoy y te ve de frente (cono de SIGHT_DISTANCE m), sale "¡!", se acerca y pelea.
## Devuelve true mientras se ocupa del movimiento (acercándose).
const SIGHT_DISTANCE := 10.0
const SIGHT_ANGLE := 38.0
const SIGHT_RETRY := 40.0


func _sight_update(person: Dictionary, role: String, sprite: DirectionalSprite, delta: float) -> bool:
	var node: Node3D = person["node"]
	var battle := get_parent().get_node_or_null("Battle") as BattleManager
	person["sight_retry"] = maxf(float(person.get("sight_retry", 0.0)) - delta, 0.0)
	if person.get("approaching", false):
		var to := _player.global_position - node.global_position
		to.y = 0.0
		if battle == null or battle.active or _player.mode != Player.Mode.WALK:
			person["approaching"] = false
			_set_mark(node, false)
			return false
		if to.length() > 2.4:
			var velocity := to.normalized() * 3.2
			node.global_position += velocity * delta
			node.global_position.y = _stand_y(node)
			sprite.animate(velocity, delta)
			return true
		person["approaching"] = false
		person["sight_retry"] = SIGHT_RETRY
		_set_mark(node, false)
		var dialog := _dialog()
		if dialog != null:
			dialog.say("%s (%s)" % [person["name"], role], "¡Te vi! ¡Mi %s y yo queremos pelear!" % _pet_name(person["pet"]))
		_challenge_person(person, role)
		return true
	if not BattleManager.enabled or battle == null or battle.active or not battle.ready_to_fight() or float(person["sight_retry"]) > 0.0:
		return false
	var pet: Variant = person.get("pet")
	if pet == null or not is_instance_valid(pet) or not (pet as Node).has_meta("species"):
		return false
	if int(GameState.world_flags.get("trainer_beaten:" + person_id(person), -1)) == GameState.game_day() or not wants_fight(person, role):
		return false
	var to_player := _player.global_position - node.global_position
	to_player.y = 0.0
	if to_player.length() > SIGHT_DISTANCE or to_player.length() < 0.1:
		return false
	if rad_to_deg(sprite.facing_world.angle_to(to_player.normalized())) > SIGHT_ANGLE:
		return false
	var query := PhysicsRayQueryParameters3D.create(node.global_position + Vector3.UP * 1.2, _player.global_position + Vector3.UP, 2)
	if not node.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return false
	person["approaching"] = true
	_set_mark(node, true)
	AudioBus.play_sfx("spotted")
	AudioBus.play_jingle("bw1_spotted")
	return true


## "¡!" rojo sobre la cabeza.
func _set_mark(node: Node3D, on: bool) -> void:
	var mark := node.get_node_or_null("Mark") as Label3D
	if mark == null:
		if not on:
			return
		mark = Label3D.new()
		mark.name = "Mark"
		mark.text = "!"
		mark.font_size = 96
		mark.outline_size = 18
		mark.modulate = Color(1.0, 0.25, 0.2)
		mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mark.no_depth_test = true
		mark.position = Vector3(0, 2.6, 0)
		node.add_child(mark)
	mark.visible = on


func _challenge_person(person: Dictionary, role: String) -> void:
	var battle := get_parent().get_node_or_null("Battle") as BattleManager
	var trainers := get_parent().get_node_or_null("RouteTrainers") as RouteTrainers
	if battle == null or trainers == null:
		return
	if not battle.ready_to_fight():
		GameState.notice.emit("Saca a tu Pokémon para pelear con %s." % person["name"])
		return
	var node: Node3D = person["node"]
	var pos := Vector2(node.global_position.x, node.global_position.z)
	var start := _world.start_position()
	var spot := {"id": person_id(person), "pos": pos, "class": role.capitalize(), "name": person["name"],
			"strength": clampf(pos.distance_to(Vector2(start.x, start.z)) / 1800.0, 0.0, 1.0)}
	var info := trainers.team_for(spot)
	info["name"] = "%s %s" % [role.capitalize(), person["name"]]
	var pet: Node3D = person["pet"]
	var own := MenuStyle.species(String(pet.get_meta("species")))
	if own != null:
		(info["team"] as Array)[0] = own
	info["at"] = node.global_position + (_player.global_position - node.global_position).normalized() * 2.5
	info["node"] = node
	person["battling_player"] = true
	pet.visible = false
	info["on_end"] = func(_result: String) -> void:
		person["battling_player"] = false
		if is_instance_valid(pet):
			pet.visible = true
	if not battle.start_trainer(info):
		person["battling_player"] = false
		pet.visible = true


## Habitantes visibles ahora (pruebas).
func visible_npcs() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for index: int in _towns:
		for npc: Dictionary in _towns[index]:
			if (npc["node"] as Node3D).visible:
				result.append(npc["node"])
	return result


func all_npcs() -> Array:
	var result: Array = []
	for index: int in _towns:
		result.append_array(_towns[index])
	return result


## Horario de los servicios (la tienda y el gimnasio cierran de noche).
static func is_open(kind: String, hour: float) -> bool:
	match kind:
		"mart":
			return hour >= 8.0 and hour < 21.0
		"gym", "contest":
			return hour >= 7.0 and hour < 22.0
	return true
