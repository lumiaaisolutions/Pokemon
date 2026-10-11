class_name CampManager
extends Node3D
## Tiendas de campaña del jugador (campamento, comida y hambre; acordado con Fernando
## el 2026-10-10): se arman desde la Mochila en un lugar plano fuera de los pueblos
## (reutiliza el campamento del viajero, ver world/npc/camp.gd). Junto a la tienda, E
## abre un menú (ui/camp/camp_menu_ui.gd): Dormir (solo de noche, hasta las 7:00; cura al
## jugador y a su equipo, no el hambre), Cocinar (tiempo real, ver ui/camp/cooking_ui.gd),
## Recoger, Convivir, Mejorar campamento (con materiales, ver UPGRADE_RECIPES), Baúl del
## campamento (funcional desde el nivel 2, ver chest_store/chest_take), Ver las estrellas
## o Nada. Si no se recoge, se queda ahí: persiste en GameState.world_flags["tents"]
## (posición, nivel y lo guardado en el baúl) y se reconstruye al cargar.
##
## Campamento animado (ronda 3, 2026-10-10): dormir, cocinar, recoger y armar tienen una
## escena corta (Nate entra a la tienda, el cielo amanece, vapor en la olla…) que no
## cambia el resultado del juego (ese se aplica de inmediato, igual que antes) y se puede
## saltar con E; ver _play_sleep_cutscene.

@export var world_path: NodePath = NodePath("../World")
@export var player_path: NodePath = NodePath("../Player")

## Materiales para mejorar el campamento (decisión de Fernando: "con materiales", no
## dinero; completando la simplificación anotada en docs/decisiones_sin_preguntar.md,
## que pagaba con $UPGRADE_COST por no existir todavía un objeto "material de
## construcción"). Minerales, bayas y bonguris que ya se recolectan en el mundo
## (ver world/gathering/gather_manager.gd): nivel 1 y nivel 2.
const UPGRADE_RECIPES := {
	1: {"hard-stone": 6, "red-apricorn": 4, "oran-berry": 6},
	2: {"hard-stone": 10, "blu-apricorn": 6, "sitrus-berry": 4, "nugget": 1},
}
## Vínculo que sube Convivir con cada miembro del equipo (una vez al día; ver commune()).
const COMMUNE_BOND_XP := 2.0
## Lo mismo que world/main.gd BOND_MINUTES_PER_LEVEL: minutos de vínculo por nivel.
const BOND_MINUTES_PER_LEVEL := 20.0
## Tiempo real de cocción en la fogata (con animación de vapor, ver CookingUI); la fogata
## mejorada (nivel 2) cocina más rápido (completando la simplificación anotada en
## docs/decisiones_sin_preguntar.md: antes cocinar era instantáneo y no había nada que
## acortar). Segundos base menos COOK_SECONDS_PER_LEVEL por cada nivel de campamento.
const COOK_SECONDS_BASE := 6.0
const COOK_SECONDS_PER_LEVEL := 2.0
const COOK_SECONDS_MIN := 1.5

var world: WorldBuilder
var player: Player

## Cada entrada: {"camp": Camp, "point": Dictionary, "pos": Vector3, "level": int, "chest": Dictionary}.
var _tents: Array[Dictionary] = []

## Cutscene en curso (si la hay): se puede saltar con E (ver _process).
var _cutscene_skip: Callable

## Visitante nocturno real (completando la simplificación anotada en
## docs/decisiones_sin_preguntar.md: antes solo era una burbuja "¿?" sin nadie caminando):
## {"actor": PokemonActor, "sprite": DirectionalSprite, "state", "target", "start", "wait"}.
var _visitor: Dictionary = {}
const VISITOR_WALK_SPEED := 1.6
const VISITOR_GIFTS := ["oran-berry", "pecha-berry", "nugget"]


func _ready() -> void:
	world = get_node(world_path) as WorldBuilder
	player = get_node(player_path) as Player
	for saved: Array in GameState.world_flags.get("tents", []):
		var chest: Dictionary = saved[4] if saved.size() > 4 and saved[4] is Dictionary else {}
		_spawn(Vector3(float(saved[0]), float(saved[1]), float(saved[2])), false, int(saved[3]) if saved.size() > 3 else 0, chest)


