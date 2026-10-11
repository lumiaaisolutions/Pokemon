class_name CampManager
extends Node3D
## Tiendas de campaña del jugador (campamento, comida y hambre; acordado con Fernando
## el 2026-10-10): se arman desde la Mochila en un lugar plano fuera de los pueblos
## (reutiliza el campamento del viajero, ver world/npc/camp.gd). Junto a la tienda, E
## abre un menú (ui/camp/camp_menu_ui.gd): Dormir (solo de noche, hasta las 7:00; cura al
## jugador y a su equipo, no el hambre), Cocinar (ver ui/camp/cooking_ui.gd), Recoger,
## Convivir, Mejorar campamento, Ver las estrellas o Nada. Si no se recoge, se queda ahí:
## persiste en GameState.world_flags["tents"] y se reconstruye al cargar.
##
## Campamento animado (ronda 3, 2026-10-10): dormir, cocinar, recoger y armar tienen una
## escena corta (Nate entra a la tienda, el cielo amanece, vapor en la olla…) que no
## cambia el resultado del juego (ese se aplica de inmediato, igual que antes) y se puede
## saltar con E; ver _play_sleep_cutscene.

@export var world_path: NodePath = NodePath("../World")
@export var player_path: NodePath = NodePath("../Player")

## Costo de mejorar el campamento (ver upgrade_camp): nivel 1 y nivel 2.
const UPGRADE_COST := 800
## Vínculo que sube Convivir con cada miembro del equipo (una vez al día; ver commune()).
const COMMUNE_BOND_XP := 2.0
## Lo mismo que world/main.gd BOND_MINUTES_PER_LEVEL: minutos de vínculo por nivel.
const BOND_MINUTES_PER_LEVEL := 20.0

var world: WorldBuilder
var player: Player

## Cada entrada: {"camp": Camp, "point": Dictionary, "pos": Vector3, "level": int}.
var _tents: Array[Dictionary] = []

## Cutscene en curso (si la hay): se puede saltar con E (ver _process).
var _cutscene_skip: Callable


func _ready() -> void:
	world = get_node(world_path) as WorldBuilder
	player = get_node(player_path) as Player
	for saved: Array in GameState.world_flags.get("tents", []):
		_spawn(Vector3(float(saved[0]), float(saved[1]), float(saved[2])), false, int(saved[3]) if saved.size() > 3 else 0)


func _process(_delta: float) -> void:
	if _cutscene_skip.is_valid() and Input.is_action_just_pressed("interact"):
		var skip := _cutscene_skip
		_cutscene_skip = Callable()
		skip.call()


func tents() -> Array[Dictionary]:
	return _tents


## ¿Se puede armar una tienda en (x, z) de near? Fuera de los pueblos, en tierra firme
## y sin encimarse con otra estructura o lugar especial.
func can_place_at(near: Vector3) -> bool:
	if world == null:
		return false
	if not world.is_inside(near.x, near.z, 10.0):
		return false
	if not world.settlement_at(near.x, near.z, 10.0).is_empty():
		return false
	if not world.structures.place_at(near.x, near.z, 6.0).is_empty():
		return false
	return world._dry_land(near.x, near.z, 2.5)


## Arma una tienda cerca de near (frente al jugador). Devuelve {"ok", "message"}.
func pitch_tent(near: Vector3) -> Dictionary:
	if not can_place_at(near):
		return {"ok": false, "message": "Aquí no puedes armar la tienda: busca un lugar plano fuera del pueblo."}
	var at := Vector3(near.x, world.surface_height_at(near.x, near.z), near.z)
	_spawn(at, true)
	return {"ok": true, "message": "¡Armaste tu tienda de campaña! Interactúa junto a ella para dormir, cocinar, recoger o convivir con tu equipo."}


func _spawn(at: Vector3, animate: bool, level: int = 0) -> void:
	var camp := Camp.create(self, at, _tents.size(), true)
	var entry := {"camp": camp, "pos": at, "level": level}
	entry["point"] = world.structures.add_point(at + Vector3(0, 0.5, 1.6), "Usar la tienda de campaña", _open_menu.bind(entry), 2.6)
	_tents.append(entry)
	_save()
	if animate:
		camp.pitch(player)
	else:
		# Ya estaba armada de antes (reconstrucción al cargar la partida): sin animación.
		camp.set_lit_instant()
		if level > 0:
			camp.upgrade(level)


func _save() -> void:
	var saved: Array = []
	for entry: Dictionary in _tents:
		var pos: Vector3 = entry["pos"]
		saved.append([pos.x, pos.y, pos.z, int(entry.get("level", 0))])
	GameState.world_flags["tents"] = saved


