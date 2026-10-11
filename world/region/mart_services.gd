class_name MartServices
extends Node
## Todo lo que pasa dentro de la Tienda Pokémon, más allá de comprar y vender (pedido y
## decisiones de Fernando, 2026-10-10 noche): dos dependientes (general y de la ciudad,
## en el segundo piso), estantes con objetos reales, tarjeta de puntos, tablón de
## anuncios, oferta del día, un niño que regala o intercambia una vez al día, pedidos por
## encargo, existencias limitadas que se reabastecen cada mañana, máquina de bebidas,
## ruleta diaria, vender lo recolectado al precio del día, mostrador de regalos, eventos
## de temporada avisados por el Rotom, un ladrón ocasional del equipo villano y el
## "empleado del mes". Vive como hijo de TownServices, igual que Interiors.

## Objetos del estante del dependiente general (abajo): salud, señuelos y comida.
const GENERAL_SHELVES := ["potion", "super-potion", "antidote", "repel", "escape-rope", "poke-doll", "honey", "oran-berry", "bread"]
## Objetos del estante del dependiente de la ciudad (arriba): MT, Balls especiales y comida regional.
const CITY_SHELVES := ["great-ball", "ultra-ball", "quick-ball", "net-ball", "full-heal", "max-repel", "nest-ball", "heal-ball", "curry-can"]
## Unidades de cada estante disponibles por día (se reabastecen cada mañana).
const STOCK_PER_DAY := 6
## Objetos que se pueden vender a precio del día (recolectables).
const COLLECTIBLES := ["nugget", "pearl", "big-pearl", "star-piece", "stardust", "red-shard", "blue-shard", "hard-stone"]
const LOYALTY_PER_PREMIER := 10
## Premio mayor cada N Premier Ball ganadas.
const LOYALTY_MAJOR_EVERY := 5
const DRINK_PRICE := 200
const DRINKS := ["soda", "moomoo-milk"]
const ORDER_CATALOG := ["rare-candy", "lucky-egg", "leftovers", "hyper-potion", "star-piece"]
const ORDER_PREMIUM := 1.15
const ROULETTE_PRIZES := ["poke-ball", "potion", "oran-berry", "rare-candy", "nugget", "great-ball", "star-piece"]
## Compras necesarias para ser "cliente VIP" (empleado del mes te saluda por tu nombre).
const EMPLOYEE_THRESHOLD := 15
## Gustos del mostrador de regalos: a quién, qué le gusta.
const GIFT_LIKES := {
	"Vecino": ["oran-berry", "sitrus-berry", "poke-doll", "honey"],
	"Líder del gimnasio": ["rare-candy", "nugget", "hyper-potion", "leftovers"],
	"Profesor": ["fire-stone", "water-stone", "leaf-stone", "moon-stone", "shiny-stone"],
}
## Ladrón: tiempo que tarda en llegar a la puerta y escapar si no lo alcanzas.
const THIEF_ESCAPE_SECONDS := 14.0
const THIEF_CATCH_RADIUS := 1.6
const THIEF_CHANCE := 0.3

var services: TownServices
var _rng := RandomNumberGenerator.new()
## Ladrón activo ahora: {"node", "timer", "arena", "settlement"} o vacío.
var _thief: Dictionary = {}
## Ambiente de "ruido de gente" dentro de la tienda (si existe el archivo).
var _ambient: AudioStreamPlayer
## Cuenta regresiva para que un cliente compre algo (existencias que también bajan sin
## que tú compres, acordado con Fernando el 2026-10-10).
var _customer_timer := 0.0


func _ready() -> void:
	_rng.randomize()


func _flags() -> Dictionary:
	if not GameState.world_flags.has("mart"):
		GameState.world_flags["mart"] = {}
	return GameState.world_flags["mart"]


func _dialog() -> DialogBox:
	return get_tree().get_first_node_in_group(&"dialog_box") as DialogBox