func _process(delta: float) -> void:
	if _cutscene_skip.is_valid() and Input.is_action_just_pressed("interact"):
		var skip := _cutscene_skip
		_cutscene_skip = Callable()
		skip.call()
	_update_visitor(delta)


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


func _spawn(at: Vector3, animate: bool, level: int = 0, chest: Dictionary = {}) -> void:
	var camp := Camp.create(self, at, _tents.size(), true)
	var entry := {"camp": camp, "pos": at, "level": level, "chest": chest}
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
		saved.append([pos.x, pos.y, pos.z, int(entry.get("level", 0)), entry.get("chest", {})])
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


## Visitante nocturno (extra, ronda 3; completado 2026-10-11): mientras duermes, con algo
## de suerte un PokemonActor salvaje real camina de verdad hasta la fogata, se queda un
## rato y luego se va por donde llegó (antes era solo una burbuja "¿?" sin nadie
## caminando, anotado en docs/decisiones_sin_preguntar.md).
func _maybe_visit(camp: Camp) -> void:
	if not _visitor.is_empty() or randf() > 0.35:
		return
	var main := get_parent()
	var spawner := main.get_node_or_null("Spawner") as WildSpawner if main != null else null
	if spawner == null or world == null:
		return
	var pool: Array[SpeciesData] = []
	for species: SpeciesData in WildSpawner.ALL_SPECIES.species:
		if not species.is_legendary and not species.is_mythical:
			pool.append(species)
	if pool.is_empty():
		return
	var species: SpeciesData = pool[randi() % pool.size()]
	var start := camp.global_position + Vector3(5.0, 0, 5.0)
	start.y = world.surface_height_at(start.x, start.z)
	var actor := spawner.spawn_species(species, start, false, false)
	if actor == null:
		return
	# Nada de IA salvaje mientras visita: lo mueve esta escena (ver _update_visitor).
	actor.set_physics_process(false)
	actor.set_process(false)
	var fire := camp.global_position + Camp.FIRE_OFFSET + Vector3(1.3, 0, -0.5)
	fire.y = world.surface_height_at(fire.x, fire.z)
	var sprite := actor.get_node_or_null("Sprite") as DirectionalSprite
	_visitor = {"actor": actor, "sprite": sprite, "state": "arrive", "target": fire, "start": start, "wait": 0.0}


## Avanza al visitante nocturno un cuadro: camina a la fogata, se queda un rato (deja un
## objeto y una burbuja) y se va caminando por donde llegó.
func _update_visitor(delta: float) -> void:
	if _visitor.is_empty():
		return
	var actor: PokemonActor = _visitor["actor"]
	if not is_instance_valid(actor):
		_visitor = {}
		return
	var sprite: DirectionalSprite = _visitor.get("sprite")
	var state: String = _visitor["state"]
	if state == "linger":
		if sprite != null:
			sprite.animate(Vector3.ZERO, delta)
		_visitor["wait"] = float(_visitor["wait"]) - delta
		if float(_visitor["wait"]) <= 0.0:
			_visitor["state"] = "leave"
			_visitor["target"] = _visitor["start"]
		return
	var target: Vector3 = _visitor["target"]
	var to := target - actor.global_position
	to.y = 0.0
	if to.length() < 0.3:
		if state == "arrive":
			_visitor["state"] = "linger"
			_visitor["wait"] = randf_range(3.0, 5.0)
			SpeechBubbles.say(actor, "¿?", 2.0)
			var gift: String = VISITOR_GIFTS[randi() % VISITOR_GIFTS.size()]
			GameState.add_item(gift, 1)
			GameState.notice.emit("¡%s se acercó de verdad a tu fogata de noche y dejó %s!" % [actor.species.display_name, Items.display_name(gift)])
		else:
			actor.queue_free()
			_visitor = {}
		return
	var step := to.normalized() * minf(VISITOR_WALK_SPEED * delta, to.length())
	actor.global_position += step
	actor.global_position.y = world.surface_height_at(actor.global_position.x, actor.global_position.z)
	if sprite != null:
		sprite.animate(step / maxf(delta, 0.0001), delta)


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
	# Si tenía baúl con cosas guardadas, no se pierden: vuelven a la Mochila.
	var chest: Dictionary = entry.get("chest", {})
	for id: String in chest:
		if int(chest[id]) > 0:
			GameState.add_item(id, int(chest[id]))
	if not chest.is_empty():
		GameState.notice.emit("Sacaste del baúl todo lo que tenías guardado antes de recoger la tienda.")
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