func _open_menu(entry: Dictionary) -> void:
	var main := get_parent()
	var layer := main.get_node_or_null("MenuLayer") as CanvasLayer if main != null else null
	if layer == null or layer.has_node("CampMenu"):
		return
	var ui := CampMenuUI.new()
	ui.name = "CampMenu"
	ui.camp_manager = self
	ui.entry = entry
	layer.add_child(ui)
	ui.open()


## Dormir solo de noche: avanza hasta las 7:00 y cura al jugador y a su equipo (NO el
## hambre, que sigue bajando igual que si estuviera despierto). El resultado se aplica de
## inmediato (como antes); la escena (Nate entra a la tienda, amanece…) es un adorno que
## corre después sin bloquear esto, y se puede saltar con E.
func sleep(entry: Dictionary = {}) -> void:
	if not GameState.is_night():
		GameState.notice.emit("Solo puedes dormir de noche en tu tienda.")
		return
	GameState.sleep_until_morning()
	for member: Dictionary in GameState.party:
		member["hp_ratio"] = 1.0
	var main := get_parent()
	var companion := main.get("companion") as PokemonActor if main != null else null
	if companion != null:
		companion.recover(1.0)
	if player != null:
		player.heal(player.config.health_max)
	GameState.notice.emit("Dormiste en tu tienda. ¡Buenos días! Tú y tu equipo están descansados (el hambre sigue igual).")
	_play_sleep_cutscene(entry, companion)


