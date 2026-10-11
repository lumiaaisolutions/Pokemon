class_name TownServices
extends Node
## Lo que pasa al interactuar con edificios y lugares: curar en el Centro Pokémon (y
## fijar ahí el punto de reaparición con autoguardado), la tienda, descansar, hablar
## con vecinos y con el profesor, retos de gimnasio y de la Liga, concursos, ruinas,
## árbol milenario, ruinas flotantes, portales, Zona Safari, guardería, lugares que
## curan (aguas termales y fuentes) y tesoros de las mazmorras.

const BADGE_MONEY := 1500
const SAFARI_PRICE := 500
const SAFARI_BALLS := 30
const SAFARI_RADIUS := 40.0
const DAYCARE_POINTS_PER_DAY := 2
const HEAL_SPOT_RATE := 0.25
const TUTOR_PRICE := 2000
## Salvajes que curan al jugador si te acercas.
const HEALERS := ["chansey", "blissey", "audino", "happiny"]
## Símbolos de las piedras de las ruinas (el orden correcto sale de la inscripción).
const RUIN_SYMBOLS := ["sol", "luna", "estrella"]
const FOSSILS := {"helix-fossil": "omanyte", "dome-fossil": "kabuto", "root-fossil": "lileep", "claw-fossil": "anorith",
		"skull-fossil": "cranidos", "armor-fossil": "shieldon", "cover-fossil": "tirtouga", "plume-fossil": "archen"}
const MERCHANT_GOODS := ["fire-stone", "water-stone", "thunderstone", "leaf-stone", "moon-stone", "sun-stone", "shiny-stone", "dusk-stone",
		"dawn-stone", "rare-candy", "lucky-egg", "leftovers", "choice-band", "choice-scarf", "big-pearl", "max-repel", "ultra-ball", "quick-ball", "lum-berry"]
## Pokémon raros de la Zona Safari (los que no existan se ignoran).
const SAFARI_POOL := ["kangaskhan", "tauros", "scyther", "pinsir", "chansey", "dratini", "exeggcute", "rhyhorn", "nidorino", "nidorina",
		"girafarig", "heracross", "phanpy", "larvitar", "bagon", "gible", "axew", "deino", "goomy", "jangmo-o", "frigibax"]

var structures: Structures
var interiors: Interiors
## Lugares que curan: {"pos", "radius", "title"}.
var _healing_spots: Array[Dictionary] = []
var _trial: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _in_safari := false
var _healing_notice := 0.0


func _ready() -> void:
	_rng.randomize()
	interiors = Interiors.new()
	interiors.name = "Interiors"
	interiors.structures = structures
	interiors.services = self
	add_child(interiors)


func main() -> Node:
	return structures.world.get_parent()


func player() -> Player:
	return main().get_node_or_null("Player") as Player


func companion() -> PokemonActor:
	var node: Variant = main().get("companion")
	return node as PokemonActor if node != null and is_instance_valid(node) else null


func _hud() -> Hud:
	return main().get_node_or_null("Hud") as Hud


func _flags() -> Dictionary:
	return GameState.world_flags


# --- Movimiento y navegación ------------------------------------------------------------

## Lleva al jugador y a su compañero (si está afuera) a point, con la cámara de golpe.
func move_party_to(point: Vector3) -> void:
	var p := player()
	if p == null:
		return
	p.global_position = point
	p.velocity = Vector3.ZERO
	var c := companion()
	var battle := main().get_node_or_null("Battle") as BattleManager
	if battle != null and battle.active:
		battle.finish("flee")
	if c != null and c.visible and not c.is_queued_for_deletion():
		c.global_position = point + Vector3(1.4, 0.2, 1.0)
		c.velocity = Vector3.ZERO
		# Sin objetivos de afuera (si no, se queda pegado a la pared queriendo pelear).
		c.calm()
	var rig := main().get_node_or_null("CameraRig") as CameraRig
	if rig != null:
		rig.snap()


func navigation_bake_interior(root: Node3D) -> void:
	var navigation := main().get_node_or_null("Navigation") as WorldNavigation
	if navigation != null:
		navigation.bake_interior(root)


func navigation_free_interior() -> void:
	var navigation := main().get_node_or_null("Navigation") as WorldNavigation
	if navigation != null:
		navigation.free_interior()


func spawn_wild(species: SpeciesData, point: Vector3) -> PokemonActor:
	var spawner := main().get_node_or_null("Spawner") as WildSpawner
	if spawner == null:
		return null
	return spawner.spawn_species(species, point, _rng.randf() < spawner.shiny_chance(), false)


# --- Edificios -----------------------------------------------------------------------------

## Entra al interior de un edificio o lugar; vuelve a la puerta al salir.
func enter_interior(kind: String, settlement: Dictionary, data: Dictionary) -> void:
	var p := player()
	if p == null:
		return
	var hour := GameState.clock_hour()
	if not TownNPCs.is_open(kind, hour):
		GameState.notice.emit("%s está cerrado. Abre a las %s." % [Structures.BUILDING_NAMES.get(kind, "El lugar"), "8:00" if kind == "mart" else "7:00"])
		return
	interiors.enter(kind, settlement, data, p.global_position + Vector3.UP * 0.3)


## Centro Pokémon: cura a todos, fija la reaparición en su puerta y autoguarda.
func heal_at_center(door: Vector3) -> void:
	heal_everyone()
	AudioBus.play_jingle("bw1_heal")
	GameState.respawn_point = door
	var saved := SaveSystem.save_slot(0, main())
	GameState.notice.emit("¡Tu equipo está como nuevo! Volverás aquí si te desmayas.%s" % (" (Autoguardado)" if saved else ""))
	Achievements.add("centers")


