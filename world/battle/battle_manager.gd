class_name BattleManager
extends Node3D
## Combate en tiempo real en una arena (Fase 3, decidido con Fernando el 2026-10-10):
## - Empieza cuando un salvaje te alcanza, cuando tu compañero lo ataca o él ataca a tu
##   compañero. Se forma una arena de ARENA_RADIUS m en ese lugar; el resto del mundo se
##   pausa (salvajes, aparición, eventos, habitantes) y la cámara pasa detrás de tu Pokémon.
## - Controlas a tu Pokémon: moverte, esquivar (Espacio / ○), fijar objetivo (Tab / R3) y
##   sus 4 movimientos (1–4 / R1 + botones). Mantener apuntar pasa el control a ti para
##   lanzar una Pokéball (Fase 4) mientras tu Pokémon pelea solo.
## - Mantener Q / △ abre la rueda para cambiar de Pokémon (2 s de espera); el menú abre la
##   Mochila para usar pociones o bayas. Si tu Pokémon cae y tienes otro, sale el siguiente;
##   si no queda ninguno, vas al Centro Pokémon.
## - Huir: sacar a tu Pokémon del círculo (ese salvaje te ignora un rato).
## - Megaevolución (G / cruceta ↑): una vez por combate con la Piedra Llave y la megapiedra.
## - Al ganar: Puntos de Entrenamiento, objetos que suelta según su tipo, vínculo y dominio,
##   investigación, racha de victorias (más shiny y objetos raros; se pierde al desmayarte)
##   y, de los fuertes, Fragmentos Místicos (MT y misiones de megapiedras).

signal started(opponent: PokemonActor)
signal ended(result: String)

const ARENA_RADIUS := 15.0
const SWITCH_COOLDOWN := 2.0
const FLEE_IGNORE := 10.0
## Objetos que suelta un salvaje por tipo (y su probabilidad base).
const DROPS := {
	PokemonTypes.Type.GRASS: ["oran-berry", "pecha-berry", "tinymushroom"], PokemonTypes.Type.BUG: ["honey", "tinymushroom"],
	PokemonTypes.Type.FIRE: ["red-shard", "lava-cookie"], PokemonTypes.Type.WATER: ["pearl", "blue-shard"],
	PokemonTypes.Type.ROCK: ["hard-stone", "red-shard"], PokemonTypes.Type.GROUND: ["hard-stone", "blue-shard"],
	PokemonTypes.Type.ELECTRIC: ["thunderstone", "blue-shard"], PokemonTypes.Type.FLYING: ["sitrus-berry", "honey"],
	PokemonTypes.Type.FAIRY: ["stardust", "moon-stone"], PokemonTypes.Type.ICE: ["blue-shard", "pearl"],
	PokemonTypes.Type.GHOST: ["stardust", "dusk-stone"], PokemonTypes.Type.DARK: ["dusk-stone", "nugget"],
	PokemonTypes.Type.PSYCHIC: ["stardust", "star-piece"], PokemonTypes.Type.STEEL: ["hard-stone", "nugget"],
	PokemonTypes.Type.DRAGON: ["star-piece", "comet-shard"], PokemonTypes.Type.POISON: ["pecha-berry", "tinymushroom"],
	PokemonTypes.Type.FIGHTING: ["cheri-berry", "hard-stone"], PokemonTypes.Type.NORMAL: ["oran-berry", "cheri-berry"],
}
const RARE_DROPS := ["rare-candy", "nugget", "star-piece", "lucky-egg"]
const FRAGMENT := "mystic-fragment"

## Se apaga en las pruebas que no son del combate (los salvajes pelean en el mundo).
static var enabled := true

var active := false
var opponent: PokemonActor
var center := Vector3.ZERO
var locked := false
var mega_used := false
var _main: Node
var _ring: MeshInstance3D
var _frozen: Array[Node] = []
var _switch_cooldown := 0.0
var _ui: BattleUI
var _rng := RandomNumberGenerator.new()
var _moves_used: Array[String] = []
var _ending := false
var _aim_attack := 0.0
## Combate contra un entrenador (Fase 5.6): {id, name, team: Array[SpeciesData], index,
## money, item, at, on_end: Callable}. Vacío en combates contra salvajes.
var trainer: Dictionary = {}
var _dodge_cooldown := 0.0
## Horda (fase 5.8): los demás miembros que pelean a la vez contra tu compañero; al caer
## el rival, sigue el siguiente. horde_size: cuántos eran (para el premio).
var horde: Array[PokemonActor] = []
var horde_size := 0
var _no_flee_notice := 0.0
var _horde_check := 0.0
const HORDE_RUSH_DISTANCE := 12.0


