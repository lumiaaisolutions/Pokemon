class_name IntroCinematic
extends Node3D
## Cinemática de inicio (acordada con Fernando el 2026-10-10, ronda de la noche): el
## profesor de la región recorre 4 lugares del mundo generado (pradera, bosque, costa y
## montaña) y conoce en cada uno a un candidato (un básico al azar de la Pokédex regional,
## del hábitat de ese lugar); narra en cajas de texto cortas con la música de introducción
## de BW2. Termina con el profesor y los 4 candidatos llegando a la plaza del pueblo
## inicial, donde StarterCeremony toma el relevo. 30-45 s; se puede saltar en cualquier
## momento con Esc o Start ("menu"); se ve una vez por partida nueva (la llama main.gd
## solo cuando GameState.party está vacío, igual que la ceremonia).

signal finished(candidates: Array[SpeciesData])

const ACTOR_SCENE := preload("res://world/actors/pokemon_actor.tscn")
const STARTER_POOL := preload("res://creatures/data/basic_pool.tres")
const STOPS: Array[Dictionary] = [
	{"label": "una pradera", "biome": RegionLayout.Biome.MEADOW},
	{"label": "un bosque", "biome": RegionLayout.Biome.FOREST},
	{"label": "la costa", "biome": RegionLayout.Biome.BEACH},
	{"label": "una montaña", "biome": RegionLayout.Biome.MOUNTAIN},
]
const FADE_TIME := 0.5
const ORBIT_DEGREES := 46.0
const ORBIT_TIME := 3.2
const SEARCH_RINGS := 45
const SEARCH_STEP := 40.0
const SEARCH_ANGLES := 12

var player: Player
var world: WorldBuilder
var camera_rig: CameraRig
var hud: Hud
## Nodo "Music" de la escena principal (MusicDirector): se apaga mientras suena la
## música de introducción y se vuelve a encender al terminar.
var music: Node

var _rng := RandomNumberGenerator.new()
var _fade: ColorRect
var _skip := false
var _dolly: Node3D
var _points: Array[Vector2] = []
var _prof_node: Node3D
var _candidate: PokemonActor


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	var hint := InputGlyph.row("menu", "Saltar (o Esc)", 20)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	layer.add_child(hint)
	_dolly = Node3D.new()
	_dolly.name = "CinematicDolly"
	add_child(_dolly)


## Sondea el salto en vez de _unhandled_input: así responde aunque un diálogo bloqueante
## esté consumiendo la entrada, y es fácil de probar con Input.action_press.
func _process(_delta: float) -> void:
	if _skip:
		return
	if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("menu"):
		_skip = true
		var dialog := _dialog()
		if dialog != null and dialog.is_open():
			dialog.close()


## Juega la cinemática completa (o la salta) y devuelve los 4 candidatos elegidos, para
## que la ceremonia del inicial los use.
func play() -> Array[SpeciesData]:
	# Se puede saltar aunque un diálogo de la narración tenga el juego en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	var candidates := _pick_candidates()
	DialogBox.blocking = true
	var original_zoom: float = camera_rig.get("_zoom")
	var original_yaw: float = camera_rig.get("_yaw_deg")
	var original_pitch: float = camera_rig.get("_pitch_deg")
	# El jugador queda congelado en su lugar: mientras la cámara viaja se descarga el
	# terreno bajo él y, con física activa, caía bajo el suelo (aparecía sin aire y se
	# desmayaba; reporte de Fernando 2026-10-11).
	var home := player.global_position
	player.process_mode = Node.PROCESS_MODE_DISABLED
	world.set_focus(_dolly)
	AudioBus.play_music("bw2_title")
	if music != null:
		music.set_process(false)
	for i in STOPS.size():
		if _skip:
			break
		await _visit(STOPS[i], _points[i], candidates[i])
	await _fade_to(1.0, FADE_TIME)
	_cleanup_visit()
	world.set_focus(null)
	# De vuelta en la plaza: se reconstruye el terreno y el jugador queda sobre el suelo.
	world.ensure_area(home)
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.respawn_at(Vector3(home.x, world.surface_height_at(home.x, home.z) + 0.3, home.z))
	if is_instance_valid(camera_rig):
		camera_rig.set_target(player)
		camera_rig.set("_zoom", original_zoom)
		camera_rig.set("_yaw_deg", original_yaw)
		camera_rig.set("_pitch_deg", original_pitch)
		camera_rig.snap()
	if music != null:
		music.set_process(true)
	DialogBox.blocking = false
	await _fade_to(0.0, FADE_TIME)
	finished.emit(candidates)
	return candidates