## Escena de Dormir (ronda 3): Nate entra a la tienda ("Zzz" encima), tu compañero se
## acurruca junto a la fogata, un adorno de cielo (ui/camp/sleep_sky_overlay.gd) simula el
## amanecer durante unos segundos y, a veces, un sueño corto deja una pista. Se salta con E.
func _play_sleep_cutscene(entry: Dictionary, companion: PokemonActor) -> void:
	var camp := entry.get("camp") as Camp
	if camp == null or player == null or not is_instance_valid(player):
		return
	var main := get_parent()
	var door := camp.global_position + Vector3(0, 0, 1.4)
	var overlay: SleepSkyOverlay = null
	if main != null:
		overlay = SleepSkyOverlay.new()
		main.add_child(overlay)
	var hint := _dream_hint()
	DialogBox.blocking = true
	var tween := create_tween()
	tween.tween_property(player, "global_position", door, 0.5)
	tween.tween_property(player, "scale", Vector3(1.0, 0.05, 1.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		SpeechBubbles.say(camp, "Zzz", 2.2)
		if companion != null and is_instance_valid(companion):
			companion.ceremony = true
			var seat := camp.global_position + Camp.FIRE_OFFSET + Vector3(-1.3, 0, 0.3)
			var seat_tween := companion.create_tween()
			seat_tween.tween_property(companion, "global_position", seat, 0.6).set_trans(Tween.TRANS_SINE)
			seat_tween.parallel().tween_property(companion, "scale", Vector3(1.08, 0.72, 1.05), 0.6)
		if overlay != null:
			overlay.start()
		_maybe_visit(camp))
	tween.tween_interval(1.4)
	tween.tween_callback(func() -> void: SpeechBubbles.say(camp, "Zzz", 2.0))
	if hint != "":
		tween.tween_interval(0.9)
		tween.tween_callback(func() -> void: GameState.notice.emit(hint))
	tween.tween_interval(1.3)
	tween.tween_callback(func() -> void:
		if companion != null and is_instance_valid(companion):
			companion.scale = Vector3.ONE
			companion.ceremony = false)
	tween.tween_property(player, "scale", Vector3(1.16, 1.22, 1.16), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "scale", Vector3.ONE, 0.16)
	tween.tween_callback(_finish_cutscene)
	_cutscene_skip = func() -> void:
		tween.kill()
		if is_instance_valid(player):
			player.scale = Vector3.ONE
		if companion != null and is_instance_valid(companion):
			companion.scale = Vector3.ONE
			companion.ceremony = false
		if overlay != null and is_instance_valid(overlay):
			overlay.finish()
		_finish_cutscene()


func _finish_cutscene() -> void:
	DialogBox.blocking = false
	_cutscene_skip = Callable()


## Visitante nocturno (extra, ronda 3): mientras duermes, con algo de suerte un salvaje
## curioso se acerca a la fogata y deja un objeto pequeño (simplificación: no se modela su
## caminata completa, solo una burbuja junto al fuego y el objeto al despertar; ver
## docs/decisiones_sin_preguntar.md).
func _maybe_visit(camp: Camp) -> void:
	if randf() > 0.35:
		return
	SpeechBubbles.say(camp, "¿?", 2.0)
	var gifts: Array[String] = ["oran-berry", "pecha-berry", "nugget"]
	var gift: String = gifts[randi() % gifts.size()]
	GameState.add_item(gift, 1)
	GameState.notice.emit("Un Pokémon salvaje curioso se acercó a tu fogata de noche y dejó %s." % Items.display_name(gift))


## Sueño corto con una pista (extra, ronda 3): texto breve, a veces según el mundo (si
## todavía no se ha roto ninguna roca grande, por ejemplo). No es un dato exacto de dónde
## está cada cosa, solo ambiente (ver docs/decisiones_sin_preguntar.md).
func _dream_hint() -> String:
	if randf() > 0.55:
		return ""
	var options: Array[String] = [
		"Soñaste con un brote verde asomando entre las piedras: algo está creciendo cerca de tu campamento.",
		"Soñaste con una sombra enorme cruzando el cielo nocturno: los legendarios solo se dejan ver en noches muy despejadas.",
	]
	if (GameState.world_flags.get("boulders", {}) as Dictionary).is_empty():
		options.append("Soñaste con una roca enorme temblando: en alguna cueva o desfiladero de la región, un compañero de tipo Lucha, Roca, Tierra o Acero podría abrirte paso.")
	return options[randi() % options.size()]


func open_cooking(entry: Dictionary = {}) -> void:
	var main := get_parent()
	var layer := main.get_node_or_null("MenuLayer") as CanvasLayer if main != null else null
	if layer == null or layer.has_node("Cooking"):
		return
	var ui := CookingUI.new()
	ui.name = "Cooking"
	ui.main = main
	ui.camp = entry.get("camp") as Camp
	layer.add_child(ui)
	ui.open()


func pack_tent(entry: Dictionary) -> void:
	world.structures.remove_point(entry["point"])
	(entry["camp"] as Camp).pack(player)
	_tents.erase(entry)
	_save()
	GameState.add_item("tent", 1)
	GameState.notice.emit("Recogiste tu tienda de campaña.")


## Convivir (extra, ronda 3): todo tu equipo se reúne junto a la fogata; sube un poco el
## vínculo de cada uno, una vez al día.
func commune(entry: Dictionary) -> void:
	if GameState.party.is_empty():
		GameState.notice.emit("No tienes compañeros todavía para convivir junto a la fogata.")
		return
	var today := GameState.game_day()
	if int(GameState.world_flags.get("camp_commune_day", -1)) == today:
		GameState.notice.emit("Ya conviviste con tu equipo hoy junto a la fogata.")
		return
	GameState.world_flags["camp_commune_day"] = today
	for member: Dictionary in GameState.party:
		member["bond_xp"] = float(member.get("bond_xp", 0.0)) + COMMUNE_BOND_XP
		var bond := clampi(1 + int(float(member["bond_xp"]) / BOND_MINUTES_PER_LEVEL), 1, 10)
		member["bond"] = maxi(bond, int(member.get("bond", 1)))
	GameState.notice.emit("Reuniste a tu equipo junto a la fogata: el vínculo de todos subió un poco.")
	var camp := entry.get("camp") as Camp
	var main := get_parent()
	var companion := main.get("companion") as PokemonActor if main != null else null
	if camp != null and companion != null and is_instance_valid(companion):
		SpeechBubbles.say(companion, "♥", 2.0)
		PixelBurst.spawn(main, camp.global_position + Vector3.UP, PixelBurst.Kind.HEAL, 1.2)


func can_upgrade(entry: Dictionary) -> bool:
	return int(entry.get("level", 0)) < 2


## Mejora el campamento ($UPGRADE_COST, dos niveles): tienda más grande y de colores,
## mesa y, al segundo nivel, un baúl (de momento decorativo; ver world/npc/camp.gd).
func upgrade_camp(entry: Dictionary) -> void:
	if not can_upgrade(entry):
		GameState.notice.emit("Tu campamento ya está al máximo.")
		return
	if GameState.money < UPGRADE_COST:
		GameState.notice.emit("Necesitas $%d para mejorar el campamento." % UPGRADE_COST)
		return
	GameState.add_money(-UPGRADE_COST, "Mejora de campamento")
	entry["level"] = int(entry.get("level", 0)) + 1
	(entry["camp"] as Camp).upgrade(int(entry["level"]))
	_save()
	GameState.notice.emit("¡Mejoraste tu campamento! Se ve más grande y de colores.")


## Mirar las estrellas (extra, ronda 3): la cámara mira al cielo y se abre una capa con
## constelaciones con forma de Pokémon (algunas dan una pista; ver stargaze_overlay.gd).
func stargaze() -> void:
	if not GameState.is_night():
		GameState.notice.emit("De día no se ven las estrellas: vuelve de noche.")
		return
	var rig := get_tree().get_first_node_in_group(CameraRig.CAMERA_GROUP) as CameraRig
	if rig != null:
		rig.look_at_sky(6.0)
	var main := get_parent()
	var layer := main.get_node_or_null("MenuLayer") as CanvasLayer if main != null else null
	if layer == null or layer.has_node("Stargazing"):
		return
	var overlay := StargazeOverlay.new()
	overlay.name = "Stargazing"
	layer.add_child(overlay)
