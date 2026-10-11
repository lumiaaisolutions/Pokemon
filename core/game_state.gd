extends Node
## Estado global de la partida: equipo, inventario, progreso y banderas del mundo.

## Jugador elegido al iniciar: personaje (ver PlayerCharacters), nombre y dificultad.
var character_id: String = PlayerCharacters.DEFAULT_ID
var player_name: String = "Nate"
var gender: String = "male"
## 0 Fácil, 1 Normal, 2 Difícil (ver DIFFICULTIES).
var difficulty: int = 1
## Por dificultad: daño de los salvajes al jugador, dinero perdido al desmayarse y
## tiempo de recuperación del desmayo (multiplicador).
const DIFFICULTIES: Array[Dictionary] = [
	{"name": "Fácil", "description": "Los salvajes pegan menos, pierdes poco dinero y te recuperas rápido.", "damage": 0.6, "money_loss": 0.05, "recovery": 0.75},
	{"name": "Normal", "description": "La experiencia pensada para el juego.", "damage": 1.0, "money_loss": 0.1, "recovery": 1.0},
	{"name": "Difícil", "description": "Los salvajes pegan fuerte, pierdes más dinero y tardas más en recuperarte.", "damage": 1.4, "money_loss": 0.2, "recovery": 1.25},
]

## Tarjetas de tutorial ya vistas en esta partida: id -> true.
var tips_seen := {}
## Premios del profesor ya entregados (ver Research.REWARDS).
var rewards_claimed := {}

## Semilla del mundo de la partida (0 = la de WorldConfig; una partida nueva elige una al azar).
var world_seed: int = 0
## Banderas del mundo: medallas, cintas, descubrimientos, tesoros, guardería,
## regalos de vecinos, eventos, etc. (ver world/region/town_services.gd).
var world_flags := {}
## Regiones de la partida (ver Regions): nombre, semilla, líderes, Liga, Pokédex regional,
## legendarios, transporte, si está abierta y lo guardado de cada una. region_index: la actual.
var regions: Array = []
var region_index: int = 0

## --- Historia y Rotom Móvil (ver world/rotom/activity_manager.gd) ---
## Elenco al azar de la partida.
var professor := ""
var rival := ""
var villain_team := ""
## Actividades activas e historial de noticias ({"day", "text"}).
var activities: Array = []
var news: Array = []
## Reputación con cada grupo (0 a 100) y progreso en cada camino.
var reputation := {}
var path_progress := {}
var rival_progress := {}
## Zonas tomadas por el equipo criminal: {"x", "z", "radius", "until_day"}.
var occupied_zones: Array = []
## Estadísticas de la partida (logros) y logros desbloqueados (id -> día).
var stats := {}
var achievements := {}
## Movimientos de dinero recientes: {"day", "amount", "reason"}.
var money_log: Array = []


## Suma (o resta) dinero y lo registra en el historial.
func add_money(amount: int, reason: String) -> void:
	money = maxi(money + amount, 0)
	money_log.push_front({"day": game_day() + 1, "amount": amount, "reason": reason})
	if money_log.size() > 25:
		money_log.resize(25)
var _activity_serial := 0


func next_activity_id() -> int:
	_activity_serial += 1
	return _activity_serial


func add_news(text: String) -> void:
	news.push_front({"day": game_day() + 1, "text": text})
	if news.size() > 30:
		news.resize(30)
	notice.emit("[Rotom] " + text)

## Avisos de captura (el HUD los muestra).
signal pokemon_caught(display_name: String, shiny: bool, location: String)
signal capture_failed(display_name: String)

## Probabilidad de que un legendario ya capturado reaparezca (se tira una vez por sesión).
const LEGENDARY_RESPAWN_CHANCE := 0.02

## Equipo (máx. PARTY_MAX) y caja: cada Pokémon es un diccionario
## {"species": identifier, "shiny": bool, "hp_ratio": float}. La Fase 5 lo amplía.
const PARTY_MAX := 6
var party: Array[Dictionary] = []
var box: Array[Dictionary] = []
## Mochila: id del objeto -> cantidad (catálogo en Items). Empieza con Items.starting_bag().
var bag: Dictionary = Items.starting_bag()
## Ball elegida para lanzar (se cambia con la cruceta ↑↓ o R / F).
var selected_ball: String = "poke-ball"
## Cantidad de la ball elegida (compatibilidad: antes era un solo contador).
var pokeballs: int:
	get:
		return item_count(selected_ball)
	set(value):
		bag[selected_ball] = maxi(value, 0)