func _ready() -> void:
	add_to_group(&"battle")
	_rng.randomize()
	_main = get_parent()
	_ui = BattleUI.new()
	_ui.name = "BattleUI"
	add_child(_ui)
	_ui.visible = false


func player() -> Player:
	return _main.get_node_or_null("Player") as Player


func companion() -> PokemonActor:
	var node: Variant = _main.get("companion")
	return node as PokemonActor if node != null and is_instance_valid(node) else null


## ¿Puede empezar un combate con este salvaje ahora?
func can_start(wild: PokemonActor) -> bool:
	if not enabled or active or wild == null or not is_instance_valid(wild) or wild.role != PokemonActor.Role.WILD:
		return false
	if wild.ceremony or wild.legendary or wild.has_meta("trainer") or wild.state == PokemonActor.State.STUNNED or wild.has_meta("fled_until") and float(wild.get_meta("fled_until")) > GameState.play_time:
		return false
	if not ready_to_fight():
		return false
	return wild.global_position.distance_to(player().global_position) < 30.0


## Tu Pokémon está fuera y tú caminas (sin montar): se puede pelear.
## Un entrenador te vio: te detiene mirándolo y saca a tu compañero si estaba guardado,
## para que el combate no se pueda saltar (regla de Fernando, 2026-10-10).
const SPOTTED_MAX_SECONDS := 15.0


func spotted(by: Node3D) -> void:
	var p := player()
	if p == null:
		return
	p.spotted_by = by
	p.spotted_time = SPOTTED_MAX_SECONDS
	p.velocity = Vector3.ZERO
	if int(_main.get("companion_state")) == 1 and GameState.party.any(func(e: Dictionary) -> bool: return float(e.get("hp_ratio", 1.0)) > 0.0):
		_main.call("_send_out_companion")


func release_spotted() -> void:
	var p := player()
	if p != null:
		p.spotted_by = null


func ready_to_fight() -> bool:
	var c := companion()
	var p := player()
	return enabled and not active and c != null and p != null and int(_main.get("companion_state")) == 0 and p.mode == Player.Mode.WALK and p.ride == Player.Ride.NONE


## Empieza el combate contra wild (devuelve false si no se puede).
func start(wild: PokemonActor) -> bool:
	if not can_start(wild):
		return false
	return _begin(wild)


## Combate contra un entrenador: saca su primer Pokémon junto a él (ver trainer).
func start_trainer(info: Dictionary) -> bool:
	release_spotted()
	if not ready_to_fight() or (info.get("team", []) as Array).is_empty():
		return false
	trainer = info
	trainer["index"] = 0
	var first := _trainer_pokemon(0)
	if first == null:
		trainer = {}
		return false
	GameState.notice.emit("¡%s quiere pelear! (%d Pokémon)" % [info["name"], (info["team"] as Array).size()])
	var ok := _begin(first)
	if ok:
		_trainer_mega(first)
	return ok


func _trainer_pokemon(index: int) -> PokemonActor:
	var spawner := _main.get_node("Spawner") as WildSpawner
	var team: Array = trainer["team"]
	var at: Vector3 = trainer.get("at", player().global_position + Vector3(0, 0, -6))
	var actor := spawner.spawn_species(team[index], at, false, false)
	if actor != null:
		actor.set_meta("trainer", true)
		actor.add_to_group(&"trainer_pokemon")
	return actor


## Rival listo (héroes): se cura con pociones, esquiva cuando preparas un ataque.
func _smart_opponent(delta: float) -> void:
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	if opponent.state == PokemonActor.State.STUNNED:
		return
	if int(trainer.get("heals", 0)) > 0 and opponent.hp / opponent.hp_max < 0.3 and opponent.hp > 0.0:
		trainer["heals"] = int(trainer["heals"]) - 1
		opponent.heal_amount(0.5)
		GameState.notice.emit("%s usó una Hiperpoción en %s." % [trainer["name"], opponent.species.display_name])
		_trainer_says("¡Aguanta!")
	var c := companion()
	if c != null and _dodge_cooldown <= 0.0 and c.winding_up() and c.global_position.distance_to(opponent.global_position) < 9.0:
		# Dificultad adaptable (Fase 6): si vas arrollando, el rival listo esquiva más seguido.
		_dodge_cooldown = clampf(2.5 - AdaptiveDifficulty.dodge_bonus() * 4.0, 1.3, 3.2)
		var away := opponent.global_position - c.global_position
		opponent.ai_dodge(Vector3(-away.z, 0, away.x) * (1.0 if _rng.randf() < 0.5 else -1.0))
		_trainer_says("¡Esquiva!")


