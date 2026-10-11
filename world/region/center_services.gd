class_name CenterServices
extends Node
## Todo lo que pasa dentro del Centro Pokémon, más allá de curar al entregar el equipo
## (pedido y decisiones de Fernando, 2026-10-10 noche): curación clásica animada,
## recordador de movimientos, café y zona de descanso, mostrador de intercambios del
## día, revisión de vínculo y salud con la enfermera, sala de entrenamiento con muñecos,
## taquilla de excursiones, fotógrafo (álbum en la Ficha), segundo piso con club de
## combate y tabla de récords, tablón de la región y visitas de líderes/héroes/rival
## curando a su equipo. Vive como hijo de TownServices, igual que Interiors.

const REMINDER_PRICE := 1000
const CAFE_PRICE := 150
const CAFE_DRINKS := ["soda", "moomoo-milk"]
## Especies pequeñas para el mostrador de intercambios del día (siempre existen en el juego).
const TRADE_POOL := ["pidgey", "rattata", "zigzagoon", "bidoof", "patrat", "ledyba", "hoothoot", "spearow", "starly", "pikipek"]
const CLUB_REWARD_MONEY := 300
const FRIENDLY_RESTING_MONEY := 250
const FRIENDLY_RESTING_HEALS := 1

var services: TownServices
var _rng := RandomNumberGenerator.new()
## Combate amistoso en curso (café o club de combate): {"actor", "kind"} o vacío.
var _friendly: Dictionary = {}


func _ready() -> void:
	_rng.randomize()


func _flags() -> Dictionary:
	if not GameState.world_flags.has("center"):
		GameState.world_flags["center"] = {}
	return GameState.world_flags["center"]


func _dialog() -> DialogBox:
	return get_tree().get_first_node_in_group(&"dialog_box") as DialogBox


# --- Curación clásica animada ------------------------------------------------------------

## Entregas el equipo, las Balls se encienden una a una con el jingle (~3 s) y te las
## devuelve ya curadas; también cura al jugador, el veneno y un té llena un poco el
## hambre. Abierto 24 h (a diferencia de la tienda): no pasa por TownNPCs.is_open.
func animated_heal(door: Vector3) -> void:
	var layer := services.main().get_node_or_null("MenuLayer") as CanvasLayer
	if layer == null or layer.has_node("HealAnim"):
		return
	var anim := HealAnimationUI.new()
	anim.name = "HealAnim"
	anim.ball_count = maxi(GameState.party.size(), 1)
	layer.add_child(anim)
	anim.finished.connect(func() -> void:
		services.heal_at_center(door)
		GameState.feed(1.5)
		GameState.notice.emit("La enfermera te invita un té mientras esperas. Ya no tienes tanta hambre."))
	anim.play()


# --- Recordador de movimientos (Escama Corazón o dinero) ---------------------------------

func move_reminder() -> void:
	if GameState.party.is_empty():
		return
	var entry: Dictionary = GameState.party[GameState.companion_index]
	Moves.ensure_entry(entry)
	var forgotten := _forgotten_moves(entry)
	var dialog := _dialog()
	if forgotten.is_empty():
		var text := "%s ya conoce todos los movimientos que ha desbloqueado. No tengo nada que recordarle." % MenuStyle.species(entry["species"]).display_name
		if dialog != null:
			dialog.open("Recordador de movimientos", [text])
		else:
			GameState.notice.emit(text)
		return
	var has_scale := GameState.item_count("heart-scale") > 0
	var price_line := "Con una Escama Corazón es gratis; si no, son $%d." % REMINDER_PRICE
	if dialog == null:
		_do_remind(entry, forgotten[0], has_scale)
		return
	var options: Array = []
	for id: String in forgotten:
		options.append("Recuérdale %s" % Moves.get_move(id)["name"])
	options.append("Nada por ahora")
	dialog.open("Recordador de movimientos", ["¿Qué movimiento quieres que %s recuerde? %s" % [MenuStyle.species(entry["species"]).display_name, price_line]],
			null, options, func(choice: int) -> void:
		if choice >= 0 and choice < forgotten.size():
			_do_remind(entry, forgotten[choice], GameState.item_count("heart-scale") > 0))


func _forgotten_moves(entry: Dictionary) -> Array:
	var unlocked: Array = entry.get("unlocked", [])
	var known: Array = entry.get("moves", [])
	var result: Array = []
	for id: String in unlocked:
		if not known.has(id):
			result.append(id)
	return result