## Receta de materiales para subir al siguiente nivel (o {} si ya está al máximo).
func upgrade_recipe(entry: Dictionary) -> Dictionary:
	return UPGRADE_RECIPES.get(int(entry.get("level", 0)) + 1, {})


func has_materials(recipe: Dictionary) -> bool:
	for id: String in recipe:
		if GameState.item_count(id) < int(recipe[id]):
			return false
	return true


## Texto de la receta con lo que ya tienes de cada material ("Piedra Dura 3/6, …"), para
## el botón del menú y el aviso si faltan.
func upgrade_cost_text(entry: Dictionary) -> String:
	var recipe := upgrade_recipe(entry)
	if recipe.is_empty():
		return "máximo"
	var parts: Array[String] = []
	for id: String in recipe:
		parts.append("%s %d/%d" % [Items.display_name(id), GameState.item_count(id), int(recipe[id])])
	return ", ".join(parts)


## Mejora el campamento con materiales recolectados (minerales, bayas y bonguris; decisión
## de Fernando, completando la simplificación anotada en docs/decisiones_sin_preguntar.md):
## tienda más grande y de colores, mesa y, al segundo nivel, un baúl de verdad (ver
## chest_store/chest_take) y una fogata que cocina más rápido (ver cook_seconds).
func upgrade_camp(entry: Dictionary) -> void:
	if not can_upgrade(entry):
		GameState.notice.emit("Tu campamento ya está al máximo.")
		return
	var recipe := upgrade_recipe(entry)
	if not has_materials(recipe):
		GameState.notice.emit("Te faltan materiales para mejorar el campamento: %s." % upgrade_cost_text(entry))
		return
	for id: String in recipe:
		GameState.use_item(id, int(recipe[id]))
	entry["level"] = int(entry.get("level", 0)) + 1
	(entry["camp"] as Camp).upgrade(int(entry["level"]))
	_save()
	GameState.notice.emit("¡Mejoraste tu campamento con los materiales que recolectaste! Se ve más grande y de colores.")


# --- Baúl del campamento (funcional desde el nivel 2) ------------------------------------

func has_chest(entry: Dictionary) -> bool:
	return int(entry.get("level", 0)) >= 2


func chest_contents(entry: Dictionary) -> Dictionary:
	return entry.get("chest", {})


## Guarda amount unidades de id de la Mochila al baúl.
func chest_store(entry: Dictionary, id: String, amount: int = 1) -> bool:
	if not has_chest(entry) or GameState.item_count(id) < amount:
		return false
	GameState.use_item(id, amount)
	var chest: Dictionary = entry.get("chest", {})
	chest[id] = int(chest.get(id, 0)) + amount
	entry["chest"] = chest
	_save()
	return true


## Sacar amount unidades de id del baúl a la Mochila.
func chest_take(entry: Dictionary, id: String, amount: int = 1) -> bool:
	var chest: Dictionary = entry.get("chest", {})
	if int(chest.get(id, 0)) < amount:
		return false
	chest[id] = int(chest[id]) - amount
	if int(chest[id]) <= 0:
		chest.erase(id)
	entry["chest"] = chest
	GameState.add_item(id, amount)
	_save()
	return true


func open_chest(entry: Dictionary) -> void:
	if not has_chest(entry):
		return
	var main := get_parent()
	var layer := main.get_node_or_null("MenuLayer") as CanvasLayer if main != null else null
	if layer == null or layer.has_node("CampChest"):
		return
	var ui := CampChestUI.new()
	ui.name = "CampChest"
	ui.camp_manager = self
	ui.entry = entry
	layer.add_child(ui)
	ui.open()


# --- Tiempo real de cocción (ver CookingUI) ------------------------------------------------

## Segundos de espera para que esté lista una receta, según el nivel del campamento (la
## fogata mejorada cocina más rápido).
static func cook_seconds(level: int) -> float:
	return maxf(COOK_SECONDS_BASE - float(level) * COOK_SECONDS_PER_LEVEL, COOK_SECONDS_MIN)


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