## Rival listo: el siguiente que saca es el que mejor le va contra tu Pokémon.
func _pick_smart_next() -> void:
	var c := companion()
	var team: Array = trainer["team"]
	var start := int(trainer["index"])
	if c == null or start >= team.size():
		return
	var best := start
	var best_score := -1.0
	for i in range(start, team.size()):
		var species: SpeciesData = team[i]
		var score := 0.0
		for t in species.types:
			score = maxf(score, TypeChart.effectiveness(t, c.species.types))
		if score > best_score:
			best_score = score
			best = i
	if best != start:
		var chosen: SpeciesData = team[best]
		team[best] = team[start]
		team[start] = chosen


## Su mega (si la tiene): megaevoluciona al salir.
func _trainer_mega(actor: PokemonActor) -> void:
	var mega_id := String(trainer.get("mega", ""))
	if mega_id == "" or trainer.get("mega_used", false):
		return
	var mega := MegaCatalog.load_catalog().find(mega_id)
	if mega == null or mega.base_species != actor.species.identifier:
		return
	trainer["mega_used"] = true
	actor.set_physics_process(false)
	await MegaEffect.play(_main, actor, actor)
	if is_instance_valid(actor):
		actor.apply_mega(mega)
		actor.set_physics_process(true)
		GameState.notice.emit("¡El %s de %s megaevolucionó!" % [mega.base_species.capitalize(), trainer["name"]])


## Burbujas de combate (acordado con Fernando el 2026-10-10): mientras su Pokémon de
## turno pelea, el entrenador (si tenemos su nodo en el mundo) va dando la orden con una
## burbuja sobre su cabeza, con el nombre real del movimiento que usa.
const _ORDER_PHRASES := ["¡Usa %s!", "¡Ahora, %s!", "¡Con %s!"]


func _hook_trainer_speech(actor: PokemonActor) -> void:
	if trainer.is_empty() or trainer.get("node") == null or not is_instance_valid(actor):
		return
	actor.move_used.connect(_on_trainer_move)


func _on_trainer_move(_actor: PokemonActor, move_id: String, _style: int) -> void:
	_trainer_says(_ORDER_PHRASES[_rng.randi() % _ORDER_PHRASES.size()] % Moves.get_move(move_id)["name"])


## El entrenador de este combate dice algo con una burbuja (solo si tenemos su nodo).
func _trainer_says(text: String) -> void:
	var node := trainer.get("node") as Node3D
	if node == null or not is_instance_valid(node):
		return
	var p := player()
	if p != null and not SpeechBubbles.near_player(node, p):
		return
	SpeechBubbles.say(node, text)


## El Pokémon del entrenador cayó: sale el siguiente.
func _next_trainer_pokemon() -> void:
	var old := opponent
	PixelBurst.spawn(old.get_parent(), old.global_position, PixelBurst.Kind.HEAL, 0.6)
	trainer["index"] = int(trainer["index"]) + 1
	var at := old.global_position
	old.queue_free()
	trainer["at"] = at
	if trainer.get("smart", false):
		_pick_smart_next()
	var next := _trainer_pokemon(int(trainer["index"]))
	if next == null:
		_win()
		return
	opponent = next
	next.battle_center = center
	next.battle_radius = ARENA_RADIUS - 0.5
	_hook_trainer_speech(next)
	var c := companion()
	if c != null:
		next.start_fight(c)
	GameState.notice.emit("%s saca a %s (%d/%d)" % [trainer["name"], next.species.display_name, int(trainer["index"]) + 1, (trainer["team"] as Array).size()])
	_ui.setup(self)
	_trainer_mega(next)