func _do_remind(entry: Dictionary, move_id: String, use_scale: bool) -> void:
	if not use_scale and GameState.money < REMINDER_PRICE:
		GameState.notice.emit("El recordador cuesta $%d (o una Escama Corazón)." % REMINDER_PRICE)
		return
	if use_scale:
		GameState.use_item("heart-scale", 1)
	else:
		GameState.add_money(-REMINDER_PRICE, "Recordador de movimientos")
	var known: Array = entry.get("moves", [])
	if known.size() >= 4:
		known.remove_at(0)
	known.append(move_id)
	entry["moves"] = known
	AudioBus.play_jingle("me_waza")
	GameState.notice.emit("¡%s recordó %s! Revisa el orden en el menú (Equipo)." % [MenuStyle.species(entry["species"]).display_name, Moves.get_move(move_id)["name"]])


# --- Café y zona de descanso --------------------------------------------------------------

func cafe() -> void:
	if GameState.money < CAFE_PRICE:
		GameState.notice.emit("El café cuesta $%d." % CAFE_PRICE)
		return
	GameState.add_money(-CAFE_PRICE, "Café del Centro Pokémon")
	var drink: String = CAFE_DRINKS[_rng.randi() % CAFE_DRINKS.size()]
	GameState.add_item(drink, 1)
	GameState.feed(2.5)
	if not GameState.party.is_empty():
		var entry: Dictionary = GameState.party[GameState.companion_index]
		entry["bond_xp"] = float(entry.get("bond_xp", 0.0)) + 2.0
	GameState.notice.emit("Te sientas un momento en la zona de descanso con %s." % Items.display_name(drink))


## Entrenador que descansa: platicar o un combate amistoso real (equipo completo, IA
## lista y curaciones con BattleManager.start_trainer; revisión de Fernando, 2026-10-11
## mañana: antes era 1 solo Pokémon salvaje "de entrenador" sin derrota real, ver
## docs/decisiones_sin_preguntar.md). Sin perder dinero al perder (main.gd, no_penalty).
func resting_trainer(look: String, node: Node3D = null) -> void:
	var dialog := _dialog()
	var lines: Array[String] = ["Vine a que mi equipo descanse un poco. ¿Platicamos o quieres un combate amistoso?"]
	if dialog == null:
		GameState.notice.emit("Entrenador: " + lines[0])
		return
	dialog.open("Entrenador", lines, NpcLooks.portrait(look), ["Platicar", "Combate amistoso"], func(choice: int) -> void:
		if choice == 1:
			_start_friendly("Entrenador que descansaba", node, _random_team(_rng.randi_range(1, 2)), FRIENDLY_RESTING_MONEY, "", FRIENDLY_RESTING_HEALS)
		else:
			dialog.open("Entrenador", ["Buen viaje. Aquí seguiré descansando."], NpcLooks.portrait(look)))


## Especies al azar para los combates amistosos genéricos (café, club): mismo pozo
## salvaje de siempre, sin escalar con medallas (son solo diversión, no un reto de
## progresión de la región).
func _random_team(size: int) -> Array[SpeciesData]:
	var pool: Array = WildSpawner.ALL_SPECIES.species.duplicate()
	pool.shuffle()
	var team: Array[SpeciesData] = []
	for i in mini(size, pool.size()):
		team.append(pool[i])
	return team


## Combate de entrenador real (café, club de combate y visitas: mismo patrón que
## GymLeaders.friendly_battle, Heroes._challenge y Rival._fight, ya con IA real).
## on_result (opcional) recibe el resultado ("trainer_win"/"lose"/"flee"/"capture") para
## que el club de combate lleve su racha; sin perder dinero al perder (main.gd,
## no_penalty en el trainer info).
func _start_friendly(title: String, node: Node3D, team: Array, money: int, item: String, heals: int, mega: String = "", on_result: Callable = Callable()) -> bool:
	if not _friendly.is_empty() or team.is_empty():
		return false
	var battle := services.main().get_node_or_null("Battle") as BattleManager
	var player := services.player()
	if battle == null or player == null or not battle.ready_to_fight():
		GameState.notice.emit("%s: Saca a tu Pokémon y peleamos." % title)
		return false
	var anchor: Vector3 = node.global_position if node != null and is_instance_valid(node) else player.global_position + Vector3(0, 0, -5)
	var at := anchor
	if anchor.distance_to(player.global_position) > 0.1:
		at = anchor + (player.global_position - anchor).normalized() * 2.5
	var info := {"id": "friendly:" + title, "name": title, "team": team, "money": money, "item": item,
			"smart": true, "heals": heals, "mega": mega, "no_penalty": true, "at": at, "node": node}
	_friendly = {"title": title}
	info["on_end"] = func(result: String) -> void:
		_friendly = {}
		if on_result.is_valid():
			on_result.call(result)
	if not battle.start_trainer(info):
		_friendly = {}
		return false
	return true