func _interiors() -> Interiors:
	return services.interiors


# --- Existencias limitadas por día (reabasto cada mañana) ------------------------------

func _day_stock(settlement: Dictionary) -> Dictionary:
	var key: String = settlement.get("name", "")
	var flags := _flags()
	var store: Dictionary = flags.get("stock", {})
	var entry: Dictionary = store.get(key, {})
	if int(entry.get("day", -1)) != GameState.game_day():
		entry = {"day": GameState.game_day()}
		for id: String in GENERAL_SHELVES + CITY_SHELVES:
			entry[id] = STOCK_PER_DAY
		store[key] = entry
		flags["stock"] = store
	return entry


func remaining(settlement: Dictionary, id: String) -> int:
	return int(_day_stock(settlement).get(id, STOCK_PER_DAY))


## Un cliente de la tienda compró uno (rutina, ver _process): baja existencias sin avisar
## con una ventana si ya está en 0.
func _customer_buys(settlement: Dictionary) -> void:
	var entry := _day_stock(settlement)
	var options: Array[String] = []
	for id: String in entry:
		if id != "day" and int(entry[id]) > 0:
			options.append(id)
	if options.is_empty():
		return
	var id: String = options[_rng.randi() % options.size()]
	entry[id] = int(entry[id]) - 1


# --- Mostrador: saludo (empleado del mes), tienda y tarjeta de puntos ------------------

func loyalty() -> Dictionary:
	var flags := _flags()
	if not flags.has("loyalty"):
		flags["loyalty"] = {"points": 0, "premiers": 0, "majors": 0}
	return flags["loyalty"]


func loyalty_text() -> String:
	var loy := loyalty()
	return "Tarjeta de puntos: %d/%d Balls para tu próxima Premier Ball (ya ganaste %d)" % [int(loy["points"]), LOYALTY_PER_PREMIER, int(loy["premiers"])]


## Tarjeta de puntos: una Premier Ball por cada 10 Balls compradas; cada 5 Premier Ball,
## un premio mayor.
func _add_loyalty(balls_bought: int) -> void:
	if balls_bought <= 0:
		return
	var loy := loyalty()
	loy["points"] = int(loy["points"]) + balls_bought
	while int(loy["points"]) >= LOYALTY_PER_PREMIER:
		loy["points"] = int(loy["points"]) - LOYALTY_PER_PREMIER
		loy["premiers"] = int(loy["premiers"]) + 1
		GameState.add_item("premier-ball", 1)
		AudioBus.play_jingle("me_item")
		GameState.notice.emit("¡Tarjeta de puntos! Te ganaste una Premier Ball (%d en total)." % int(loy["premiers"]))
		if int(loy["premiers"]) % LOYALTY_MAJOR_EVERY == 0:
			loy["majors"] = int(loy["majors"]) + 1
			GameState.add_item("rare-candy", 1)
			GameState.notice.emit("¡Premio mayor de la tarjeta de puntos! Te llevas un Caramelo Raro.")


func _is_ball(id: String) -> bool:
	return Items.get_item(id).has("ball")


## Cuántas Balls cuenta una compra para la tarjeta de puntos.
func _balls_in(id: String, amount: int) -> int:
	return amount if _is_ball(id) else 0


## Compras totales (empleado del mes).
func _purchases() -> int:
	return int(_flags().get("purchases", 0))


## Dependiente del mostrador (general o de la ciudad): saludo según cuántas veces has
## comprado (empleado del mes: te saluda por tu nombre, rumores exclusivos y aviso antes
## de las rebajas) y abre la tienda con su surtido, existencias, oferta del día, tarjeta
## de puntos y venta de lo recolectado (solo el general).
func open_counter(settlement: Dictionary, counter: String) -> void:
	var vip := _purchases() >= EMPLOYEE_THRESHOLD
	var dialog := _dialog()
	if dialog != null:
		var speaker := "Dependiente" if NpcLooks.GENDER.get("dependiente", "male") == "male" else "Dependienta"
		var greeting := ("¡Bienvenido, %s! ¿Qué te traigo hoy?" % GameState.player_name) if vip else "Bienvenido a la Tienda Pokémon."
		var lines: Array[String] = [greeting]
		if vip and counter == "general":
			lines.append(_employee_rumor())
		dialog.open(speaker, lines, NpcLooks.portrait("dependiente"))
	_open_shop(settlement, counter)