func heal_everyone() -> void:
	for member: Dictionary in GameState.party:
		member["hp_ratio"] = 1.0
	var p := player()
	if p != null:
		p.heal(9999.0)
	var c := companion()
	if c != null:
		c.recover(1.0)


## Descansar (carpa o cama): duerme hasta la mañana y se cura todo.
func rest(_door: Vector3) -> void:
	GameState.sleep_until_morning()
	heal_everyone()
	GameState.notice.emit("Dormiste hasta la mañana. Todos descansaron.")


func open_menu_tab(tab_name: String) -> void:
	var menu := main().get_node_or_null("MenuLayer/GameMenu") as GameMenu
	if menu != null:
		menu.tab = GameMenu.TABS.find(tab_name)
		menu.open()


func open_shop() -> void:
	var layer := main().get_node_or_null("MenuLayer") as CanvasLayer
	if layer == null or layer.has_node("Shop"):
		return
	var shop := ShopUI.new()
	shop.name = "Shop"
	layer.add_child(shop)
	shop.open()


## Vecinos: un consejo y, una vez por día, un regalo. Hablan en la caja de diálogo con su
## retrato (antes salía como aviso y parecía que no decían nada).
func talk_resident(settlement: Dictionary, building: Dictionary, look: String = "") -> void:
	var tips := [
		"Dicen que en las cuevas hay salidas que te llevan muy lejos.",
		"Por las noches salen Pokémon distintos. ¡Revisa tu Pokédex!",
		"En las aguas termales se te quita todo el cansancio.",
		"El líder del gimnasio de %s usa Pokémon de un solo tipo." % settlement.get("name", "la ciudad"),
		"Si atacas por la espalda, es más fácil capturar.",
		"Las ruinas flotantes solo se alcanzan volando.",
		"La Calle Victoria lleva directo a la Liga Pokémon.",
		"En la Zona Safari viven Pokémon que no verás en otro lado.",
	]
	var key := "gift:%s:%d" % [settlement.get("name", ""), int(float(building.get("x", 0)))]
	var text: String = tips[_rng.randi() % tips.size()]
	if int(_flags().get(key, -1)) != GameState.game_day():
		_flags()[key] = GameState.game_day()
		var gifts := ["oran-berry", "potion", "poke-ball", "great-ball", "sitrus-berry", "repel", "honey"]
		var gift: String = gifts[_rng.randi() % gifts.size()]
		GameState.add_item(gift, 1 + _rng.randi() % 2)
		AudioBus.play_jingle("me_item")
		text += " Toma, llévate esto: %s." % Items.display_name(gift)
	var dialog := _dialog()
	if dialog == null:
		GameState.notice.emit(text)
		return
	var greeting := "¡Hola! Bienvenido a mi casa en %s." % settlement.get("name", "el pueblo")
	dialog.open("Vecino" if look == "" or NpcLooks.GENDER.get(look, "male") == "male" else "Vecina", [greeting, text], TownNPCs.portrait(look if look != "" else "joven_a"))


## Profesor: entrega premios de investigación y comenta tu avance. Habla en la caja de
## diálogo con su nombre y retrato (antes salía como una serie de avisos sueltos).
func talk_professor() -> void:
	var rewards := Research.claim_rewards()
	var caught := 0
	for id: String in GameState.dex:
		caught += 1 if int(GameState.dex[id].get("caught", 0)) > 0 else 0
	var lines: Array[String] = ["Llevas %d especies registradas como capturadas.%s" % [caught, "" if not rewards.is_empty() else " Sigue investigando y vuelve por tus premios."]]
	for message in rewards:
		lines.append(message)
	# Bicicleta y licencias de montura y vuelo (por medallas o actividades cumplidas).
	if GameState.item_count("bicycle") <= 0 and not _flags().get("bike_given", false):
		_flags()["bike_given"] = true
		GameState.add_item("bicycle", 1)
		lines.append("Toma esta Bicicleta para recorrer la región (V / cruceta ←).")
	var done := GameState.activities.filter(func(a: Dictionary) -> bool: return a.get("done", false)).size()
	if not _flags().get("ride_license", false) and (badges().size() >= 1 or done >= 2):
		_flags()["ride_license"] = true
		lines.append("¡Te ganaste la Licencia de Montura! Ya puedes montar Pokémon grandes.")
	if not _flags().get("fly_license", false) and (badges().size() >= 3 or done >= 5):
		_flags()["fly_license"] = true
		lines.append("¡Licencia de Vuelo! Monta a un volador grande y salta para despegar.")
	var ticket_line := _region_ticket()
	if ticket_line != "":
		lines.append(ticket_line)
	# Revive fósiles.
	for fossil: String in FOSSILS:
		if GameState.item_count(fossil) > 0:
			var species := MenuStyle.species(FOSSILS[fossil])
			if species == null:
				continue
			GameState.use_item(fossil)
			var where := GameState.add_caught(species, false, 1.0)
			lines.append("¡Revivimos tu %s! Es un %s (va a tu %s)." % [Items.display_name(fossil), species.display_name, where])
	var dialog := _dialog()
	if dialog == null:
		for line in lines:
			GameState.notice.emit("Prof. %s: %s" % [GameState.professor, line])
		return
	dialog.open("Prof. %s" % GameState.professor, lines, Professor.portrait())


# --- Retos: gimnasio, Liga y concursos --------------------------------------------------

func badges() -> Array:
	if not _flags().has("badges"):
		_flags()["badges"] = []
	return _flags()["badges"]


