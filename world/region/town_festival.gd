class_name TownFestival
extends RefCounted
## Feria del pueblo (acordado con Fernando el 2026-10-10: "ferias y festivales en un
## pueblo al azar"). Cada pueblo tiene un día fijo de la semana del juego (fijo por su
## nombre) con feria: tiro al blanco y un torneo improvisado con premio mayor (ver
## TownServices.festival_tournament). El resto de los días el puesto solo dice cuándo es.

const DAY_NAMES := ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]
const SHOOT_PRICE := 50


static func festival_weekday(settlement: Dictionary) -> int:
	return absi(hash(settlement["name"])) % 7


static func is_today(settlement: Dictionary) -> bool:
	return GameState.game_day() % 7 == festival_weekday(settlement)


static func open_booth(structures: Structures, settlement: Dictionary) -> void:
	var dialog := structures.get_tree().get_first_node_in_group(&"dialog_box") as DialogBox
	if dialog == null:
		return
	if not is_today(settlement):
		dialog.open("Feria del pueblo", ["Hoy no hay feria en %s. La próxima es el %s." % [String(settlement["name"]), DAY_NAMES[festival_weekday(settlement)]]])
		return
	dialog.open("Feria de %s" % String(settlement["name"]), ["¡Hoy es día de feria! ¿Qué quieres hacer?"], null,
			["Tiro al blanco ($%d)" % SHOOT_PRICE, "Torneo improvisado (combate)", "Nada por ahora"], func(choice: int) -> void:
		if choice == 0:
			_shooting_game(settlement)
		elif choice == 1:
			structures.services.festival_tournament(settlement))


static func _shooting_game(settlement: Dictionary) -> void:
	if GameState.money < SHOOT_PRICE:
		GameState.notice.emit("El tiro al blanco cuesta $%d." % SHOOT_PRICE)
		return
	GameState.add_money(-SHOOT_PRICE, "Feria de %s" % String(settlement["name"]))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll := rng.randf()
	if roll < 0.2:
		GameState.add_item("nugget", 1)
		AudioBus.play_jingle("me_item")
		GameState.notice.emit("¡Diste en el blanco! Ganaste una Pepita.")
	elif roll < 0.6:
		GameState.add_item("rare-candy", 1)
		AudioBus.play_jingle("me_item")
		GameState.notice.emit("¡Casi! Aun así te llevas un Caramelo Raro.")
	else:
		GameState.notice.emit("Fallaste el tiro. ¡Suerte la próxima!")