func _begin(wild: PokemonActor) -> bool:
	active = true
	_ending = false
	opponent = wild
	# Horda: todos sus miembros entran al combate (y no se congelan).
	horde.clear()
	horde_size = 0
	if wild.has_meta("horde"):
		var spawner := _main.get_node_or_null("Spawner") as WildSpawner
		if spawner != null:
			for member in spawner.horde_members(int(wild.get_meta("horde"))):
				if member != wild and member.state != PokemonActor.State.STUNNED:
					horde.append(member)
			horde_size = horde.size() + 1
	mega_used = false
	locked = true
	_moves_used.clear()
	var c := companion()
	var p := player()
	center = (wild.global_position + c.global_position) * 0.5
	var world := _main.get_node("World") as WorldBuilder
	center.y = world.surface_height_at(center.x, center.z)
	# El jugador queda atrás, en el borde, mirando la pelea.
	var away := p.global_position - center
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3.BACK
	var player_spot := center + away.normalized() * (ARENA_RADIUS - 3.0)
	if p.global_position.distance_to(center) > ARENA_RADIUS - 2.0:
		p.global_position = Vector3(player_spot.x, world.surface_height_at(player_spot.x, player_spot.z) + 0.3, player_spot.z)
	_freeze_world(true)
	_make_ring()
	c.set_controlled(true)
	c.battle_center = center
	c.battle_radius = ARENA_RADIUS + 1.5
	wild.battle_center = center
	wild.battle_radius = ARENA_RADIUS - 0.5
	wild.start_fight(c)
	_hook_trainer_speech(wild)
	# La horda te rodea: entran al círculo y atacan a tu compañero a la vez.
	for k in horde.size():
		var member := horde[k]
		var angle := TAU * k / maxf(horde.size(), 1) + 0.6
		var spot := center + Vector3(cos(angle), 0, sin(angle)) * (ARENA_RADIUS * 0.45)
		member.global_position = Vector3(spot.x, world.surface_height_at(spot.x, spot.z) + 0.3, spot.z)
		member.battle_center = center
		member.battle_radius = ARENA_RADIUS - 0.5
		member.start_fight(c)
	var rig := _main.get_node("CameraRig") as CameraRig
	rig.set_target(c)
	_ui.visible = true
	_ui.setup(self)
	if horde_size > 1:
		GameState.notice.emit("¡Una horda de %d %s te rodea!" % [horde_size, wild.species.display_name])
	elif trainer.is_empty():
		GameState.notice.emit("¡Combate contra %s! Sal del círculo para huir." % wild.species.display_name)
	started.emit(wild)
	return true


func _process(delta: float) -> void:
	if not active:
		_check_hordes(delta)
	if not active or _ending:
		return
	_switch_cooldown = maxf(_switch_cooldown - delta, 0.0)
	var c := companion()
	if opponent == null or not is_instance_valid(opponent) or opponent.is_queued_for_deletion():
		_end("capture")
		return
	if not trainer.is_empty() and trainer.get("smart", false):
		_smart_opponent(delta)
	if opponent.state == PokemonActor.State.STUNNED:
		if not trainer.is_empty() and int(trainer["index"]) + 1 < (trainer["team"] as Array).size():
			_next_trainer_pokemon()
		elif _next_horde_member():
			pass
		else:
			_win()
		return
	if c == null:
		return
	# Al apuntar (Fase 4) el control pasa al jugador y el compañero pelea solo.
	var aiming := (player().get_node("ThrowAim") as ThrowAim).is_aiming()
	if aiming and c.controlled:
		c.set_controlled(false)
		c.battle_center = center
		c.start_fight(opponent)
		(_main.get_node("CameraRig") as CameraRig).set_target(player())
		_aim_attack = 1.5
	elif not aiming and not c.controlled and c.state != PokemonActor.State.STUNNED and int(_main.get("companion_state")) == 0:
		c.set_controlled(true)
		(_main.get_node("CameraRig") as CameraRig).set_target(c)
	# Mientras apuntas, el rival sigue peleando y a veces va por ti: esquívalo.
	if aiming:
		_aim_attack -= delta
		if _aim_attack <= 0.0:
			_aim_attack = 4.0
			if _rng.randf() < 0.6:
				opponent.start_fight(player())
	elif opponent.fight_target == player() and c.state != PokemonActor.State.STUNNED:
		opponent.start_fight(c)
	# De un entrenador no se huye (regla de Fernando): tu Pokémon vuelve al círculo.
	var out := Vector2(c.global_position.x - center.x, c.global_position.z - center.z)
	if not trainer.is_empty() and out.length() > ARENA_RADIUS - 0.4:
		var inside := out.normalized() * (ARENA_RADIUS - 0.6)
		c.global_position = Vector3(center.x + inside.x, c.global_position.y, center.z + inside.y)
		if _no_flee_notice <= 0.0:
			_no_flee_notice = 4.0
			GameState.notice.emit("¡No puedes huir de un combate contra un entrenador!")
	_no_flee_notice = maxf(_no_flee_notice - delta, 0.0)
	# Huir: tu Pokémon salió del círculo.
	if c.controlled and trainer.is_empty() and out.length() > ARENA_RADIUS + 1.0:
		opponent.set_meta("fled_until", GameState.play_time + FLEE_IGNORE)
		opponent.lose_track(FLEE_IGNORE)
		GameState.notice.emit("¡Escapaste del combate!" if trainer.is_empty() else "Te retiraste del combate contra %s." % trainer["name"])
		AudioBus.play_sfx("flee")
		_end("flee")
		return
	if Input.is_action_just_pressed("lock_on"):
		locked = not locked
	if locked and c.controlled:
		var rig := _main.get_node("CameraRig") as CameraRig
		var to := opponent.global_position - c.global_position
		to.y = 0.0
		if to.length() > 0.5:
			var yaw := rad_to_deg(atan2(-to.x, -to.z))
			rig.set("_yaw_deg", lerp_angle_deg(float(rig.get("_yaw_deg")), yaw, 1.0 - exp(-6.0 * delta)))
	if Input.is_action_just_pressed("mega_evolve"):
		try_mega()
	_ui.refresh()