## Pokémon del líder: de su tipo, más fuertes con cada medalla que ya tienes.
func _team_of_type(type: int, count: int, tier: float) -> Array[SpeciesData]:
	var options: Array[SpeciesData] = []
	for species: SpeciesData in WildSpawner.ALL_SPECIES.species:
		if species.types.has(type) and not species.is_legendary and not species.is_mythical:
			options.append(species)
	options.sort_custom(func(a: SpeciesData, b: SpeciesData) -> bool: return a.base_total < b.base_total)
	var team: Array[SpeciesData] = []
	if options.is_empty():
		return team
	for i in count:
		var center := clampf(tier + (i - count * 0.5) * 0.06, 0.0, 1.0)
		team.append(options[clampi(int(center * (options.size() - 1)) + _rng.randi_range(-2, 2), 0, options.size() - 1)])
	return team


func _dialog() -> DialogBox:
	return get_tree().get_first_node_in_group(&"dialog_box") as DialogBox


## Boleto a otra región: al completar esta (8 medallas, Liga y 11 misiones del Rotom).
## Devuelve lo que dice el profesor sobre el Boleto ("" si no hay nada que comentar).
func _region_ticket() -> String:
	var prof := "Prof. %s" % GameState.professor
	var vehicle := "barco" if TravelTerminal.boat() else "avión"
	var booth := "el muelle" if TravelTerminal.boat() else "el aeropuerto"
	if Regions.ticket_given():
		if not Regions.unlocked().size() <= 1:
			return "%s: Tu Boleto sigue vigente: ve a %s de %s para viajar." % [prof, booth, _world_start_name()]
		return ""
	var p := Regions.progress()
	if p["complete"]:
		var opened := Regions.give_ticket()
		AudioBus.play_jingle("me_badge")
		if opened >= 0:
			GameState.add_news("¡%s completó la %s y recibió el Boleto a la %s!" % [GameState.player_name, Regions.region_name(), Regions.region_name(opened)])
			return "%s: ¡Completaste la %s! Toma este Boleto de %s a la %s. Ve a %s de %s." % [prof, Regions.region_name(), vehicle, Regions.region_name(opened), booth, _world_start_name()]
		return "%s: ¡Completaste la %s! Ya abriste todas las regiones: puedes viajar a cualquiera desde %s." % [prof, Regions.region_name(), booth]
	elif p["badges"] > 0 or p["champion"]:
		return "%s: Para el Boleto a otra región te falta: medallas %d/8 · Liga %s · misiones del Rotom %d/%d." % [prof, p["badges"],
				"✓" if p["champion"] else "pendiente", p["missions"], Regions.MISSIONS_NEEDED]
	return ""


func _world_start_name() -> String:
	var settlements: Array = structures.world.layout.settlements
	return String(settlements[0]["name"]) if not settlements.is_empty() else "el pueblo inicial"


func _battle() -> BattleManager:
	return main().get_node_or_null("Battle") as BattleManager


## Combate de reto (gimnasio o Liga) con la IA lista; on_win al vencer a todo su equipo.
func _challenge(info: Dictionary, on_win: Callable, on_lose: Callable = Callable()) -> bool:
	var battle := _battle()
	if battle == null or not battle.ready_to_fight():
		GameState.notice.emit("%s: Saca a tu Pokémon y peleamos." % info["name"])
		return false
	info["on_end"] = func(result: String) -> void:
		if result == "trainer_win":
			on_win.call()
		elif on_lose.is_valid():
			on_lose.call()
	return battle.start_trainer(info)


# Gimnasios (acordado con Fernando el 2026-10-10): el líder de la región en el pueblo, con
# su sprite y su equipo canónico (de 3 a 6 según la región), y 2 entrenadores opcionales.

## Hablar con el líder: si ya tienes su medalla, te saluda; si no, ofrece el reto.
func talk_leader(settlement: Dictionary, arena: Vector3) -> void:
	var id := structures.leader_of(settlement)
	var city: String = settlement.get("name", "")
	var speaker := "Líder " + Leaders.name_of(id)
	var dialog := _dialog()
	if dialog == null:
		gym_challenge(settlement, arena)
		return
	if badges().has(city):
		dialog.open(speaker, ["¡Ya tienes la medalla de %s! Sigue entrenando: la Liga te espera." % city], Leaders.portrait(id))
		return
	var lines := ["Bienvenido al Gimnasio de %s. Soy %s y uso Pokémon de tipo %s." % [city, Leaders.name_of(id), Leaders.type_name(id)],
			"Llevas %d medallas en esta región. ¿Estás listo?" % badges().size()]
	dialog.open(speaker, lines, Leaders.portrait(id), ["¡Te reto!", "Todavía no"], func(choice: int) -> void:
		if choice == 0:
			gym_challenge(settlement, arena))


func _leaders() -> GymLeaders:
	return main().get_node_or_null("GymLeaders") as GymLeaders


## ¿Está el líder en el gimnasio? (de 9 a 15 h y si no salió de viaje).
func leader_in_gym(settlement: Dictionary) -> bool:
	var leaders := _leaders()
	return leaders == null or leaders.in_gym(settlement)


## El guía del gimnasio: dónde anda el líder (y lo marca en el mapa).
func ask_leader(settlement: Dictionary) -> void:
	var id := structures.leader_of(settlement)
	var leaders := _leaders()
	var text := "El líder %s te espera al fondo. ¡Usa Pokémon fuertes contra el tipo %s!" % [Leaders.name_of(id), Leaders.type_name(id)]
	if leaders != null and not leaders.in_gym(settlement):
		text = leaders.mark_on_map(id)
	var dialog := _dialog()
	if dialog != null:
		dialog.open("Guía del gimnasio", [text], NpcLooks.portrait("joven_c"))
	else:
		GameState.notice.emit("Guía del gimnasio: " + text)


