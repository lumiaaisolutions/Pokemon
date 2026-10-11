class_name RegionEpilogueCinematic
extends Node3D
## Epílogo al vencer al líder del equipo villano (revisión de Fernando, 2026-10-11
## mañana: "cinemática corta ~20 s: la base se desmorona, corte al pueblo inicial donde
## el profesor y la gente celebran, resumen del viaje"; antes era solo una caja de
## diálogo sin cinemática, ver docs/decisiones_sin_preguntar.md). Mismo patrón que
## IntroCinematic (dolly con la cámara, fundidos, se puede saltar en cualquier momento
## con Esc o Start/"menu"); la música es `bw2_the_end` (AudioBus.play_music).

const FADE_TIME := 0.5
const CRUMBLE_SECONDS := 7.0
const CELEBRATE_SECONDS := 8.0
const DUST_EVERY := 0.4
const CELEBRATE_LINES := ["¡Lo logramos!", "¡Viva!", "¡Por fin!", "¡Gracias, entrenador!"]
const TOWNSFOLK_LOOKS := ["joven_a", "chica_a", "dama_a", "guay_a"]

var player: Player
var world: WorldBuilder
var camera_rig: CameraRig
## Nodo "Music" de la escena principal (MusicDirector): se apaga mientras suena
## `bw2_the_end` y se vuelve a encender al terminar, igual que IntroCinematic.
var music: Node

var _rng := RandomNumberGenerator.new()
var _fade: ColorRect
var _skip := false
var _dolly: Node3D
var _town_actors: Array[Node3D] = []
var _dust_timer := 0.0


func _ready() -> void:
	_rng.randomize()
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
	_dolly.name = "EpilogueDolly"
	add_child(_dolly)


## Sondea el salto (igual que IntroCinematic): responde aunque un diálogo bloqueante
## esté consumiendo la entrada.
func _process(_delta: float) -> void:
	if _skip:
		return
	if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("menu"):
		_skip = true
		var dialog := _dialog()
		if dialog != null and dialog.is_open():
			dialog.close()


func _dialog() -> DialogBox:
	return get_tree().get_first_node_in_group(&"dialog_box") as DialogBox


## Juega la cinemática completa (o la salta) y, al final, muestra el resumen del viaje
## en una caja de diálogo del Narrador. arena: dónde estaba la base (para el derrumbe).
func play(arena: Vector3, summary_lines: Array[String]) -> void:
	DialogBox.blocking = true
	var original_zoom: float = camera_rig.get("_zoom")
	var original_yaw: float = camera_rig.get("_yaw_deg")
	var original_pitch: float = camera_rig.get("_pitch_deg")
	world.set_focus(_dolly)
	AudioBus.play_music("bw2_the_end")
	if music != null:
		music.set_process(false)
	await _crumble(arena)
	if not _skip:
		await _celebrate()
	await _fade_to(1.0, FADE_TIME)
	_cleanup_town()
	world.set_focus(null)
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
	var dialog := _dialog()
	if dialog != null:
		dialog.open("Narrador", summary_lines, null)
	else:
		for line: String in summary_lines:
			GameState.notice.emit(line)
	queue_free()


## La base se desmorona: polvo y temblor de cámara sobre la arena donde peleaste.
func _crumble(arena: Vector3) -> void:
	await _fade_to(1.0, FADE_TIME)
	if _skip:
		return
	_dolly.global_position = arena
	world.ensure_area(_dolly.global_position)
	camera_rig.set_target(_dolly)
	camera_rig.set("_zoom", 7.0)
	camera_rig.set("_pitch_deg", 18.0)
	camera_rig.set("_yaw_deg", 0.0)
	camera_rig.snap()
	await _fade_to(0.0, FADE_TIME)
	if _skip:
		return
	GameState.notice.emit("¡La base del %s se derrumba tras la derrota de su líder!" % GameState.villain_team)
	var elapsed := 0.0
	while elapsed < CRUMBLE_SECONDS and not _skip:
		var delta := get_process_delta_time()
		elapsed += delta
		_dust_timer -= delta
		if _dust_timer <= 0.0:
			_dust_timer = DUST_EVERY
			var at := _dolly.global_position + Vector3(_rng.randf_range(-2.4, 2.4), _rng.randf_range(0.3, 2.2), _rng.randf_range(-2.4, 2.4))
			PixelBurst.spawn(self, at, PixelBurst.Kind.DUST, 1.4)
		camera_rig.shake(0.45)
		await get_tree().process_frame