static func lerp_angle_deg(from: float, to: float, weight: float) -> float:
	return rad_to_deg(lerp_angle(deg_to_rad(from), deg_to_rad(to), weight))


## Registra un movimiento usado por tu Pokémon (para el dominio extra al ganar).
func note_move(id: String) -> void:
	if active and not _moves_used.has(id):
		_moves_used.append(id)


## Tu Pokémon cayó: sale el siguiente sano o se pierde.
func on_companion_fainted() -> bool:
	if not active:
		return false
	var next := next_healthy()
	if next < 0:
		_end("lose")
		return false
	GameState.party[GameState.companion_index]["hp_ratio"] = 0.0
	_switch_cooldown = 0.0
	switch_to(next)
	return true


func next_healthy() -> int:
	for i in GameState.party.size():
		if i != GameState.companion_index and float(GameState.party[i].get("hp_ratio", 1.0)) > 0.0:
			return i
	return -1


## Cambia de Pokémon dentro del combate (con espera).
func switch_to(index: int) -> bool:
	if not active or _switch_cooldown > 0.0 or index == GameState.companion_index:
		return false
	if float(GameState.party[index].get("hp_ratio", 1.0)) <= 0.0:
		GameState.notice.emit("Ese Pokémon está debilitado.")
		return false
	_switch_cooldown = SWITCH_COOLDOWN
	_restore_mega()
	_main.call("swap_companion", index)
	var c := companion()
	if c == null:
		return false
	c.global_position = center + (player().global_position - center).normalized() * 4.0 + Vector3.UP * 0.3
	c.set_controlled(true)
	c.battle_center = center
	c.battle_radius = ARENA_RADIUS + 1.5
	opponent.start_fight(c)
	(_main.get_node("CameraRig") as CameraRig).set_target(c)
	GameState.notice.emit("¡Adelante, %s!" % c.species.display_name)
	_ui.setup(self)
	return true


func switch_ready() -> bool:
	return _switch_cooldown <= 0.0


# --- Megaevolución ------------------------------------------------------------------

## Megas que puede usar tu compañero ahora (Piedra Llave y su megapiedra en la mochila).
func available_mega() -> MegaData:
	var c := companion()
	if c == null or mega_used or GameState.item_count("key-stone") <= 0:
		return null
	for mega in MegaCatalog.load_catalog().for_species(c.species.identifier):
		if Items.exists("stone-" + mega.identifier) and GameState.item_count("stone-" + mega.identifier) > 0:
			return mega
		if mega.identifier == "rayquaza-mega":
			return mega
	return null