func gym_challenge(settlement: Dictionary, arena: Vector3) -> void:
	var city: String = settlement.get("name", "")
	if badges().has(city):
		GameState.notice.emit("Líder: ya tienes la medalla de %s. ¡Sigue tu camino!" % city)
		return
	if not leader_in_gym(settlement):
		GameState.notice.emit("El líder no está en el gimnasio. Pregúntale al guía dónde anda.")
		return
	var id := structures.leader_of(settlement)
	var region := Regions.index()
	var team := Leaders.gym_team(id, region, badges().size())
	var info := {"id": "gym:" + id, "name": "Líder " + Leaders.name_of(id), "team": team,
			"money": BADGE_MONEY * (badges().size() + 1) * (region + 1), "item": "rare-candy",
			"smart": true, "heals": 1 + region / 2, "mega": Leaders.mega_for(team, region), "at": arena}
	_challenge(info, func() -> void: _win_badge(settlement, id))


func _win_badge(settlement: Dictionary, id: String) -> void:
	var city: String = settlement.get("name", "")
	if badges().has(city):
		return
	badges().append(city)
	AudioBus.play_jingle("me_badge")
	GameState.path_progress["gimnasios"] = mini(badges().size(), 8)
	Achievements.add("badges")
	GameState.add_news("¡%s ganó la medalla del Gimnasio de %s! (%d/8)" % [GameState.player_name, city, badges().size()])
	var dialog := _dialog()
	if dialog != null:
		dialog.open("Líder " + Leaders.name_of(id), ["¡Qué combate! Te ganaste la medalla de %s. Llevas %d de 8." % [city, badges().size()]], Leaders.portrait(id))
	else:
		GameState.notice.emit("¡Ganaste la medalla de %s! Medallas: %d/8" % [city, badges().size()])


## Entrenadores del gimnasio (0 o 1): 2–3 Pokémon del tipo del líder; se vencen una vez.
func gym_trainer_challenge(settlement: Dictionary, slot: int, look: String, arena: Vector3) -> void:
	var key := "gym_trainer:%s:%d" % [settlement.get("name", ""), slot]
	var class_name_ := "Entrenadora Guay" if NpcLooks.gender(look) == "female" else "Entrenador Guay"
	var speaker := "%s del gimnasio" % class_name_
	if _flags().get(key, false):
		var dialog := _dialog()
		if dialog != null:
			dialog.open(speaker, ["¡Ya me venciste! El líder te espera al fondo."], NpcLooks.portrait(look))
		else:
			GameState.notice.emit("%s: ¡ya me venciste! El líder te espera al fondo." % speaker)
		return
	var id := structures.leader_of(settlement)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ int(Regions.current()["seed"])
	var info := {"id": key, "name": speaker, "team": Leaders.gym_trainer_team(id, Regions.index(), rng),
			"money": 400 + Regions.index() * 250, "item": "", "at": arena}
	_challenge(info, func() -> void: _flags()[key] = true)


# Liga (acordado con Fernando el 2026-10-10): 4 del Alto Mando real y un héroe no elegido
# como Campeón, en orden y sin salir; si pierdes o sales, vuelves a empezar.

func league_members() -> Array:
	var region := Regions.current()
	var members: Array = (region["elite"] as Array).duplicate()
	members.append("hero:" + String(region["champion"]))
	return members


## Cuántos venciste en este intento (se reinicia al salir o perder).
func league_step() -> int:
	return int(_flags().get("league_run", 0))


func reset_league() -> void:
	_flags()["league_run"] = 0


func league_talk(slot: int, arena: Vector3) -> void:
	var members := league_members()
	var id: String = members[slot]
	var champion := id.begins_with("hero:")
	var hero := id.trim_prefix("hero:")
	var speaker: String = ("Campeón " + String(PlayerCharacters.find(hero)["name"])) if champion else ("Alto Mando " + Leaders.name_of(id))
	var portrait: Texture2D = Leaders.portrait(hero) if champion else Leaders.portrait(id)
	var dialog := _dialog()
	if badges().size() < Regions.GYMS:
		GameState.notice.emit("Guardia: necesitas las 8 medallas para retar a la Liga (tienes %d)." % badges().size())
		return
	if slot < league_step():
		if dialog != null:
			dialog.open(speaker, ["Ya me venciste. ¡Sigue adelante!"], portrait)
		return
	if slot > league_step():
		var next: String = members[league_step()]
		GameState.notice.emit("Primero vence a %s." % (Leaders.name_of(next) if not next.begins_with("hero:") else "los del Alto Mando"))
		return
	var lines := ["Soy %s, del Alto Mando. Mi especialidad es el tipo %s." % [Leaders.name_of(id), Leaders.type_name(id)]] if not champion \
			else ["Así que llegaste hasta aquí... Soy el Campeón de %s." % Regions.region_name(), "Mi equipo es el más fuerte de la región. ¡Demuéstrame lo que vales!"]
	if dialog == null:
		league_challenge(slot, arena)
		return
	dialog.open(speaker, lines, portrait, ["¡Combate!", "Espera"], func(choice: int) -> void:
		if choice == 0:
			league_challenge(slot, arena))