# --- Mostrador de intercambios del día -----------------------------------------------------

func trade_counter() -> void:
	var offer := daily_trade(GameState.world_seed)
	var dialog := _dialog()
	var lines: Array[String] = ["Hoy cambio un %s de otra región por un %s tuyo. ¿Tienes uno?" % [MenuStyle.species(offer["give"]).display_name, MenuStyle.species(offer["want"]).display_name]]
	if dialog == null:
		GameState.notice.emit(lines[0])
		return
	var index := _find_species(offer["want"])
	if index < 0:
		dialog.open("Mostrador de intercambios", lines + ["Parece que no tienes uno ahora mismo."])
		return
	dialog.open("Mostrador de intercambios", lines, null, ["Intercambiar", "Ahora no"], func(choice: int) -> void:
		if choice == 0:
			_do_trade(offer, index))


func daily_trade(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([GameState.game_day(), seed_value]) ^ 0x7ade
	var pool := TRADE_POOL.filter(func(id: String) -> bool: return MenuStyle.species(id) != null)
	var want: String = pool[rng.randi() % pool.size()]
	var give: String = pool[rng.randi() % pool.size()]
	return {"want": want, "give": give}


func _find_species(identifier: String) -> int:
	for i in GameState.party.size():
		if i != GameState.companion_index and String(GameState.party[i]["species"]) == identifier:
			return i
	for i in GameState.box.size():
		if String(GameState.box[i]["species"]) == identifier:
			return -2 - i
	return -1


func _do_trade(offer: Dictionary, index: int) -> void:
	if index >= 0:
		GameState.party.remove_at(index)
		if GameState.companion_index > index:
			GameState.companion_index -= 1
	elif index <= -2:
		GameState.box.remove_at(-2 - index)
	var species := MenuStyle.species(offer["give"])
	var where := GameState.add_caught(species, false, 1.0)
	GameState.notice.emit("¡Intercambio hecho! Recibiste un %s (va a tu %s)." % [species.display_name, where])


# --- Revisión de vínculo y salud con la enfermera -------------------------------------------

func checkup() -> void:
	var dialog := _dialog()
	var lines: Array[String] = []
	if GameState.party.is_empty():
		lines.append("Todavía no tienes compañero para revisar.")
	else:
		var entry: Dictionary = GameState.party[GameState.companion_index]
		var bond := int(entry.get("bond", 1))
		var hp := int(round(float(entry.get("hp_ratio", 1.0)) * 100.0))
		lines.append("%s: vínculo %d/10, salud %d%%, hambre %d/%d." % [MenuStyle.species(entry["species"]).display_name, bond, hp, int(GameState.hunger), int(GameState.HUNGER_MAX)])
		if GameState.hunger < GameState.HUNGER_MAX * 0.3:
			lines.append("Dale de comer pronto: se nota cansado.")
		elif bond < 5:
			lines.append("Pasa más tiempo con él fuera de su Ball para que el vínculo suba.")
		else:
			lines.append("¡Se ve en muy buena forma!")
	if dialog != null:
		dialog.open("Enfermera", lines, NpcLooks.portrait("enfermera"))
	else:
		for line in lines:
			GameState.notice.emit("Enfermera: " + line)


# --- Sala de entrenamiento con muñecos (sube el dominio de movimientos) --------------------

const TRAINING_REPS := 3


func training_room() -> void:
	if GameState.party.is_empty():
		return
	var entry: Dictionary = GameState.party[GameState.companion_index]
	Moves.ensure_entry(entry)
	var known: Array = entry.get("moves", [])
	var dialog := _dialog()
	if known.is_empty():
		return
	if dialog == null:
		_practice(entry, known[0])
		return
	var options: Array = []
	for id: String in known:
		options.append("Practicar %s (dominio %d)" % [Moves.get_move(id)["name"], Moves.rank(entry, id)])
	dialog.open("Sala de entrenamiento", ["Elige un movimiento para practicar contra los muñecos."], null, options, func(choice: int) -> void:
		if choice >= 0 and choice < known.size():
			_practice(entry, known[choice]))


func _practice(entry: Dictionary, move_id: String) -> void:
	var before := Moves.rank(entry, move_id)
	var learned := ""
	for i in TRAINING_REPS:
		var result := Moves.register_use(entry, move_id)
		if result != "":
			learned = result
	var after := Moves.rank(entry, move_id)
	var text := "%s practicó %s contra los muñecos." % [MenuStyle.species(entry["species"]).display_name, Moves.get_move(move_id)["name"]]
	if after > before:
		text += " ¡Subió a dominio %d!" % after
	if learned != "":
		text += " Y de paso desbloqueó %s." % Moves.get_move(learned)["name"]
	GameState.notice.emit(text)


# --- Taquilla de excursiones (tours guiados) -------------------------------------------------

const EXCURSION_PRICE := 400


func excursion_desk() -> void:
	var key := "excursion:%d" % GameState.game_day()
	var dialog := _dialog()
	if _flags().get(key, false):
		var text := "Ya hiciste tu excursión de hoy. Vuelve mañana."
		if dialog != null:
			dialog.open("Taquilla de excursiones", [text])
		else:
			GameState.notice.emit(text)
		return
	var spot := _excursion_spot()
	if spot.is_empty():
		var text := "Hoy no tenemos excursiones programadas. Explora por tu cuenta."
		if dialog != null:
			dialog.open("Taquilla de excursiones", [text])
		else:
			GameState.notice.emit(text)
		return
	if dialog == null:
		_do_excursion(key, spot)
		return
	dialog.open("Taquilla de excursiones", ["Tenemos un tour guiado por $%d: %s. ¿Vamos?" % [EXCURSION_PRICE, spot["label"]]], null,
			["Ir", "Ahora no"], func(choice: int) -> void:
		if choice == 0:
			_do_excursion(key, spot))


## Qué excursión hay hoy: una bandada aterrizada o, si no, nada (no se invita a inventar
## cuevas tapadas que no existen todavía en el mundo).
func _excursion_spot() -> Dictionary:
	var main := services.main()
	var migrations := main.get_node_or_null("Migrations")
	if migrations != null and migrations.has_method("landed") and migrations.landed() and migrations.has_method("current"):
		var flock: Dictionary = migrations.current()
		if not flock.is_empty() and flock.has("pos"):
			return {"label": "ver la bandada que aterrizó cerca", "pos": flock["pos"]}
	return {}


func _do_excursion(key: String, spot: Dictionary) -> void:
	if GameState.money < EXCURSION_PRICE:
		GameState.notice.emit("El tour cuesta $%d." % EXCURSION_PRICE)
		return
	GameState.add_money(-EXCURSION_PRICE, "Excursión guiada")
	_flags()[key] = true
	var pos: Vector3 = spot.get("pos", services.player().global_position)
	services.structures.world.ensure_area(pos)
	services.move_party_to(pos + Vector3(2.0, 0.5, 0))
	GameState.notice.emit("El guía te lleva a %s." % spot["label"])


# --- Fotógrafo (cabina de fotos, queda en la Ficha) -------------------------------------------

## Cabina de fotos (completando la simplificación anotada en
## docs/decisiones_sin_preguntar.md: antes solo contaba cuántas fotos y con quién, sin
## generar una imagen real). Reusa PhotoMode (la misma cámara con la que se fotografían
## los Pokémon salvajes, "photo" en el mundo): captura el viewport de verdad con tu
## compañero y la guarda en user://fotos/, visible en la Ficha y en el álbum del Rotom
## (que ya lee toda esa carpeta).
func photo_booth() -> void:
	var companion := services.companion()
	var dialog := _dialog()
	if companion == null or GameState.party.is_empty():
		var text := "Saca a tu compañero para la foto."
		if dialog != null:
			dialog.open("Fotógrafo", [text])
		else:
			GameState.notice.emit(text)
		return
	var flags := _flags()
	var photo := get_tree().get_first_node_in_group(&"photo_mode") as PhotoMode
	if photo != null:
		await photo.take()
		if photo.last_saved_path != "":
			flags["photo_booth_path"] = photo.last_saved_path
	flags["photo_booth_count"] = int(flags.get("photo_booth_count", 0)) + 1
	flags["photo_booth_last"] = MenuStyle.species(GameState.party[GameState.companion_index]["species"]).display_name
	var text := "¡Sonrían! Guardamos la foto con %s en tu Ficha." % flags["photo_booth_last"]
	if dialog != null:
		dialog.open("Fotógrafo", [text])
	else:
		GameState.notice.emit(text)


func photo_booth_count() -> int:
	return int(_flags().get("photo_booth_count", 0))


## Ruta de la última foto real de la cabina (o "" si todavía no se ha tomado ninguna).
func photo_booth_path() -> String:
	return String(_flags().get("photo_booth_path", ""))


# --- Segundo piso: club de combate y tabla de récords --------------------------------------

func club_streak() -> int:
	return int(_flags().get("club_streak", 0))


func club_record() -> int:
	return int(_flags().get("club_record", 0))


func combat_club(node: Node3D = null) -> void:
	var dialog := _dialog()
	var text := "Club de combate: racha actual %d, récord %d. ¿Peleamos?" % [club_streak(), club_record()]
	if dialog == null:
		_club_duel(node)
		return
	dialog.open("Club de combate", [text], null, ["¡Vamos!", "Ahora no"], func(choice: int) -> void:
		if choice == 0:
			_club_duel(node))


## Combate de entrenador real; el equipo y el premio crecen con la racha (en vez de un
## solo Pokémon salvaje sin derrota real, ver docs/decisiones_sin_preguntar.md).
func _club_duel(node: Node3D) -> void:
	var streak := club_streak()
	var size := clampi(1 + streak / 2, 1, 6)
	var money := CLUB_REWARD_MONEY + 50 * mini(streak, 10)
	var heals := 1 + streak / 4
	_start_friendly("Club de combate", node, _random_team(size), money, "", heals, "", func(result: String) -> void:
		if result == "trainer_win":
			var new_streak := streak + 1
			_flags()["club_streak"] = new_streak
			if new_streak > club_record():
				_flags()["club_record"] = new_streak
			GameState.notice.emit("¡Victoria %d en el club de combate! (récord %d) +$%d" % [new_streak, club_record(), money])
		elif result == "lose":
			_flags()["club_streak"] = 0
			GameState.notice.emit("Perdiste la racha del club de combate. No perdiste dinero: era un combate amistoso."))


# --- Tablón de la región -------------------------------------------------------------------

func region_board(settlement: Dictionary) -> void:
	var lines: Array[String] = []
	var events: Dictionary = GameState.world_flags.get("events", {})
	if events.has("migration_next"):
		var days := int(events["migration_next"]) - GameState.game_day()
		if days >= 0 and days <= 3:
			lines.append("Brote: se espera una bandada en %d día(s)." % days)
	var leaders := services.main().get_node_or_null("GymLeaders")
	if leaders != null and leaders.has_method("in_gym"):
		var in_gym: bool = leaders.in_gym(settlement)
		lines.append("El líder de %s está %s hoy." % [settlement.get("name", "aquí"), "en su gimnasio" if in_gym else "fuera, de viaje"])
	lines.append("Peticiones de los vecinos: pregunta en el tablón de la Tienda Pokémon.")
	var dialog := _dialog()
	if dialog == null:
		for line in lines:
			GameState.notice.emit(line)
		return
	dialog.open("Tablón de la región", lines)


# --- Visitas de líderes, héroes y rival curando a su equipo --------------------------------

const VISITOR_CHANCE := 0.25
## Peso relativo de cada tipo de visitante cuando hay héroes de verdad pasando hoy por
## este pueblo (Heroes.location) o toca la visita suelta del rival: completando la
## simplificación anotada en docs/decisiones_sin_preguntar.md ("solo el líder de la
## ciudad por ahora"), ahora también puede tocar un héroe no elegido o Hugh.
const RIVAL_VISIT_CHANCE := 0.12


## Visitante de hoy (o {} si no toca ninguno): {"id", "kind" ("leader"/"hero"/"rival"),
## "sprite_id" (lo que se le pasa a Interiors._npc para su aspecto), "name"}.
func maybe_visitor(settlement: Dictionary) -> Dictionary:
	var key := "visitor:%s:%d" % [settlement.get("name", ""), GameState.game_day()]
	if _flags().get(key, false) or _rng.randf() > VISITOR_CHANCE:
		return {}
	_flags()[key] = true
	var candidates: Array[Dictionary] = []
	var leader_id := services.structures.leader_of(settlement)
	if leader_id != "":
		candidates.append({"id": leader_id, "kind": "leader", "sprite_id": Leaders.look(leader_id), "name": Leaders.name_of(leader_id)})
	var heroes := services.main().get_node_or_null("Heroes")
	if heroes != null and heroes.has_method("roster") and heroes.has_method("location"):
		for id: String in heroes.roster():
			var loc: Dictionary = heroes.location(id)
			if String(loc.get("name", "")) == String(settlement.get("name", "")):
				candidates.append({"id": id, "kind": "hero", "sprite_id": id, "name": PlayerCharacters.find(id)["name"]})
	if _rng.randf() < RIVAL_VISIT_CHANCE:
		candidates.append({"id": "hugh", "kind": "rival", "sprite_id": "hugh", "name": GameState.rival})
	if candidates.is_empty():
		return {}
	return candidates[_rng.randi() % candidates.size()]


func _visitor_portrait(visitor: Dictionary) -> Texture2D:
	match String(visitor.get("kind", "")):
		"leader":
			return Leaders.portrait(visitor["id"])
		"rival":
			return NpcLooks.portrait("hugh")
		_:
			var sheet := PlayerCharacters.sheet(visitor["id"])
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(0, 0, sheet.get_width() / 3.0, sheet.get_height() / 8.0)
			return atlas


## Hablar con la visita: platicar o pedirle un combate amistoso real (mismo patrón que
## el café y el club de combate; antes era un solo Pokémon salvaje sin derrota real,
## ver docs/decisiones_sin_preguntar.md). node: el sprite real que Interiors puso en el
## cuarto (para la posición y las burbujas del combate).
func talk_visitor(visitor: Dictionary, node: Node3D = null) -> void:
	var dialog := _dialog()
	var kind_title: String = {"leader": "Líder", "hero": "Entrenador", "rival": "Rival"}.get(String(visitor.get("kind", "")), "Visita")
	var name: String = visitor.get("name", "Alguien")
	var text := "%s: vine a curar a mi equipo después de unos combates duros." % name
	if dialog == null:
		GameState.notice.emit(text)
		return
	dialog.open("%s %s" % [kind_title, name], [text], _visitor_portrait(visitor), ["Platicar", "Combate amistoso"], func(choice: int) -> void:
		if choice == 1:
			_visitor_duel(visitor, name, node)
		else:
			dialog.open("%s %s" % [kind_title, name], ["Buen viaje. Aquí seguiré un rato más."], _visitor_portrait(visitor)))


## Equipo real del visitante según su tipo (mismo cálculo que su combate de verdad en
## el mundo: líder en GymLeaders.friendly_battle, héroe en Heroes._challenge y rival en
## Rival._fight).
func _visitor_duel(visitor: Dictionary, name: String, node: Node3D) -> void:
	var region := Regions.index()
	var badges := Regions.total_badges()
	match String(visitor.get("kind", "")):
		"leader":
			var id: String = visitor["id"]
			var team := Leaders.gym_team(id, region, Regions.badges())
			_start_friendly(name, node, team, GymLeaders.FRIENDLY_MONEY * (region + 1), "", 1, Leaders.mega_for(team, region))
		"hero":
			var id: String = visitor["id"]
			var team := Heroes.team_for(id, badges)
			_start_friendly(name, node, team, 1500 + 600 * badges, ["rare-candy", "star-piece", "ultra-ball", "nugget"][badges % 4], 2)
		"rival":
			var stage := 1 if badges < 2 else (2 if badges < 5 else 3)
			var team: Array[SpeciesData] = []
			for id: String in (Rival.team_ids() as Array).slice(0, clampi(2 + int(ceil(badges / 2.0)), 2, 6)):
				team.append(MenuStyle.species(Heroes._stage_form(id, stage)))
			_start_friendly(name, node, team, 1200 + 500 * badges, ["super-potion", "great-ball", "ultra-ball", "rare-candy"][badges % 4], 1)