func _visit(stop: Dictionary, point: Vector2, species: SpeciesData) -> void:
	await _fade_to(1.0, FADE_TIME)
	if _skip:
		return
	_cleanup_visit()
	_dolly.global_position = Vector3(point.x, 0.0, point.y)
	world.ensure_area(_dolly.global_position)
	_dolly.global_position.y = world.surface_height_at(point.x, point.y)
	_spawn_professor()
	_spawn_candidate(species)
	camera_rig.set_target(_dolly)
	camera_rig.set("_zoom", 5.5)
	camera_rig.set("_pitch_deg", 16.0)
	# Siempre el mismo rumbo fijo (no el que haya dejado el jugador): junto con que el
	# profesor y el candidato están siempre en el eje X respecto al dolly (ver
	# _spawn_professor/_spawn_candidate), la cámara los enmarca lado a lado sin depender
	# de hacia dónde miraba antes.
	var base_yaw := 0.0
	camera_rig.set("_yaw_deg", base_yaw)
	camera_rig.snap()
	await _fade_to(0.0, FADE_TIME)
	if _skip:
		return
	PixelBurst.spawn(self, _candidate.global_position + Vector3.UP * 0.4, PixelBurst.Kind.LEAVES, species.size_scale)
	var elapsed := 0.0
	while elapsed < ORBIT_TIME and not _skip:
		elapsed += get_process_delta_time()
		camera_rig.set("_yaw_deg", lerpf(base_yaw, base_yaw + ORBIT_DEGREES, clampf(elapsed / ORBIT_TIME, 0.0, 1.0)))
		await get_tree().process_frame
	if _skip:
		return
	var type_name: String = MenuStyle.TYPE_NAMES[species.types[0]]
	var dialog := _dialog()
	if dialog != null:
		dialog.open(Professor.title(), [
			"Llegamos a %s." % stop["label"],
			"¡Miren! Aquí vive %s, de tipo %s. Parece %s." % [species.display_name, type_name, PokemonActor.tactic_label(species)],
		], Professor.portrait())
		await dialog.closed
	if _skip:
		return
	await get_tree().create_timer(0.4).timeout


func _cleanup_visit() -> void:
	if _prof_node != null and is_instance_valid(_prof_node):
		_prof_node.queue_free()
	_prof_node = null
	if _candidate != null and is_instance_valid(_candidate):
		_candidate.queue_free()
	_candidate = null


## Al oeste del dolly (eje X), mirando al candidato: con la cámara siempre a rumbo fijo
## (ver _visit), quedan lado a lado en el encuadre en vez de uno encima del otro.
const PROFESSOR_OFFSET := Vector3(-1.3, 0.0, 0.0)
const CANDIDATE_OFFSET := Vector3(1.3, 0.0, 0.0)


func _spawn_professor() -> void:
	var node := Node3D.new()
	node.name = "CinProfessor"
	add_child(node)
	node.global_position = _dolly.global_position + PROFESSOR_OFFSET
	node.global_position.y = world.surface_height_at(node.global_position.x, node.global_position.z)
	var sprite := DirectionalSprite.new()
	sprite.name = "Sprite"
	node.add_child(sprite)
	sprite.setup(NpcLooks.sheet(Professor.look()), 3, 8, 0.057)
	sprite.look_at_point(_dolly.global_position + CANDIDATE_OFFSET)
	_prof_node = node