func league_challenge(slot: int, arena: Vector3) -> void:
	var members := league_members()
	if slot != league_step() or slot >= members.size():
		return
	var id: String = members[slot]
	var region := Regions.index()
	var info := {}
	if id.begins_with("hero:"):
		var hero := id.trim_prefix("hero:")
		info = {"id": "champion:" + hero, "name": "Campeón " + PlayerCharacters.find(hero)["name"], "team": Heroes.team_for(hero, 99),
				"money": 20000 * (region + 1), "item": "master-ball", "smart": true, "heals": 3, "mega": Heroes.TEAMS[hero]["mega"], "at": arena}
	else:
		var team := Leaders.elite_team(id)
		info = {"id": "elite:" + id, "name": "Alto Mando " + Leaders.name_of(id), "team": team, "money": 5000 * (region + 1),
				"item": "", "smart": true, "heals": 2 + region / 2, "mega": Leaders.mega_for(team, region), "at": arena}
	_challenge(info, func() -> void: _league_win(slot), reset_league)


func _league_win(slot: int) -> void:
	_flags()["league_run"] = slot + 1
	if slot + 1 < league_members().size():
		GameState.notice.emit("¡Venciste a %d de %d! Sigue al siguiente." % [slot + 1, league_members().size()])
		return
	reset_league()
	_flags()["champion"] = true
	Achievements.add("champion")
	GameState.add_news("¡%s es el nuevo Campeón de la %s!" % [GameState.player_name, Regions.region_name()])
	var p := Regions.progress()
	var hint := "Ya puedes pedirle el Boleto al Prof. %s." % GameState.professor if p["complete"] \
			else "Para el Boleto a otra región te faltan misiones del Rotom (%d/%d)." % [p["missions"], Regions.MISSIONS_NEEDED]
	GameState.notice.emit("¡Eres el Campeón de la %s! %s" % [Regions.region_name(), hint])


## Reto por rondas: sale un Pokémon del entrenador a la vez y ataca; al debilitarlo
## sale el siguiente. No se pueden capturar. Si te desmayas, el reto termina.
func _start_trial(title: String, team: Array[SpeciesData], arena: Vector3, on_win: Callable) -> void:
	if team.is_empty():
		return
	_trial = {"title": title, "team": team, "index": 0, "arena": arena, "on_win": on_win, "actor": null}
	GameState.notice.emit("¡Comienza el reto: %s! (%d Pokémon)" % [title, team.size()])
	_next_round()


func _next_round() -> void:
	if _trial.is_empty():
		return
	var team: Array = _trial["team"]
	var index: int = _trial["index"]
	if index >= team.size():
		var on_win: Callable = _trial["on_win"]
		_trial = {}
		on_win.call()
		return
	var actor := spawn_wild(team[index], _trial["arena"])
	if actor == null:
		_trial = {}
		return
	actor.set_meta("trainer", true)
	actor.add_to_group(&"trainer_pokemon")
	_trial["actor"] = actor
	(interiors.current.get("actors", []) as Array).append(actor)
	GameState.notice.emit("%s saca a %s (%d/%d)" % [_trial["title"], actor.species.display_name, index + 1, team.size()])
	actor.stunned.connect(_on_trial_stunned, CONNECT_ONE_SHOT)
	var target: Node3D = companion() if companion() != null and companion().visible else player()
	actor.start_fight.call_deferred(target)


func _on_trial_stunned(actor: PokemonActor) -> void:
	if _trial.is_empty() or _trial["actor"] != actor:
		return
	PixelBurst.spawn(actor.get_parent(), actor.global_position, PixelBurst.Kind.HEAL, 0.6)
	actor.queue_free()
	_trial["index"] = int(_trial["index"]) + 1
	await get_tree().create_timer(1.5).timeout
	_next_round()


func trial_active() -> bool:
	return not _trial.is_empty()


func end_trial() -> void:
	if not _trial.is_empty():
		GameState.notice.emit("El reto terminó.")
	_trial = {}


## Concurso: los jueces miran el dominio de los movimientos, la variedad de tipos y el
## vínculo de tu compañero. Con 14 puntos o más ganas la cinta de la sala.
func contest(settlement: Dictionary) -> void:
	if GameState.party.is_empty():
		return
	var hall: String = settlement.get("name", "")
	var key := "contest_day:%s" % hall
	if int(_flags().get(key, -1)) == GameState.game_day():
		_judge_says("El próximo concurso es mañana.")
		return
	_flags()[key] = GameState.game_day()
	var entry: Dictionary = GameState.party[GameState.companion_index]
	Moves.ensure_entry(entry)
	var score := int(entry.get("bond", 1))
	var types := {}
	for id: String in entry["moves"]:
		score += Moves.rank(entry, id) * 2
		types[Moves.get_move(id)["type"]] = true
	score += types.size() + _rng.randi_range(0, 5)
	var name := MenuStyle.species(entry["species"]).display_name
	if score >= 14:
		var ribbons: Array = _flags().get("ribbons", [])
		if not ribbons.has(hall):
			ribbons.append(hall)
			_flags()["ribbons"] = ribbons
			GameState.path_progress["concursos"] = mini(ribbons.size(), 5)
			GameState.add_news("¡%s ganó la cinta del concurso de %s!" % [name, hall])
		GameState.add_money(800, "Concurso de %s" % hall)
		_judge_says("¡%s brilló con %d puntos y ganó el concurso! Cintas: %d/5" % [name, score, (_flags()["ribbons"] as Array).size()])
	else:
		_judge_says("%s sacó %d puntos (necesita 14). Sube el dominio de sus movimientos y su vínculo." % [name, score])


## El juez de la Sala de Concursos habla en la caja de diálogo (antes salía como aviso).
func _judge_says(text: String) -> void:
	var dialog := _dialog()
	if dialog != null:
		dialog.open("Juez", [text], NpcLooks.portrait("guay_chica"))
	else:
		GameState.notice.emit("Juez: " + text)


# --- Lugares especiales ----------------------------------------------------------------------