func try_mega() -> bool:
	var mega := available_mega()
	if mega == null:
		if not mega_used:
			GameState.notice.emit("Necesitas la Piedra Llave y la megapiedra de tu Pokémon para megaevolucionar.")
		return false
	mega_used = true
	var c := companion()
	opponent.set_physics_process(false)
	c.set_physics_process(false)
	await MegaEffect.play(_main, c, player())
	if is_instance_valid(c):
		c.apply_mega(mega)
		c.set_physics_process(true)
	if is_instance_valid(opponent):
		opponent.set_physics_process(true)
	GameState.notice.emit("¡%s megaevolucionó en %s!" % [c.species.display_name if c.mega == null else c.mega.base_species.capitalize(), mega.display_name])
	Achievements.add("megas")
	_ui.setup(self)
	return true


func _restore_mega() -> void:
	var c := companion()
	if c != null and c.mega != null:
		c.remove_mega()


# --- Final ---------------------------------------------------------------------------

## Horda: si quedan miembros en pie, el siguiente pasa a ser el rival.
func _next_horde_member() -> bool:
	horde = horde.filter(func(m: PokemonActor) -> bool: return is_instance_valid(m) and not m.is_queued_for_deletion() and m.state != PokemonActor.State.STUNNED)
	if horde.is_empty():
		return false
	opponent = horde.pop_front()
	opponent.start_fight(companion())
	_ui.setup(self)
	GameState.notice.emit("¡Quedan %d de la horda!" % (horde.size() + 1))
	return true


## Fuera de combate: una horda cercana se lanza sobre ti (te rodea) y empieza el combate.
func _check_hordes(delta: float) -> void:
	_horde_check -= delta
	if _horde_check > 0.0:
		return
	_horde_check = 0.5
	if not ready_to_fight():
		return
	for node in get_tree().get_nodes_in_group(WildSpawner.HORDE_GROUP):
		var actor := node as PokemonActor
		if is_instance_valid(actor) and actor.state != PokemonActor.State.STUNNED and actor.global_position.distance_to(player().global_position) < HORDE_RUSH_DISTANCE:
			start(actor)
			return


func _win() -> void:
	var defeated := opponent
	var c := companion()
	var species := defeated.species
	var lines: Array[String] = ["¡%s ganó!" % (c.species.display_name if c != null else "Tu equipo")]
	# Horda: premio extra por vencerla completa.
	if horde_size > 1:
		var bonus := 150 * horde_size
		GameState.add_money(bonus, "Horda de %s" % species.display_name)
		GameState.add_item("rare-candy", 1)
		lines.append("¡Venciste a la horda de %d! +$%d y un Caramelo Raro." % [horde_size, bonus])
	# Racha de victorias.
	var streak := int(GameState.world_flags.get("win_streak", 0)) + 1
	GameState.world_flags["win_streak"] = streak
	if streak > int(GameState.stats.get("best_streak", 0)):
		Achievements.add("best_streak", streak - int(GameState.stats.get("best_streak", 0)))
	# Vínculo y dominio extra.
	if c != null and not GameState.party.is_empty():
		var entry: Dictionary = GameState.party[GameState.companion_index]
		entry["bond_xp"] = float(entry.get("bond_xp", 0.0)) + 3.0
		entry["wins"] = int(entry.get("wins", 0)) + 1
		if not Evolution.ready_option(entry).is_empty():
			lines.append("¡%s puede evolucionar! (Menú → Pokémon)" % c.species.display_name)
		for id in _moves_used:
			var mastery: Dictionary = entry.get("mastery", {})
			mastery[id] = int(mastery.get(id, 0)) + 2
			entry["mastery"] = mastery
	# Investigación: vencido en combate.
	GameState.dex_count(species.identifier, "battles")
	if defeated.has_meta("Alfa") or defeated.has_meta("dominante"):
		GameState.world_flags["alpha_beaten:" + species.identifier] = true
	# Entrenador: dinero y un objeto (revancha al día siguiente).
	if not trainer.is_empty():
		var money := int(trainer.get("money", 500))
		GameState.add_money(money, "Combate contra %s" % trainer["name"])
		lines.append("¡Venciste a %s! +$%d." % [trainer["name"], money])
		var prize := String(trainer.get("item", ""))
		if Items.exists(prize):
			GameState.add_item(prize, 1)
			lines.append("Te dio %s." % Items.display_name(prize))
		GameState.world_flags["trainer_beaten:" + String(trainer["id"])] = GameState.game_day()
		Achievements.add("trainers")
	# Objetos que suelta (dificultad adaptable, Fase 6: más si vas flojo, algo menos si arrollas).
	var drop_chance := 0.0 if not trainer.is_empty() else (0.45 + minf(streak, 10) * 0.03) * AdaptiveDifficulty.reward_multiplier()
	if _rng.randf() < drop_chance:
		var pool: Array = DROPS.get(species.types[0], ["oran-berry"])
		var item: String = pool[_rng.randi() % pool.size()]
		if _rng.randf() < minf(streak, 10) * 0.015:
			item = RARE_DROPS[_rng.randi() % RARE_DROPS.size()]
		if Items.exists(item):
			GameState.add_item(item, 1)
			lines.append("Soltó %s." % Items.display_name(item))
	# Fragmentos de los fuertes (Alfas, dominantes y evolucionados).
	var strong := defeated.has_meta("Alfa") or defeated.has_meta("dominante") or species.evolution_stage >= 2
	if strong and _rng.randf() < (0.8 if defeated.has_meta("Alfa") else 0.3):
		var amount := 3 if defeated.has_meta("Alfa") else 1
		GameState.add_item(FRAGMENT, amount)
		lines.append("+%d Fragmento Místico." % amount)
	if streak >= 3:
		lines.append("Racha: %d victorias." % streak)
	GameState.notice.emit(" ".join(lines))
	for message in MegaMissions.update():
		GameState.notice.emit(message)
	# Dificultad adaptable (Fase 6): una victoria con vida alta y racha sube el nivel.
	AdaptiveDifficulty.record_battle(true, c.hp / c.hp_max if c != null else 1.0, streak)
	_end("win" if trainer.is_empty() else "trainer_win")