func _employee_rumor() -> String:
	var rumors := [
		"No se lo digas a nadie, pero mañana subirán las existencias de MT.",
		"Dicen que un líder de gimnasio anda de viaje por la región.",
		"Entre tú y yo: la próxima temporada trae rebajas en toda la tienda.",
		"Un cliente dejó pistas de un brote de Pokémon raros cerca de aquí.",
	]
	return rumors[absi(hash([GameState.game_day(), "employee"])) % rumors.size()]


func _open_shop(settlement: Dictionary, counter: String) -> void:
	var layer := services.main().get_node_or_null("MenuLayer") as CanvasLayer
	if layer == null or layer.has_node("Shop"):
		return
	var shop := ShopUI.new()
	shop.name = "Shop"
	shop.title = "Tienda Pokémon" if counter == "general" else "Tienda Pokémon (planta alta)"
	var shelves: Array[String] = GENERAL_SHELVES if counter == "general" else CITY_SHELVES
	shop.custom_stock = shelves + ShopUI.stock().filter(func(id: String) -> bool: return not shelves.has(id))
	var limits := {}
	for id: String in shelves:
		limits[id] = remaining(settlement, id)
	shop.stock_limits = limits
	shop.discount_id = daily_offer(settlement)
	shop.loyalty_text = loyalty_text()
	if counter == "general":
		var overrides := {}
		for id: String in COLLECTIBLES:
			if Items.exists(id):
				overrides[id] = collectible_price(id)
		shop.sell_price_overrides = overrides
	shop.on_bought = func(id: String, amount: int) -> void:
		_on_bought(settlement, id, amount)
	layer.add_child(shop)
	shop.open()


func _on_bought(settlement: Dictionary, id: String, amount: int) -> void:
	var entry := _day_stock(settlement)
	if entry.has(id):
		entry[id] = maxi(int(entry[id]) - amount, 0)
	_flags()["purchases"] = _purchases() + amount
	_add_loyalty(_balls_in(id, amount))
	AudioBus.play_jingle("me_item")
	_companion_reacts(id)
	_roulette_spin()


## Precio del día de un recolectable (±30 %, fijo por día y objeto): se ve en el tablón.
func collectible_price(id: String) -> int:
	var base := maxi(int(Items.get_item(id).get("price", 100)) / 2, 20)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([id, GameState.game_day(), GameState.world_seed])
	return int(base * rng.randf_range(0.7, 1.3))


## Oferta del día: un id del surtido con 20 % de descuento, rotativo por día.
func daily_offer(settlement: Dictionary) -> String:
	var options := GENERAL_SHELVES + CITY_SHELVES
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([settlement.get("name", ""), GameState.game_day(), GameState.world_seed]) ^ 0x0ffe12
	return options[rng.randi() % options.size()]


# --- Estantes individuales (al acercarte dice qué es y su precio) ---------------------

## Pone el ícono flotante del objeto y el punto de interacción del estante, en la sala
## actual (ground floor o segundo piso, según el local que le pasen).
func place_shelf(local: Vector3, settlement: Dictionary, id: String) -> void:
	if not Items.exists(id):
		return
	var interiors := services.interiors
	interiors.room_marker(local + Vector3(0, 1.3, 0), Items.icon(id), 0.5)
	interiors.room_point(local, "%s ($%d)" % [Items.display_name(id), int(Items.get_item(id).get("price", 0))], inspect_shelf.bind(settlement, id), 1.7)