func _discovery(key: String, text: String) -> bool:
	var found: Array = _flags().get("discoveries", [])
	if found.has(key):
		return false
	found.append(key)
	_flags()["discoveries"] = found
	GameState.path_progress["investigacion"] = mini(found.size(), 10)
	GameState.add_news("Descubrimiento: %s (%d/10)" % [text, found.size()])
	return true


func read_ruins(place: Dictionary) -> void:
	var lines := ["\"Los que cayeron del cielo duermen bajo la montaña.\"", "\"Veintiocho formas, una sola palabra.\"",
			"\"El árbol más viejo recuerda el primer amanecer.\"", "\"Cruza la puerta violeta y estarás lejos.\""]
	var text: String = lines[int(place["id"]) % lines.size()]
	var order := ruin_order(place)
	text += " Debajo: \"Despierta primero al %s, luego a la %s y al final a la %s.\"" % [RUIN_SYMBOLS[order[0]], RUIN_SYMBOLS[order[1]], RUIN_SYMBOLS[order[2]]]
	if _discovery("ruins:%d" % int(place["id"]), "inscripción de las Ruinas Antiguas"):
		text += " (Descubrimiento registrado)"
	GameState.notice.emit("Las inscripciones dicen: " + text)


## Orden de las piedras de unas ruinas (fijo por semilla y lugar).
func ruin_order(place: Dictionary) -> Array:
	var orders := [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
	return orders[absi(hash([int(place["id"]), structures.world.layout.seed])) % orders.size()]


## Tocar una piedra: si sigue el orden avanza; al completarlo, el premio (una vez).
func ruin_stone(place: Dictionary, symbol: int) -> void:
	var key := "ruin_solved:%d" % int(place["id"])
	if _flags().get(key, false):
		GameState.notice.emit("Las piedras ya están despiertas.")
		return
	var progress_key := "ruin_progress:%d" % int(place["id"])
	var progress := int(_flags().get(progress_key, 0))
	var order := ruin_order(place)
	if order[progress] != symbol:
		_flags()[progress_key] = 0
		GameState.notice.emit("La piedra del %s se apaga... El orden no era ese." % RUIN_SYMBOLS[symbol])
		return
	progress += 1
	_flags()[progress_key] = progress
	if progress < 3:
		GameState.notice.emit("La piedra del %s brilla (%d/3)." % [RUIN_SYMBOLS[symbol], progress])
		return
	_flags()[key] = true
	GameState.add_item("star-piece", 2)
	GameState.add_item("old-charm", 1)
	# La Piedra Llave está en un lugar fijo: el primer acertijo de ruinas que resuelvas.
	if GameState.item_count("key-stone") <= 0:
		GameState.add_item("key-stone", 1)
		AudioBus.play_jingle("me_item")
		GameState.notice.emit("¡En el centro de las piedras brilla la Piedra Llave! Con ella y una megapiedra tu Pokémon puede megaevolucionar en combate.")
	_discovery("ruin_puzzle:%d" % int(place["id"]), "el acertijo de las Ruinas Antiguas")
	GameState.notice.emit("¡Las tres piedras despertaron! Encontraste 2 Trozos Estrella y un Amuleto Antiguo. Los Unown se acercan...")
	var unown := MenuStyle.species("unown")
	var p := player()
	if unown != null and p != null:
		for i in 3:
			spawn_wild(unown, p.global_position + Vector3(cos(i * 2.1) * 4.0, 0.3, sin(i * 2.1) * 4.0))


## Tutor: enseña a tu compañero el siguiente movimiento de su lista oficial.
func tutor() -> void:
	if GameState.party.is_empty():
		return
	var entry: Dictionary = GameState.party[GameState.companion_index]
	var name := MenuStyle.species(entry["species"]).display_name
	Moves.ensure_entry(entry)
	var text := ""
	if Moves.next_unlock(entry) == "":
		text = "%s ya conoce todos sus movimientos." % name
	elif GameState.money < TUTOR_PRICE:
		text = "Mis clases cuestan $%d." % TUTOR_PRICE
	else:
		GameState.add_money(-TUTOR_PRICE, "Tutor de movimientos")
		var learned := Moves.unlock_next(entry)
		text = "¡%s aprendió %s! Equípalo en el menú (Equipo)." % [name, Moves.get_move(learned)["name"]]
	var dialog := _dialog()
	if dialog != null:
		dialog.open("Tutor", [text], NpcLooks.portrait("abuelo_a"))
	else:
		GameState.notice.emit("Tutor: " + text)


## Rancho: Leche Mu-mu.
func buy_milk() -> void:
	if GameState.money < 500:
		GameState.notice.emit("Ranchero: la leche cuesta $500.")
		return
	GameState.add_money(-500, "Leche Mu-mu")
	GameState.add_item("moomoo-milk", 1)
	GameState.notice.emit("Ranchero: ¡recién ordeñada! (Leche Mu-mu +1)")


## Huerto: cada fila se cosecha una vez por día.
func harvest(place: Dictionary, row: int) -> void:
	var key := "harvest:%d:%d" % [int(place["id"]), row]
	if int(_flags().get(key, -1)) == GameState.game_day():
		GameState.notice.emit("Esta fila ya se cosechó hoy. Vuelve mañana.")
		return
	_flags()[key] = GameState.game_day()
	var berry: String = ["oran-berry", "pecha-berry", "cheri-berry", "sitrus-berry"][row % 4]
	var amount := _rng.randi_range(2, 4)
	GameState.add_item(berry, amount)
	GameState.gathered.emit(berry, amount)
	GameState.notice.emit("Cosechaste %d %s." % [amount, Items.display_name(berry)])


## Comerciante viajero: 5 objetos raros distintos cada día (precio ×1.5).
func merchant_stock(place: Dictionary) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(place["id"]), GameState.game_day(), structures.world.layout.seed])
	var goods: Array = MERCHANT_GOODS.duplicate()
	var result: Array[String] = []
	for i in 5:
		var id: String = goods.pop_at(rng.randi() % goods.size())
		if Items.exists(id):
			result.append(id)
	return result