func _end(result: String) -> void:
	if _ending:
		return
	_ending = true
	_restore_mega()
	var c := companion()
	if c != null:
		c.battle_center = Vector3.INF
		if result != "lose":
			c.set_controlled(false)
	if opponent != null and is_instance_valid(opponent):
		opponent.battle_center = Vector3.INF
	for member in horde:
		if is_instance_valid(member):
			member.battle_center = Vector3.INF
	horde.clear()
	horde_size = 0
	_freeze_world(false)
	if _ring != null and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null
	if result != "lose":
		(_main.get_node("CameraRig") as CameraRig).set_target(player())
	_ui.visible = false
	active = false
	# Entrenador: su Pokémon vuelve a la ball y él se entera del resultado.
	if not trainer.is_empty():
		if opponent != null and is_instance_valid(opponent):
			opponent.queue_free()
		var info := trainer
		trainer = {}
		var on_end: Callable = info.get("on_end", Callable())
		if on_end.is_valid():
			on_end.call(result)
	opponent = null
	ended.emit(result)


## Termina el combate desde afuera (captura, desmayo del jugador, interior…).
func finish(result: String) -> void:
	if active:
		_end(result)


## Racha: se pierde al desmayarte.
static func reset_streak() -> void:
	GameState.world_flags["win_streak"] = 0


static func streak() -> int:
	return int(GameState.world_flags.get("win_streak", 0))


# --- Mundo en pausa y arena ------------------------------------------------------------

func _freeze_world(freeze: bool) -> void:
	if freeze:
		_frozen.clear()
		for path in ["Spawner", "Legendaries", "Ambushes", "Events", "TownNPCs", "Gathering"]:
			var node := _main.get_node_or_null(path)
			if node != null and node.process_mode != Node.PROCESS_MODE_DISABLED and node.is_processing():
				node.set_process(false)
				_frozen.append(node)
		for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP) + get_tree().get_nodes_in_group(LegendaryManager.LEGENDARY_GROUP):
			if node != opponent and not horde.has(node) and is_instance_valid(node) and (node as Node).process_mode != Node.PROCESS_MODE_DISABLED:
				(node as Node).process_mode = Node.PROCESS_MODE_DISABLED
				_frozen.append(node)
	else:
		for node in _frozen:
			if not is_instance_valid(node):
				continue
			if node is PokemonActor:
				node.process_mode = Node.PROCESS_MODE_INHERIT
			else:
				node.set_process(true)
		_frozen.clear()


func _make_ring() -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "ArenaRing"
	var torus := TorusMesh.new()
	torus.inner_radius = ARENA_RADIUS - 0.15
	torus.outer_radius = ARENA_RADIUS + 0.15
	torus.rings = 64
	_ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.85, 0.3, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.8, 0.2)
	_ring.material_override = material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_ring.global_position = center + Vector3.UP * 0.25
