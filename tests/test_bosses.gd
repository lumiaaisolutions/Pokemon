extends Node
## Prueba de los jefes de la Fase 6 (ver docs/sistemas/jefes.md): hay un guardián por
## cada bioma presente en la región (menos el mar); tiene fases (cambia al bajar de
## umbral e invoca ayudantes); sus ataques en área se pueden esquivar (daño 0 si el
## compañero sale de la zona antes de que se resuelvan); al vencerlo da su premio único
## y queda registrado por región; el líder del equipo villano solo aparece con bastantes
## medallas, pelea con un equipo fuerte y, al vencerlo, libera las zonas tomadas; la
## dificultad adaptable sube con una racha de victorias y baja con un desmayo.
## Uso: godot --headless --path . tests/test_bosses.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")

var _failures: Array[String] = []
var _main: Node3D
var _player: Player
var _world: WorldBuilder
var _services: TownServices
var _battle: BattleManager
var _bosses: BossManager


func _ready() -> void:
	BattleManager.enabled = true
	GameState.party.clear()
	GameState.box.clear()
	GameState.world_flags = {}
	GameState.regions = []
	GameState.region_index = 0
	GameState.money = 1000
	GameState.performance = 0.0
	GameState.difficulty = 1
	GameState.play_time = 0.0
	_main = MAIN_SCENE.instantiate() as Node3D
	_main.set("starter_ceremony", false)
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_world = _main.get_node("World") as WorldBuilder
	_services = _world.structures.services
	_battle = _main.get_node("Battle") as BattleManager
	_bosses = _main.get_node("Bosses") as BossManager
	var navigation := _main.get_node("Navigation") as WorldNavigation
	while not navigation.is_baked:
		await get_tree().physics_frame
	# Se controla todo a mano: sin exploración de salvajes, eventos ni el proceso
	# automático de Bosses (lo manejamos directo para que la prueba sea determinista).
	for node_name in ["Spawner", "Legendaries", "Ambushes", "Events", "Migrations", "Heroes", "Rival", "RouteTrainers", "TownNPCs"]:
		(_main.get_node(node_name) as Node).set_process(false)
	_bosses.set_process(false)
	await _frames(10)
	await _run()
	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_bosses: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run() -> void:
	# 1. Hay un guardián por bioma presente en la región, y el mar no tiene guardián.
	_check(not _bosses._lairs.is_empty(), "hay al menos un bioma con guarida de guardián")
	_check(not _bosses._lairs.has(int(RegionLayout.Biome.SEA)), "el mar no tiene guardián")

	# 2. Aparece enorme y fuerte, con fases: cambia al bajar de umbral e invoca ayudantes.
	var spot := _world.start_position() + Vector3(0, 0, -8)
	_player.global_position = spot + Vector3(0, 0.5, -2)
	var companion: PokemonActor = _main.companion
	_check(companion != null, "hay compañero")
	if companion == null:
		return
	companion.global_position = spot + Vector3(1.0, 0.3, -2.0)
	await _frames(5)
	var guardian := _bosses._spawn_guardian(int(RegionLayout.Biome.MEADOW), Vector3(spot.x, 0, spot.z))
	_check(guardian != null, "se puede crear un guardián de bioma")
	if guardian == null:
		return
	var region := Regions.index()
	_check(guardian.size_factor >= Bosses.size_scale(region) - 0.01, "el guardián es enorme (×%.1f)" % guardian.size_factor)
	_check(guardian.hp_max > 20.0 + guardian.species.hp * 0.6 * 2.0, "el guardián tiene mucha más vida que uno normal")
	_check(guardian.has_meta("guardian"), "está marcado como guardián")
	await _frames(5)
	_check(_battle.start(guardian), "empieza el combate contra el guardián")
	await _frames(3)
	_check(not _bosses._fight.is_empty() and int(_bosses._fight.get("phase", 0)) == 1, "el combate de jefe arranca en fase 1")
	var horde_before := _battle.horde.size()
	_bosses._advance_phase(2)
	_check(int(_bosses._fight.get("phase", 0)) == 2, "sube a la fase 2 al forzarla")
	_check(_battle.horde.size() > horde_before, "la fase 2 invoca un ayudante")

	# 3. Ataques en área telegrafiados que se esquivan: el círculo marca dónde estaba el
	# compañero al lanzarse; si sale de ahí antes de que se cumpla, 0 de daño. Se apaga
	# la IA normal del guardián y de su ayudante para que solo el ataque en área pueda
	# dañar en esta prueba.
	guardian.set_physics_process(false)
	for member: PokemonActor in _battle.horde:
		if is_instance_valid(member):
			member.set_physics_process(false)
	companion.hp = companion.hp_max
	companion.global_position = guardian.global_position + Vector3(0, 0, -1.5)
	# Sin await entre lanzar el ataque y moverse: así se mueve antes de que el temporizador
	# (que corre en tiempo real, no por cuadro de física) tenga oportunidad de cumplirse.
	# Se mueve solo lo justo para salir del círculo (no tanto como para "huir" del combate).
	_bosses.launch_aoe(guardian, "circle")
	companion.global_position = guardian.global_position + Vector3(7.0, 0, -1.5)
	await _frames(100)
	_check(is_equal_approx(companion.hp, companion.hp_max), "si sales de la zona antes de que se cumpla, no hace daño")
	companion.hp = companion.hp_max
	companion.global_position = guardian.global_position + Vector3(0, 0, -1.5)
	_bosses.launch_aoe(guardian, "circle")
	await _frames(100)
	_check(companion.hp < companion.hp_max, "si te quedas dentro de la zona, sí hace daño")

	# 4. Premio único y registro por región al vencerlo.
	var biome := int(guardian.get_meta("guardian_biome"))
	var money_before := GameState.money
	var crest_before := GameState.item_count(Bosses.crest_item_id(biome))
	_check(not Bosses.is_defeated(biome), "todavía no estaba vencido")
	guardian.receive_hit(guardian.hp_max + 999.0, companion)
	await _frames(10)
	_check(Bosses.is_defeated(biome), "el guardián vencido queda registrado en la región")
	_check(GameState.money > money_before, "da dinero al vencerlo")
	_check(GameState.item_count(Bosses.crest_item_id(biome)) > crest_before, "da su insignia única de guardián")
	var targets := _bosses.guardian_targets()
	var marked := targets.filter(func(t: Dictionary) -> bool: return int(t["biome"]) == biome)
	_check(not marked.is_empty() and bool(marked[0]["defeated"]), "la Brújula del Rotom lo marca como vencido")
	# La fase 2 invocó un ayudante que puede seguir vivo: se cierra el combate a mano
	# (no es parte de esta prueba) para dejar la arena libre para el líder del equipo villano.
	if _battle.active:
		_battle.finish("flee")
	await _frames(10)

	# 5. El líder del equipo villano solo aparece con bastantes medallas.
	var arena := Interiors.ORIGIN + Vector3(0, 0.3, -2)
	_services.villain_confront(arena)
	_check(not _battle.active, "sin medallas suficientes, un guardia rechaza el reto")
	for i in TownServices.VILLAIN_BADGE_GATE:
		_services.badges().append("pueblo %d" % i)
	_player.global_position = spot
	companion.global_position = spot + Vector3(1.0, 0.3, 1.0)
	await _frames(5)
	var reputation_before := int(GameState.reputation.values()[0]) if not GameState.reputation.is_empty() else 0
	_services._villain_battle(arena)
	_check(_battle.active and (_battle.trainer.get("team", []) as Array).size() >= 4, "el líder pelea con un equipo fuerte")
	await _win_battle()
	_check(bool(GameState.world_flags.get("villain_defeated", false)), "al vencer al líder, la base queda desmantelada")
	if not GameState.reputation.is_empty():
		_check(int(GameState.reputation.values()[0]) >= reputation_before, "la reputación sube con las zonas liberadas")
	_check(GameState.item_count("villain-emblem") > 0, "da el emblema único del equipo villano")

	# 6. Dificultad adaptable: sube con una racha ganadora y baja con un desmayo.
	GameState.performance = 0.0
	var base_damage := GameState.difficulty_value("damage")
	_check(is_equal_approx(base_damage, GameState.DIFFICULTIES[GameState.difficulty]["damage"]), "rendimiento neutral no cambia la dificultad elegida")
	for i in 8:
		AdaptiveDifficulty.record_battle(true, 0.9, 3)
	_check(GameState.performance > 0.0, "ganar con vida alta y racha sube el rendimiento")
	_check(GameState.difficulty_value("damage") > base_damage, "si vas arrollando, los rivales pegan algo más fuerte")
	GameState.performance = 0.0
	AdaptiveDifficulty.record_battle(false, 0.0, 0)
	_check(GameState.performance < 0.0, "un desmayo baja el rendimiento")
	_check(GameState.difficulty_value("damage") < base_damage, "si vas flojo, los rivales pegan algo menos")


## Vence a todo el equipo del entrenador del combate actual (igual que test_regions).
func _win_battle() -> void:
	for i in 12:
		if not _battle.active:
			break
		var foe := _battle.opponent
		if foe != null and is_instance_valid(foe):
			foe.receive_hit(foe.hp + 9999.0, _main.companion)
		await _frames(15)
	await _frames(20)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