func open_merchant(place: Dictionary) -> void:
	var layer := main().get_node_or_null("MenuLayer") as CanvasLayer
	if layer == null or layer.has_node("Shop"):
		return
	var shop := ShopUI.new()
	shop.name = "Shop"
	shop.title = "Comerciante Viajero"
	shop.custom_stock = merchant_stock(place)
	shop.price_factor = 1.5
	layer.add_child(shop)
	shop.open()


## Base secreta: el jefe del equipo criminal reta con sus Pokémon Siniestro y Veneno.
func villain_challenge(arena: Vector3) -> void:
	if not _trial.is_empty():
		return
	if _flags().get("villain_defeated", false):
		GameState.notice.emit("La base está vacía. %s huyó de la región." % GameState.villain_team)
		return
	var team: Array[SpeciesData] = []
	team.append_array(_team_of_type(PokemonTypes.Type.DARK, 2, 0.6))
	team.append_array(_team_of_type(PokemonTypes.Type.POISON, 2, 0.7))
	_start_trial("Jefe del %s" % GameState.villain_team, team, arena, func() -> void:
		_flags()["villain_defeated"] = true
		for group: String in GameState.reputation:
			GameState.reputation[group] = mini(int(GameState.reputation[group]) + 15, 100)
		GameState.occupied_zones.clear()
		GameState.add_money(8000, "Base del %s" % GameState.villain_team)
		GameState.add_news("¡%s desmanteló la base secreta del %s! Las zonas tomadas quedan libres." % [GameState.player_name, GameState.villain_team])
		GameState.notice.emit("¡Derrotaste al jefe del %s! Las zonas tomadas quedan libres." % GameState.villain_team))


func giant_tree(place: Dictionary) -> void:
	if _discovery("giant_tree:%d" % int(place["id"]), "el Árbol Milenario"):
		GameState.add_item("leftovers", 1)
		GameState.notice.emit("El Árbol Milenario dejó caer algo: Restos.")
	else:
		GameState.notice.emit("El viento mueve las hojas del Árbol Milenario.")


func sky_shard(place: Dictionary) -> void:
	if _discovery("floating:%d" % int(place["id"]), "las Ruinas Flotantes"):
		GameState.add_item("comet-shard", 1)
		GameState.notice.emit("¡Encontraste un Fragmento Cometa en las ruinas del cielo!")
	else:
		GameState.notice.emit("Desde aquí se ve toda la región.")


func portal(place: Dictionary) -> void:
	var others := structures.world.layout.places_of("portal").filter(func(p: Dictionary) -> bool: return p["id"] != place["id"])
	if others.is_empty():
		return
	var target: Dictionary = others[0]
	var x := float(target["x"]) + 3.5
	var z := float(target["z"])
	_discovery("portal:%d" % int(place["id"]), "un portal entre dos lugares")
	var p := player()
	if p == null:
		return
	PixelBurst.spawn(main(), p.global_position, PixelBurst.Kind.HEAL, 0.8)
	structures.world.ensure_area(Vector3(x, 0, z))
	move_party_to(Vector3(x, structures.world.height_at(x, z) + 0.5, z))
	GameState.notice.emit("El portal te llevó a otro lugar de la región.")


func reveal_area(center: Vector3, radius: float) -> void:
	var map := main().get_node_or_null("MapUi") as MapUi
	if map != null:
		map.data.reveal(center, radius)
	GameState.notice.emit("Desde lo alto de la torre ves los alrededores (el mapa se actualizó).")


## Zona Safari: pagas la entrada y recibes Safari Balls que solo sirven adentro.
func safari(place: Dictionary) -> void:
	if GameState.item_count("safari-ball") > 0:
		GameState.notice.emit("Ya tienes Safari Balls. ¡Busca Pokémon raros dentro de la cerca!")
		return
	if GameState.money < SAFARI_PRICE:
		GameState.notice.emit("La entrada cuesta $%d." % SAFARI_PRICE)
		return
	GameState.add_money(-SAFARI_PRICE, "Entrada a la Zona Safari")
	GameState.add_item("safari-ball", SAFARI_BALLS)
	GameState.selected_ball = "safari-ball"
	GameState.notice.emit("¡Bienvenido a la Zona Safari! Tienes %d Safari Balls; se devuelven al salir." % SAFARI_BALLS)


func safari_place_at(point: Vector3) -> Dictionary:
	for place: Dictionary in structures.world.layout.places_of("safari"):
		if Vector2(point.x - float(place["x"]), point.z - float(place["z"])).length() < SAFARI_RADIUS:
			return place
	return {}


func safari_species() -> Array[SpeciesData]:
	var pool: Array[SpeciesData] = []
	for id: String in SAFARI_POOL:
		var species := MenuStyle.species(id)
		if species != null:
			pool.append(species)
	return pool