func _spawn_candidate(species: SpeciesData) -> void:
	var actor := ACTOR_SCENE.instantiate() as PokemonActor
	actor.species = species
	actor.world = world
	actor.ceremony = true
	add_child(actor)
	actor.global_position = _dolly.global_position + CANDIDATE_OFFSET
	actor.global_position.y = world.surface_height_at(actor.global_position.x, actor.global_position.z)
	var sprite := actor.get_node("Sprite") as DirectionalSprite
	if sprite != null and _prof_node != null:
		sprite.look_at_point(_prof_node.global_position)
	_candidate = actor


func _fade_to(alpha: float, seconds: float) -> void:
	if _skip:
		_fade.color.a = alpha
		return
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, seconds)
	await tween.finished


func _dialog() -> DialogBox:
	return get_tree().get_first_node_in_group(&"dialog_box") as DialogBox


## 4 candidatos distintos, uno por lugar (hábitat de ese punto, Pokédex regional, básicos).
func _pick_candidates() -> Array[SpeciesData]:
	var start := world.layout.start
	var used := {}
	var result: Array[SpeciesData] = []
	_points.clear()
	for stop: Dictionary in STOPS:
		var point := _find_point(stop["biome"], start)
		_points.append(point)
		var habitat := world.habitat_at(point.x, point.y)
		# Primero el básico de ese hábitat en la Pokédex regional; si la región no tiene
		# ninguno, cualquier básico de la región; si ni eso, cualquier básico sin repetir.
		var options: Array = STARTER_POOL.species.filter(func(sp: SpeciesData) -> bool:
			return sp.habitats.has(habitat) and Regions.allows(sp) and not used.has(sp.identifier))
		if options.is_empty():
			options = STARTER_POOL.species.filter(func(sp: SpeciesData) -> bool:
				return Regions.allows(sp) and not used.has(sp.identifier))
		if options.is_empty():
			options = STARTER_POOL.species.filter(func(sp: SpeciesData) -> bool: return not used.has(sp.identifier))
		var pick: SpeciesData = options[_rng.randi() % options.size()]
		used[pick.identifier] = true
		result.append(pick)
	return result


## Punto real más cercano a start con ese bioma exacto (en espiral, sin construir zonas:
## solo consulta el ruido de RegionLayout), fuera de cualquier asentamiento (para que se
## sienta un lugar distinto del pueblo, no su propio patio) y en terreno razonablemente
## llano (nada de laderas ni orillas empinadas: la cámara quedaría pegada a la cuesta).
## Si no hay ninguno cerca (mundo raro), cae a un punto cualquiera a 400 m.
func _find_point(biome: RegionLayout.Biome, start: Vector2) -> Vector2:
	for ring in range(1, SEARCH_RINGS + 1):
		var radius := ring * SEARCH_STEP
		for a in SEARCH_ANGLES:
			var angle := TAU * a / SEARCH_ANGLES + float(ring) * 0.21
			var p := start + Vector2.from_angle(angle) * radius
			if world.region_biome_at(p.x, p.y) != biome or not world.settlement_at(p.x, p.y, 40.0).is_empty():
				continue
			if _is_flat(p):
				return p
	return start + Vector2.from_angle(_rng.randf() * TAU) * 400.0


## Terreno llano de verdad (con ríos y lagos ya tallados, a diferencia de
## RegionLayout._slope que solo mide el ruido base): nada de orillas ni laderas.
func _is_flat(p: Vector2) -> bool:
	var h := world.surface_height_at(p.x, p.y)
	for i in 4:
		var angle := TAU * i / 4.0
		var side := p + Vector2.from_angle(angle) * 6.0
		if absf(world.surface_height_at(side.x, side.y) - h) > 1.1:
			return false
	return true