## Pokédex: identifier -> {"seen": veces vista, "caught": capturas, "shiny": capturó un
## shiny, "behind": capturas por la espalda, "stunned": vistos debilitados en peleas,
## "fights": peleas vistas, "biggest"/"smallest": tamaño récord (m)}.
var dex := {}

signal bag_changed
## Capturaste una especie (identifier) por la espalda o no (lo usan las actividades).
signal species_caught(identifier: String, behind: bool)
## Tu compañero debilitó a un salvaje.
signal wild_defeated(identifier: String)
## Se recogió algo en el mundo (lo usan las actividades del Rotom Móvil).
signal gathered(id: String, amount: int)
## Aviso para el HUD (premios del profesor, etc.).
signal notice(text: String)
signal dex_changed(identifier: String)

## Dinero del jugador. Al desmayarse pierde BLACKOUT_MONEY_LOSS (como en los juegos).
var money: int = 3000
const BLACKOUT_MONEY_LOSS := 0.1
## Dónde reaparece tras desmayarse: el último Centro Pokémon o campamento visitado
## (hasta la capa 2.6, el punto de inicio).
var respawn_point := Vector3(0, 1, 0)

## Legendarios capturados: identifier -> true. Se guarda con la partida (Fase 5).
var legendary_caught := {}
## Resultado de la tirada de reaparición de esta sesión: identifier -> bool.
var _legendary_respawn_roll := {}


## ¿Debe estar el legendario en su lugar? Siempre si no se ha capturado; si ya se
## capturó, solo si salió la tirada del 2 % en esta sesión (nunca más de uno).
func is_legendary_available(identifier: String) -> bool:
	if not legendary_caught.get(identifier, false):
		return true
	if not _legendary_respawn_roll.has(identifier):
		_legendary_respawn_roll[identifier] = randf() < LEGENDARY_RESPAWN_CHANCE
	return _legendary_respawn_roll[identifier]


## Agrega un Pokémon capturado al equipo, o a la caja si el equipo está lleno.
## Devuelve "equipo" o "caja".
func add_caught(species: SpeciesData, shiny: bool, hp_ratio: float, gender: int = -1, size: float = 1.0) -> String:
	var entry := {"species": species.identifier, "shiny": shiny, "hp_ratio": hp_ratio, "gender": gender, "size": size}
	Moves.ensure_entry(entry)
	# Récords de tamaño y sexos registrados.
	var record := dex_entry(species.identifier)
	var height := DexData.height(species.identifier) * size
	record["biggest"] = maxf(float(record["biggest"]), height)
	record["smallest"] = height if float(record["smallest"]) <= 0.0 else minf(float(record["smallest"]), height)
	if gender == 0:
		record["male"] = int(record["male"]) + 1
	elif gender == 1:
		record["female"] = int(record["female"]) + 1
	dex_entry(species.identifier)["seen"] = maxi(dex_entry(species.identifier)["seen"], 1)
	dex_count(species.identifier, "caught")
	if shiny:
		dex_entry(species.identifier)["shiny"] = true
		Achievements.add("shinies")
	Achievements.add("captures")
	for message in Research.claim_rewards():
		notice.emit(message)
	if species.is_legendary or species.is_mythical:
		mark_legendary_caught(species.identifier)
	if party.size() < PARTY_MAX:
		party.append(entry)
		return "equipo"
	box.append(entry)
	return "caja"


## Aplica la pérdida de dinero de un desmayo y devuelve cuánto se perdió.
func apply_blackout_penalty() -> int:
	var lost := int(money * difficulty_value("money_loss"))
	add_money(-lost, "Desmayo")
	Achievements.add("blackouts")
	return lost


## Valor de la dificultad actual ("damage", "money_loss" o "recovery").
func difficulty_value(key: String) -> float:
	return float(DIFFICULTIES[clampi(difficulty, 0, DIFFICULTIES.size() - 1)][key])


## Segundos jugados (sin contar pausas); lo suma la escena principal.
var play_time: float = 0.0
## Un día del juego dura 24 minutos reales (1 min = 1 h).
const DAY_SECONDS := 1440.0
## Miembro del equipo que acompaña al jugador en el mundo.
var companion_index: int = 0
## Repelente y potenciadores activos: tipo -> momento (play_time) en que terminan.
var repel_until: float = 0.0
var boosts := {}


## --- Hambre (campamento, comida y hambre; acordado con Fernando el 2026-10-10) ------
## 10 muslitos en el HUD, junto a los corazones. Se vacían solos en 2 días de juego;
## correr, nadar y pelear los vacían un poco más rápido (ver Player._update_hunger).
## Con la barra vacía, el jugador pierde vida poco a poco hasta quedarse sin vida en
## STARVE_SECONDS. Comer (crudo, de tienda, cocinado, de restaurante o puesto) la llena.
## Dormir en la tienda de campaña NO la llena.
const HUNGER_MAX := 10.0
const HUNGER_EMPTY_SECONDS := DAY_SECONDS * 2.0
const STARVE_SECONDS := 600.0
var hunger: float = HUNGER_MAX