## Guardería: deja un Pokémon del equipo (que no sea tu compañero) y gana Puntos de
## Entrenamiento por cada día del juego; al volver te lo devuelven.
func daycare(_place: Dictionary) -> void:
	var stay: Dictionary = _flags().get("daycare", {})
	if not stay.is_empty():
		var entry: Dictionary = stay["entry"]
		var days := maxi(GameState.game_day() - int(stay["day"]), 0)
		var used := TeamTab._total(entry.get("training", {})) + int(entry.get("training_free", 0))
		var gained := mini(days * DAYCARE_POINTS_PER_DAY, TeamTab.MAX_TOTAL - used)
		entry["training_free"] = int(entry.get("training_free", 0)) + gained
		(GameState.party if GameState.party.size() < 6 else GameState.box).append(entry)
		_flags().erase("daycare")
		GameState.notice.emit("Guardería: ¡aquí está %s! Ganó %d Puntos de Entrenamiento en %d días." % [MenuStyle.species(entry["species"]).display_name, gained, days])
		return
	if GameState.party.size() < 2:
		GameState.notice.emit("Guardería: necesitas otro Pokémon en tu equipo además de tu compañero.")
		return
	for i in GameState.party.size():
		if i != GameState.companion_index:
			var entry: Dictionary = GameState.party[i]
			GameState.party.remove_at(i)
			if GameState.companion_index > i:
				GameState.companion_index -= 1
			_flags()["daycare"] = {"entry": entry, "day": GameState.game_day()}
			GameState.notice.emit("Guardería: cuidaremos a %s. Ganará %d Puntos de Entrenamiento por día." % [MenuStyle.species(entry["species"]).display_name, DAYCARE_POINTS_PER_DAY])
			return


func add_healing_spot(pos: Vector3, radius: float, title: String) -> void:
	_healing_spots.append({"pos": pos, "radius": radius, "title": title})


func healing_spots() -> Array[Dictionary]:
	return _healing_spots


## Tesoro de mazmorra: una Poké Ball en el suelo; se recoge una vez por día del juego.
func place_treasure(owner_interiors: Interiors, root: Node3D, at: Vector3, key: String, rng: RandomNumberGenerator) -> void:
	if int(_flags().get("treasure:" + key, -1)) == GameState.game_day():
		return
	var sprite := Sprite3D.new()
	sprite.texture = Items.icon("poke-ball")
	sprite.pixel_size = 0.03
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.position = at + Vector3.UP * 0.4
	root.add_child(sprite)
	var loot := ["ultra-ball", "hyper-potion", "nugget", "star-piece", "rare-candy", "fire-stone", "water-stone", "thunderstone", "moon-stone", "max-repel", "big-pearl"]
	if key.begins_with("mine:"):
		loot = FOSSILS.keys() + ["hard-stone", "red-shard", "blue-shard", "nugget"]
	elif key.begins_with("shipwreck:"):
		loot = ["big-pearl", "pearl", "nugget", "star-piece", "dive-ball"]
	# Una de cada cuatro veces, una MT al azar.
	if rng.randf() < 0.25:
		loot = ["tm-normal", "tm-fighting", "tm-flying", "tm-poison", "tm-ground", "tm-rock", "tm-bug", "tm-ghost", "tm-steel", "tm-fire",
				"tm-water", "tm-grass", "tm-electric", "tm-psychic", "tm-ice", "tm-dragon", "tm-dark", "tm-fairy"]
	var item: String = loot[rng.randi() % loot.size()]
	var point: Dictionary = {}
	point = structures.add_point(Interiors.ORIGIN + at + Vector3.UP * 0.5, "Recoger el objeto", func() -> void:
		_flags()["treasure:" + key] = GameState.game_day()
		GameState.add_item(item, 1)
		AudioBus.play_jingle("me_item")
		GameState.notice.emit("¡Encontraste %s!" % Items.display_name(item))
		sprite.queue_free()
		structures.remove_point(point), 1.8)
	(owner_interiors.current["points"] as Array).append(point)


func _process(delta: float) -> void:
	var p := player()
	if p == null:
		return
	# Lugares que curan: poco a poco a ti y a tu equipo.
	_healing_notice -= delta
	for spot in _healing_spots:
		if p.global_position.distance_to(spot["pos"]) < float(spot["radius"]):
			p.heal(p.config.health_max * HEAL_SPOT_RATE * delta)
			for member: Dictionary in GameState.party:
				member["hp_ratio"] = minf(float(member.get("hp_ratio", 1.0)) + HEAL_SPOT_RATE * delta, 1.0)
			var c := companion()
			if c != null and c.visible:
				c._heal_to(float(GameState.party[GameState.companion_index].get("hp_ratio", 1.0)) if not GameState.party.is_empty() else 1.0)
			if _healing_notice <= 0.0:
				_healing_notice = 20.0
				GameState.notice.emit("%s: te recuperas poco a poco." % spot["title"])
			break
	# Salvajes amables (Chansey, Blissey, Audino, Happiny) te curan si estás cerca.
	for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
		var wild := node as PokemonActor
		if wild != null and wild.species.identifier in HEALERS and wild.global_position.distance_to(p.global_position) < 4.0 \
				and wild.state not in [PokemonActor.State.FIGHT, PokemonActor.State.CHASE, PokemonActor.State.STUNNED]:
			if p.health < p.config.health_max:
				p.heal(p.config.health_max * 0.15 * delta)
				if _healing_notice <= 0.0:
					_healing_notice = 20.0
					GameState.notice.emit("%s te está curando." % wild.species.display_name)
			break
	# Las Safari Balls se devuelven al salir de la Zona Safari.
	var inside := not safari_place_at(p.global_position).is_empty()
	if _in_safari and not inside and GameState.item_count("safari-ball") > 0:
		GameState.use_item("safari-ball", GameState.item_count("safari-ball"))
		if GameState.selected_ball == "safari-ball":
			GameState.cycle_ball(1)
		GameState.notice.emit("Saliste de la Zona Safari: devolviste las Safari Balls.")
	_in_safari = inside