## Abre una ventanita con el objeto del estante: nombre, descripción, precio y un botón
## para comprarlo ahí mismo (en píldora, con su ícono).
func inspect_shelf(settlement: Dictionary, id: String) -> void:
	var layer := services.main().get_node_or_null("MenuLayer") as CanvasLayer
	if layer == null or layer.has_node("ShelfPopup"):
		return
	var popup := ShelfPopupUI.new()
	popup.name = "ShelfPopup"
	popup.item_id = id
	popup.price = int(Items.get_item(id).get("price", 0) * (0.8 if id == daily_offer(settlement) else 1.0))
	popup.left_today = remaining(settlement, id)
	popup.on_buy = func(amount: int) -> bool:
		if not buy_from_shelf(settlement, id, amount):
			return false
		return true
	layer.add_child(popup)
	popup.open()


func buy_from_shelf(settlement: Dictionary, id: String, amount: int) -> bool:
	if remaining(settlement, id) < amount:
		return false
	var factor := 0.8 if id == daily_offer(settlement) else 1.0
	if not ShopUI.buy(id, amount, factor):
		return false
	_on_bought(settlement, id, amount)
	return true


## El compañero reacciona a los estantes y a veces "pide" algo: si compraste lo que
## quería, sube un poco el vínculo.
func _companion_reacts(id: String) -> void:
	var companion := services.companion()
	if companion == null or not companion.visible or GameState.party.is_empty():
		return
	if _rng.randf() > 0.35:
		return
	SpeechBubbles.say(companion, "¡%s le gustó!" % Items.display_name(id), 2.2)
	var entry: Dictionary = GameState.party[GameState.companion_index]
	entry["bond_xp"] = float(entry.get("bond_xp", 0.0)) + 4.0


# --- Tablón de anuncios -----------------------------------------------------------------

## Rumores, brotes, ofertas y una petición de un vecino (misión corta): se lee en la
## caja de diálogo. Resolver la petición da dinero y un objeto.
func open_board(settlement: Dictionary) -> void:
	var lines: Array[String] = []
	lines.append("Oferta del día: %s con 20%% de descuento." % Items.display_name(daily_offer(settlement)))
	lines.append(_board_rumor(settlement))
	var brote := _board_outbreak()
	if brote != "":
		lines.append(brote)
	var season_line := seasonal_announcement()
	if season_line != "":
		lines.append(season_line)
	var request := request_for(settlement)
	var request_line: String
	if request.get("done", false):
		request_line = "Petición de %s: ya la cumpliste hoy. ¡Gracias!" % request["name"]
	else:
		request_line = "Petición de %s: %d × %s a cambio de $%d y %s." % [request["name"], request["amount"], Items.display_name(request["item"]), request["reward_money"], Items.display_name(request["reward_item"])]
	lines.append(request_line)
	var dialog := _dialog()
	if dialog == null:
		for line in lines:
			GameState.notice.emit(line)
		return
	if request.get("done", false):
		dialog.open("Tablón de anuncios", lines)
		return
	dialog.open("Tablón de anuncios", lines, null, ["Cumplir la petición", "Nada por ahora"], func(choice: int) -> void:
		if choice == 0:
			fulfill_request(settlement))