## fast: corriendo, nadando moviéndose o peleando (la vacía ~40 % más rápido).
func drain_hunger(delta: float, fast: bool = false) -> void:
	var rate := HUNGER_MAX / HUNGER_EMPTY_SECONDS * (1.4 if fast else 1.0)
	hunger = maxf(hunger - rate * delta, 0.0)


## Comer: sube la barra de hambre (sin pasarse del máximo).
func feed(amount: float) -> void:
	hunger = minf(hunger + amount, HUNGER_MAX)


## La partida empieza a esta hora del primer día.
const START_HOUR := 8.0


## Día del juego (desde 0) y hora (0 a 24) según el tiempo jugado.
func game_day() -> int:
	return int((play_time + START_HOUR * 60.0) / DAY_SECONDS)


func clock_hour() -> float:
	return fmod(START_HOUR + play_time / 60.0, 24.0)


func is_night() -> bool:
	var hour := clock_hour()
	return hour < 5.5 or hour >= 20.0


## Dormir: avanza hasta las 7:00 del día siguiente.
func sleep_until_morning() -> void:
	var hour := clock_hour()
	var hours := (24.0 - hour) + 7.0 if hour >= 7.0 else 7.0 - hour
	play_time += hours * 60.0


## ¿Está activo el potenciador kind ("speed", "stealth", "shiny") o el repelente ("repel")?
func boost_active(kind: String) -> bool:
	if kind == "repel":
		return play_time < repel_until
	return play_time < float(boosts.get(kind, 0.0))


## ¿Está oscuro (de noche o en una cueva)? Lo usará la Ocaso Ball; el reloj del día
## y la noche lo actualiza.
var dark := false


func is_dark() -> bool:
	return dark


## --- Mochila --------------------------------------------------------------------

func item_count(id: String) -> int:
	return int(bag.get(id, 0))


func add_item(id: String, amount: int = 1) -> void:
	bag[id] = item_count(id) + amount
	bag_changed.emit()


## Gasta amount; devuelve false si no hay suficientes.
func use_item(id: String, amount: int = 1) -> bool:
	if item_count(id) < amount:
		return false
	bag[id] = item_count(id) - amount
	if bag[id] <= 0:
		bag.erase(id)
	bag_changed.emit()
	return true


## Balls que tiene (en el orden del catálogo).
func owned_balls() -> Array[String]:
	var result: Array[String] = []
	for id in Items.ball_ids():
		if item_count(id) > 0:
			result.append(id)
	return result


## Cambia a la siguiente (step = 1) o anterior (-1) ball que tenga.
func cycle_ball(step: int) -> void:
	var owned := owned_balls()
	if owned.is_empty():
		return
	var index := owned.find(selected_ball)
	selected_ball = owned[(index + step + owned.size()) % owned.size()] if index >= 0 else owned[0]
	bag_changed.emit()


## --- Pokédex ----------------------------------------------------------------------

func dex_entry(identifier: String) -> Dictionary:
	if not dex.has(identifier):
		dex[identifier] = {"seen": 0, "caught": 0, "shiny": false, "behind": 0, "stunned": 0, "fights": 0, "biggest": 0.0, "smallest": 0.0,
				"male": 0, "female": 0, "shiny_seen": false}
	return dex[identifier]


func mark_seen(identifier: String) -> void:
	var first: bool = not dex.has(identifier) or dex[identifier]["seen"] == 0
	dex_entry(identifier)["seen"] += 1
	if first:
		dex_changed.emit(identifier)


## Suma uno a un contador de la Pokédex ("caught", "behind", "stunned", "fights").
func dex_count(identifier: String, key: String) -> void:
	var entry := dex_entry(identifier)
	entry[key] = int(entry.get(key, 0)) + 1
	if key == "behind":
		Achievements.add("behind")
	dex_changed.emit(identifier)


func is_seen(identifier: String) -> bool:
	return dex.has(identifier) and dex[identifier]["seen"] > 0


func is_caught(identifier: String) -> bool:
	return dex.has(identifier) and dex[identifier]["caught"] > 0


## Marca un legendario como capturado (lo llamará la captura en la Fase 4).
func mark_legendary_caught(identifier: String) -> void:
	legendary_caught[identifier] = true
	_legendary_respawn_roll[identifier] = false
