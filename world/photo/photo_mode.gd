class_name PhotoMode
extends Node
## Fotografía (Fase 5.5): con "photo" (P) se oculta la interfaz, se guarda la imagen en
## user://fotos/ y se registran los Pokémon que salen en cuadro (cerca del centro, a
## menos de 35 m y sin nada que los tape): cuentan para su investigación ("photos").
## Misión de fotografía del Rotom: cada día pide fotografiar una especie que anda cerca;
## al cumplirla da dinero y un objeto.

const PHOTO_DIR := "user://fotos/"
const RANGE := 35.0
## Fracción central de la pantalla donde cuenta un Pokémon (0.5 = mitad central).
const FRAME := 0.7
const REWARD_MONEY := 800
const REWARD_ITEMS := ["great-ball", "potion", "rare-candy", "star-piece"]
const UI_NODES := ["Hud", "MapUi", "Battle/BattleUI"]

var _main: Node
var _busy := false


func _ready() -> void:
	add_to_group(&"photo_mode")
	_main = get_parent()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("photo") and not get_tree().paused and not _busy:
		take.call_deferred()


## Saca una foto. Devuelve las especies fotografiadas.
func take() -> Array[String]:
	_busy = true
	var hidden: Array[CanvasLayer] = []
	for path in UI_NODES:
		var layer := _main.get_node_or_null(path) as CanvasLayer
		if layer != null and layer.visible:
			layer.visible = false
			hidden.append(layer)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	for layer in hidden:
		layer.visible = true
	if image != null and not image.is_empty():
		DirAccess.make_dir_recursive_absolute(PHOTO_DIR)
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		image.save_png(PHOTO_DIR + "foto_%s.png" % stamp)
	_flash()
	AudioBus.play_sfx("ui_decide", 1.6)
	var subjects := subjects_in_frame()
	for identifier in subjects:
		GameState.dex_count(identifier, "photos")
	Achievements.add("photos")
	var message := "📷 Foto guardada" + (": " + ", ".join(subjects.map(func(id: String) -> String: return MenuStyle.species(id).display_name)) if not subjects.is_empty() else ".")
	GameState.notice.emit(message)
	_check_mission(subjects)
	_busy = false
	return subjects


## Especies a la vista en el centro del cuadro.
func subjects_in_frame() -> Array[String]:
	var result: Array[String] = []
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return result
	var size := get_viewport().get_visible_rect().size
	var margin := size * (1.0 - FRAME) * 0.5
	var space := camera.get_world_3d().direct_space_state
	var actors := get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP) + get_tree().get_nodes_in_group(LegendaryManager.LEGENDARY_GROUP)
	var companion: Variant = _main.get("companion")
	if companion != null and is_instance_valid(companion):
		actors.append(companion)
	for node in actors:
		var actor := node as PokemonActor
		if actor == null or not actor.visible or actor.species == null:
			continue
		var at := actor.global_position + Vector3.UP * 0.6
		if camera.is_position_behind(at) or camera.global_position.distance_to(at) > RANGE:
			continue
		var screen := camera.unproject_position(at)
		if screen.x < margin.x or screen.x > size.x - margin.x or screen.y < margin.y or screen.y > size.y - margin.y:
			continue
		# Nada lo tapa (terreno u obstáculos).
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, at, 1 | 2)
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and (hit["position"] as Vector3).distance_to(at) > 1.5:
			continue
		if not result.has(actor.species.identifier):
			result.append(actor.species.identifier)
	return result


# --- Misión de fotografía del día ----------------------------------------------------

## Misión actual ({species, day, done}); se renueva cada día con una especie cercana.
func mission() -> Dictionary:
	var current: Dictionary = GameState.world_flags.get("photo_mission", {})
	if not current.is_empty() and int(current.get("day", -1)) == GameState.game_day():
		return current
	var candidates: Array[String] = []
	for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
		var actor := node as PokemonActor
		if actor != null and actor.species != null and not actor.legendary and not candidates.has(actor.species.identifier):
			candidates.append(actor.species.identifier)
	if candidates.is_empty():
		return current
	current = {"species": candidates[randi() % candidates.size()], "day": GameState.game_day(), "done": false}
	GameState.world_flags["photo_mission"] = current
	GameState.add_news("Misión de fotografía: retrata a un %s hoy." % MenuStyle.species(current["species"]).display_name)
	return current


func _check_mission(subjects: Array[String]) -> void:
	var current := mission()
	if current.is_empty() or current.get("done", false) or not subjects.has(String(current["species"])):
		return
	current["done"] = true
	var item: String = REWARD_ITEMS[randi() % REWARD_ITEMS.size()]
	GameState.add_money(REWARD_MONEY, "Misión de fotografía")
	GameState.add_item(item, 1)
	AudioBus.play_jingle("me_mission_clear")
	GameState.notice.emit("¡Misión de fotografía cumplida! +$%d y %s." % [REWARD_MONEY, Items.display_name(item)])


func _flash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	var rect := ColorRect.new()
	rect.color = Color.WHITE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
	var tween := create_tween()
	tween.tween_property(rect, "color:a", 0.0, 0.35)
	tween.tween_callback(layer.queue_free)