## Corte al pueblo inicial: el profesor y unos vecinos celebran con burbujas.
func _celebrate() -> void:
	await _fade_to(1.0, FADE_TIME)
	if _skip:
		return
	var start := world.layout.start
	_dolly.global_position = Vector3(start.x, 0.0, start.y)
	world.ensure_area(_dolly.global_position)
	_dolly.global_position.y = world.surface_height_at(start.x, start.y)
	_spawn_celebration()
	camera_rig.set_target(_dolly)
	camera_rig.set("_zoom", 6.0)
	camera_rig.set("_pitch_deg", 20.0)
	camera_rig.set("_yaw_deg", 0.0)
	camera_rig.snap()
	await _fade_to(0.0, FADE_TIME)
	if _skip:
		return
	var elapsed := 0.0
	var bubble_timer := 0.0
	while elapsed < CELEBRATE_SECONDS and not _skip:
		var delta := get_process_delta_time()
		elapsed += delta
		camera_rig.set("_yaw_deg", lerpf(0.0, 28.0, clampf(elapsed / CELEBRATE_SECONDS, 0.0, 1.0)))
		bubble_timer -= delta
		if bubble_timer <= 0.0:
			bubble_timer = _rng.randf_range(1.1, 2.0)
			for actor in _town_actors:
				if is_instance_valid(actor) and _rng.randf() < 0.55:
					SpeechBubbles.say(actor, CELEBRATE_LINES[_rng.randi() % CELEBRATE_LINES.size()])
		await get_tree().process_frame


func _spawn_celebration() -> void:
	var prof := Node3D.new()
	prof.name = "EpilogueProfessor"
	add_child(prof)
	prof.global_position = _dolly.global_position + Vector3(-1.5, 0, 0.6)
	prof.global_position.y = world.surface_height_at(prof.global_position.x, prof.global_position.z)
	var prof_sprite := DirectionalSprite.new()
	prof_sprite.name = "Sprite"
	prof.add_child(prof_sprite)
	prof_sprite.setup(NpcLooks.sheet(Professor.look()), 3, 8, 0.057)
	prof_sprite.look_at_point(_dolly.global_position)
	_town_actors.append(prof)
	for i in 3:
		var npc := Node3D.new()
		npc.name = "EpilogueTownsfolk%d" % i
		add_child(npc)
		var angle := TAU * i / 3.0 + 0.6
		npc.global_position = _dolly.global_position + Vector3(cos(angle), 0, sin(angle)) * 2.0
		npc.global_position.y = world.surface_height_at(npc.global_position.x, npc.global_position.z)
		var sprite := DirectionalSprite.new()
		sprite.name = "Sprite"
		npc.add_child(sprite)
		sprite.setup(NpcLooks.sheet(TOWNSFOLK_LOOKS[i % TOWNSFOLK_LOOKS.size()]), 3, 8, 0.057)
		sprite.look_at_point(_dolly.global_position)
		_town_actors.append(npc)


func _cleanup_town() -> void:
	for actor in _town_actors:
		if is_instance_valid(actor):
			actor.queue_free()
	_town_actors.clear()


func _fade_to(alpha: float, seconds: float) -> void:
	if _skip:
		_fade.color.a = alpha
		return
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, seconds)
	await tween.finished