func _board_rumor(settlement: Dictionary) -> String:
	var rumors := [
		"Rumor: vieron una horda cerca de %s." % settlement.get("name", "aquí"),
		"Rumor: un comerciante viajero trae objetos raros por los caminos.",
		"Rumor: en las cuevas hay salidas que llevan muy lejos.",
		"Rumor: el clima va a cambiar pronto por esta zona.",
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([settlement.get("name", ""), GameState.game_day()]) ^ 0x51a
	return rumors[rng.randi() % rumors.size()]


func _board_outbreak() -> String:
	var events: Dictionary = GameState.world_flags.get("events", {})
	if not events.has("migration_next"):
		return ""
	var days := int(events["migration_next"]) - GameState.game_day()
	if days < 0 or days > 3:
		return ""
	return "Brote: se espera una bandada en %d día(s)." % maxi(days, 0)


## Eventos de temporada (decoración y rebajas avisadas por el Rotom): al cambiar de
## estación, un aviso una sola vez; mientras dura, hay un 15 % de descuento general.
func seasonal_discount() -> float:
	return 0.85 if _in_season_event() else 1.0


func _in_season_event() -> bool:
	return GameState.game_day() % Weather.SEASON_DAYS < 3


func seasonal_announcement() -> String:
	if not _in_season_event():
		return ""
	var key := "season_notice:%d" % Weather.season(GameState.game_day())
	if _flags().get(key, false):
		return ""
	_flags()[key] = true
	return "📱 Rotom: ¡Llegaron la decoración y las rebajas de %s a la Tienda!" % Weather.season_name(GameState.game_day())


# --- Petición del tablón (misión corta) -------------------------------------------------

func request_for(settlement: Dictionary) -> Dictionary:
	var names := ["un vecino", "la familia de la esquina", "el jardinero", "una viajera"]
	var items := ["oran-berry", "pecha-berry", "honey", "poke-ball", "sitrus-berry"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([settlement.get("name", ""), GameState.game_day()]) ^ 0x7e9
	var item: String = items[rng.randi() % items.size()]
	var key := "request:%s:%d" % [settlement.get("name", ""), GameState.game_day()]
	return {"name": names[rng.randi() % names.size()], "item": item, "amount": rng.randi_range(2, 4),
			"reward_money": 300 + rng.randi_range(0, 4) * 100, "reward_item": "rare-candy" if rng.randf() < 0.3 else "nugget",
			"done": _flags().get(key, false), "key": key}


func fulfill_request(settlement: Dictionary) -> void:
	var request := request_for(settlement)
	if request["done"]:
		return
	if GameState.item_count(request["item"]) < int(request["amount"]):
		GameState.notice.emit("Todavía no tienes %d × %s." % [request["amount"], Items.display_name(request["item"])])
		return
	GameState.use_item(request["item"], request["amount"])
	GameState.add_money(request["reward_money"], "Petición del tablón")
	GameState.add_item(request["reward_item"], 1)
	_flags()[request["key"]] = true
	GameState.notice.emit("¡Gracias! %s te da $%d y %s." % [request["name"].capitalize(), request["reward_money"], Items.display_name(request["reward_item"])])


# --- Niño que regala o intercambia una vez al día ---------------------------------------

const KID_GIFTS := ["oran-berry", "poke-doll", "honey", "potion"]
## Intercambios fijos (lo que pide -> lo que da), para que siempre tenga sentido.
const KID_TRADES := [["sitrus-berry", "lucky-egg"], ["nugget", "star-piece"], ["big-pearl", "rare-candy"]]


func kid_corner(settlement: Dictionary) -> void:
	var key := "kid:%s:%d" % [settlement.get("name", ""), GameState.game_day()]
	var dialog := _dialog()
	if _flags().get(key, false):
		if dialog != null:
			dialog.open("Niño", ["Ya jugué contigo hoy. ¡Vuelve mañana!"], NpcLooks.portrait("nino"))
		else:
			GameState.notice.emit("Niño: ya jugué contigo hoy. ¡Vuelve mañana!")
		return
	var trade: Array = KID_TRADES[_rng.randi() % KID_TRADES.size()]
	var can_trade := Items.exists(trade[0]) and Items.exists(trade[1]) and GameState.item_count(trade[0]) > 0
	if dialog == null:
		_flags()[key] = true
		GameState.add_item(KID_GIFTS[_rng.randi() % KID_GIFTS.size()], 1)
		GameState.notice.emit("Niño: ¡toma, es un regalo!")
		return
	var options: Array[String] = ["Acepta el regalo"]
	if can_trade:
		options.append("Intercambia %s por %s" % [Items.display_name(trade[0]), Items.display_name(trade[1])])
	options.append("Ahora no")
	dialog.open("Niño", ["¡Hola! Hoy solo puedo jugar con una persona. ¿Quieres un regalo o prefieres intercambiar?"], NpcLooks.portrait("nino"), options, func(choice: int) -> void:
		if choice == 0:
			_flags()[key] = true
			var gift: String = KID_GIFTS[_rng.randi() % KID_GIFTS.size()]
			GameState.add_item(gift, 1)
			GameState.notice.emit("Niño: ¡toma, es un regalo! (%s)" % Items.display_name(gift))
		elif choice == 1 and can_trade:
			_flags()[key] = true
			GameState.use_item(trade[0], 1)
			GameState.add_item(trade[1], 1)
			GameState.notice.emit("Niño: ¡trato hecho! Te doy %s." % Items.display_name(trade[1])))


# --- Pedidos por encargo (1-2 días, aviso del Rotom) ------------------------------------

func open_orders(settlement: Dictionary) -> void:
	_check_orders()
	var dialog := _dialog()
	var pending: Array = _flags().get("orders", [])
	var lines: Array[String] = []
	if pending.is_empty():
		lines.append("No tienes pedidos por encargo. Puedo traerte algo especial en 1 o 2 días.")
	else:
		for order: Dictionary in pending:
			lines.append("Pedido de %s: llega en %d día(s)." % [Items.display_name(order["item"]), maxi(int(order["day"]) - GameState.game_day(), 0)])
	if dialog == null:
		for line in lines:
			GameState.notice.emit(line)
		return
	var options: Array[String] = []
	for id: String in ORDER_CATALOG:
		options.append("Encargar %s ($%d)" % [Items.display_name(id), int(Items.get_item(id).get("price", 0) * ORDER_PREMIUM)])
	options.append("Nada por ahora")
	dialog.open("Dependiente", lines, NpcLooks.portrait("dependiente"), options, func(choice: int) -> void:
		if choice >= 0 and choice < ORDER_CATALOG.size():
			_place_order(ORDER_CATALOG[choice]))


func _place_order(id: String) -> void:
	var cost := int(Items.get_item(id).get("price", 0) * ORDER_PREMIUM)
	if GameState.money < cost:
		GameState.notice.emit("Ese pedido cuesta $%d." % cost)
		return
	GameState.add_money(-cost, "Pedido por encargo: %s" % Items.display_name(id))
	var orders: Array = _flags().get("orders", [])
	orders.append({"item": id, "day": GameState.game_day() + _rng.randi_range(1, 2)})
	_flags()["orders"] = orders
	GameState.notice.emit("Pedido hecho. El Rotom te avisará cuando llegue %s." % Items.display_name(id))


## Revisa si ya llegó algún pedido (al entrar a la tienda): lo entrega y avisa.
func _check_orders() -> void:
	var orders: Array = _flags().get("orders", [])
	var left: Array = []
	for order: Dictionary in orders:
		if int(order["day"]) <= GameState.game_day():
			GameState.add_item(order["item"], 1)
			AudioBus.play_jingle("me_item")
			GameState.notice.emit("📱 Rotom: ¡tu pedido de %s ya llegó a la tienda!" % Items.display_name(order["item"]))
		else:
			left.append(order)
	_flags()["orders"] = left


# --- Máquina de bebidas ------------------------------------------------------------------

func drink_machine() -> void:
	if GameState.money < DRINK_PRICE:
		GameState.notice.emit("La máquina cuesta $%d." % DRINK_PRICE)
		return
	GameState.add_money(-DRINK_PRICE, "Máquina de bebidas")
	var drink: String = DRINKS[_rng.randi() % DRINKS.size()]
	var amount := 2 if _rng.randf() < 0.15 else 1
	GameState.add_item(drink, amount)
	GameState.feed(2.0 * amount)
	var companion := services.companion()
	if companion != null and GameState.party.size() > 0:
		var entry: Dictionary = GameState.party[GameState.companion_index]
		entry["bond_xp"] = float(entry.get("bond_xp", 0.0)) + 2.0
	AudioBus.play_sfx("ui_decide")
	GameState.notice.emit(("¡La máquina soltó dos! " if amount == 2 else "") + "Conseguiste %s. Ya no tienes tanta hambre." % Items.display_name(drink))


# --- Ruleta diaria (con cualquier compra) ------------------------------------------------

func _roulette_spin() -> void:
	var key := "roulette:%d" % GameState.game_day()
	if _flags().get(key, false):
		return
	_flags()[key] = true
	var prize: String = ROULETTE_PRIZES[_rng.randi() % ROULETTE_PRIZES.size()]
	GameState.add_item(prize, 1)
	AudioBus.play_jingle("me_item")
	GameState.notice.emit("🎡 ¡La ruleta diaria te regala %s!" % Items.display_name(prize))


# --- Mostrador de regalos -----------------------------------------------------------------

func gift_counter() -> void:
	var dialog := _dialog()
	var options: Array = GIFT_LIKES.keys()
	options.append("Cancelar")
	if dialog == null:
		GameState.notice.emit("Mostrador de regalos: elige a quién regalarle desde el menú de Mochila.")
		return
	dialog.open("Mostrador de regalos", ["¿A quién quieres hacerle un regalo?"], null, options, func(choice: int) -> void:
		if choice >= 0 and choice < GIFT_LIKES.size():
			_offer_gift(options[choice]))


func _offer_gift(who: String) -> void:
	var likes: Array = GIFT_LIKES[who]
	var have := likes.filter(func(id: String) -> bool: return GameState.item_count(id) > 0)
	var dialog := _dialog()
	if have.is_empty():
		var text := "A %s le gustaría algo como %s, pero no traes nada así." % [who, Items.display_name(likes[0])]
		if dialog != null:
			dialog.open("Mostrador de regalos", [text])
		else:
			GameState.notice.emit(text)
		return
	var gift: String = have[0]
	GameState.use_item(gift, 1)
	for group: String in GameState.reputation:
		GameState.reputation[group] = mini(int(GameState.reputation[group]) + 3, 100)
	AudioBus.play_jingle("me_item")
	var text := "¡A %s le encantó tu %s!" % [who, Items.display_name(gift)]
	if dialog != null:
		dialog.open("Mostrador de regalos", [text])
	else:
		GameState.notice.emit(text)


# --- Ladrón ocasional del equipo villano --------------------------------------------------

func maybe_spawn_thief(settlement: Dictionary, root: Node3D, shelf_at: Vector3, door_at: Vector3) -> void:
	var key := "thief:%d" % GameState.game_day()
	if not _thief.is_empty() or _flags().get(key, false):
		return
	if _rng.randf() > THIEF_CHANCE:
		return
	_flags()[key] = true
	var node := services.interiors.room_npc(shelf_at, "obrero_a")
	node.modulate = Color(0.55, 0.55, 0.85)
	_thief = {"node": node, "elapsed": 0.0, "door": Interiors.ORIGIN + door_at, "settlement": settlement}
	GameState.notice.emit("¡Un ladrón del %s está vaciando un estante! Atrápalo antes de que llegue a la puerta." % GameState.villain_team)


func _process(delta: float) -> void:
	if services.interiors.is_inside() and services.interiors.current.get("kind", "") == "mart":
		_customer_timer -= delta
		if _customer_timer <= 0.0:
			_customer_timer = _rng.randf_range(25.0, 45.0)
			_customer_buys(services.interiors.current.get("settlement", {}))
	if _thief.is_empty():
		return
	# Puede haberse liberado al salir del interior: se revisa antes de tiparlo.
	var maybe: Variant = _thief.get("node")
	if not is_instance_valid(maybe):
		_thief = {}
		return
	var node := maybe as Node3D
	var player := services.player()
	if player == null:
		return
	_thief["elapsed"] = float(_thief["elapsed"]) + delta
	var to_door: Vector3 = (_thief["door"] as Vector3) - node.global_position
	if player.global_position.distance_to(node.global_position) <= THIEF_CATCH_RADIUS:
		_catch_thief()
		return
	if float(_thief["elapsed"]) >= THIEF_ESCAPE_SECONDS or to_door.length() < 0.6:
		node.queue_free()
		GameState.notice.emit("El ladrón escapó con lo que alcanzó a robar. Quizá vuelva otro día.")
		_thief = {}
		return
	node.global_position += to_door.normalized() * delta * 1.6


## Lo alcanzaste: ahora "gánale" con un combate corto (un solo Pokémon Siniestro o
## Veneno del equipo villano, igual que su base secreta); al vencerlo, la recompensa.
func _catch_thief() -> void:
	var node: Node3D = _thief["node"]
	var settlement: Dictionary = _thief["settlement"]
	_thief = {}
	if is_instance_valid(node):
		node.queue_free()
	var player := services.player()
	if player == null:
		return
	var types := [PokemonTypes.Type.DARK, PokemonTypes.Type.POISON]
	var pool: Array[SpeciesData] = []
	for species: SpeciesData in WildSpawner.ALL_SPECIES.species:
		if species.types.has(types[_rng.randi() % types.size()]) and not species.is_legendary and not species.is_mythical:
			pool.append(species)
	if pool.is_empty():
		_reward_thief(settlement)
		return
	var species: SpeciesData = pool[_rng.randi() % pool.size()]
	var actor := services.spawn_wild(species, player.global_position + Vector3(0, 0, 1.6))
	if actor == null:
		_reward_thief(settlement)
		return
	actor.set_meta("trainer", true)
	actor.add_to_group(&"trainer_pokemon")
	(services.interiors.current.get("actors", []) as Array).append(actor)
	AudioBus.play_sfx("spotted")
	GameState.notice.emit("¡Lo alcanzaste! El ladrón del %s saca a %s." % [GameState.villain_team, species.display_name])
	actor.stunned.connect(_on_thief_stunned.bind(settlement), CONNECT_ONE_SHOT)
	var target: Node3D = services.companion() if services.companion() != null and services.companion().visible else player
	actor.start_fight.call_deferred(target)


func _on_thief_stunned(actor: PokemonActor, settlement: Dictionary) -> void:
	PixelBurst.spawn(actor.get_parent(), actor.global_position, PixelBurst.Kind.HEAL, 0.6)
	actor.queue_free()
	_reward_thief(settlement)


func _reward_thief(settlement: Dictionary) -> void:
	AudioBus.play_sfx("caught")
	var reward_money := 300 + _rng.randi_range(0, 5) * 100
	GameState.add_money(reward_money, "Recompensa: ladrón atrapado")
	GameState.add_item("rare-candy", 1)
	GameState.add_news("¡%s atrapó a un ladrón del %s en la Tienda de %s!" % [GameState.player_name, GameState.villain_team, settlement.get("name", "")])
	GameState.notice.emit("¡Le ganaste! Recompensa: $%d y un Caramelo Raro." % reward_money)


# --- Ambiente (ruido de gente) y sonido de la tienda --------------------------------------

func start_ambient(root: Node3D) -> void:
	stop_ambient()
	var player := AudioBus.ambient_player("amb_mart_crowd")
	if player == null:
		return
	_ambient = player
	root.add_child(player)
	player.play()


func stop_ambient() -> void:
	if _ambient != null and is_instance_valid(_ambient):
		_ambient.queue_free()
	_ambient = null
