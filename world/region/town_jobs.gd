class_name TownJobs
extends RefCounted
## Tablón de encargos del pueblo (mundo más lleno, acordado con Fernando el 2026-10-10:
## "tablones con encargos... pueblo que crece si ayudas a su gente"). Cada pueblo tiene
## 2 encargos por día del juego (fijos por semilla, pueblo y día): traer N de un objeto
## a cambio de dinero. Al cumplir GOAL encargos en un pueblo, la próxima vez que se
## construya el mundo (cargar la partida) aparece un puesto nuevo agradecido en su plaza
## (ver Structures._growth_kiosk).

const POOL := [
	{"item": "oran-berry", "count": 3, "reward": 300, "text": "Necesito %d Bayas Oran para el guiso del pueblo."},
	{"item": "potion", "count": 2, "reward": 250, "text": "¿Tienes %d Pociones? Las necesito para mi botiquín."},
	{"item": "pearl", "count": 2, "reward": 400, "text": "Busco %d Perlas para un regalo."},
	{"item": "nugget", "count": 1, "reward": 500, "text": "Cambio dinero por %d Pepita que encuentres por ahí."},
	{"item": "star-piece", "count": 1, "reward": 450, "text": "Un Trozo Estrella (×%d) para mi colección vale mucho para mí."},
	{"item": "great-ball", "count": 3, "reward": 350, "text": "Me faltan %d Súper Balls para mi viaje."},
]
## Encargos cumplidos para que el pueblo "crezca" (un puesto nuevo en la próxima carga).
const GOAL := 3


static func _state(town: String) -> Dictionary:
	var all: Dictionary = GameState.world_flags.get("town_jobs", {})
	if not all.has(town):
		all[town] = {"done": 0, "day": -1, "jobs": []}
		GameState.world_flags["town_jobs"] = all
	return all[town]


## 2 encargos del día, fijos por semilla + pueblo + día; se renuevan cada día del juego.
static func jobs_today(settlement: Dictionary) -> Array:
	var town: String = settlement["name"]
	var state := _state(town)
	var day := GameState.game_day()
	if int(state["day"]) != day:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(town) ^ (day * 7919) ^ 331
		var jobs: Array = []
		for i in 2:
			jobs.append((POOL[rng.randi() % POOL.size()] as Dictionary).duplicate())
		state["day"] = day
		state["jobs"] = jobs
	return state["jobs"]


static func help_count(settlement: Dictionary) -> int:
	return int(_state(settlement["name"])["done"])


## El pueblo ya ayudó bastante: la próxima vez que se construya el mundo tendrá un
## puesto nuevo (ver Structures.build()).
static func grown(settlement: Dictionary) -> bool:
	return help_count(settlement) >= GOAL


static func open_board(structures: Structures, settlement: Dictionary) -> void:
	var dialog := structures.get_tree().get_first_node_in_group(&"dialog_box") as DialogBox
	if dialog == null:
		return
	var jobs := jobs_today(settlement)
	var lines: Array = ["Tablón de encargos de %s:" % String(settlement["name"])]
	var options: Array[String] = []
	var valid: Array[int] = []
	for i in jobs.size():
		var job: Dictionary = jobs[i]
		var done := bool(job.get("done", false))
		lines.append("%s %s (recompensa $%d)" % ["✓" if done else "·", (String(job["text"]) % int(job["count"])), int(job["reward"])])
		if not done:
			options.append("Cumplir: %s ×%d" % [Items.display_name(String(job["item"])), int(job["count"])])
			valid.append(i)
	lines.append("Ayuda a %s: %d/%d (con %d el pueblo abre un puesto nuevo)." % [String(settlement["name"]), help_count(settlement), GOAL, GOAL])
	options.append("Nada por ahora")
	dialog.open("Tablón de encargos", lines, null, options, func(choice: int) -> void:
		if choice < 0 or choice >= valid.size():
			return
		_fulfill(settlement, valid[choice], structures))


static func _fulfill(settlement: Dictionary, index: int, structures: Structures) -> void:
	var town: String = settlement["name"]
	var state := _state(town)
	var jobs: Array = state["jobs"]
	if index < 0 or index >= jobs.size():
		return
	var job: Dictionary = jobs[index]
	if bool(job.get("done", false)):
		return
	var item: String = job["item"]
	var count: int = job["count"]
	if GameState.item_count(item) < count:
		GameState.notice.emit("Te faltan %s (tienes %d de %d)." % [Items.display_name(item), GameState.item_count(item), count])
		return
	GameState.use_item(item, count)
	GameState.add_money(int(job["reward"]), "Encargo de %s" % town)
	job["done"] = true
	var was_grown := grown(settlement)
	state["done"] = int(state["done"]) + 1
	AudioBus.play_jingle("me_item")
	GameState.notice.emit("¡Encargo cumplido! +$%d. Ayuda a %s: %d/%d." % [int(job["reward"]), town, int(state["done"]), GOAL])
	# Pueblo que crece de verdad en el momento (completar lo simplificado del mundo,
	# 2026-10-11): al llegar justo a GOAL, aparece ya mismo (sin recargar) un puesto
	# nuevo y un vecino más, con aviso; antes esperaba a la próxima carga del mundo
	# (ver Structures.build(), docs/decisiones_sin_preguntar.md).
	if not was_grown and grown(settlement):
		_grow_now(settlement, structures)


## Hace crecer al pueblo ya mismo: puesto nuevo en la plaza y un vecino más con rutina,
## sin esperar a recargar el mundo.
static func _grow_now(settlement: Dictionary, structures: Structures) -> void:
	if structures == null or not is_instance_valid(structures):
		return
	structures.spawn_growth_now(settlement)
	var npcs_raw: Variant = structures.get_tree().get_first_node_in_group(&"town_npcs")
	if is_instance_valid(npcs_raw):
		var npcs: TownNPCs = npcs_raw
		var index := structures.world.layout.settlements.find(settlement)
		if index >= 0:
			npcs.add_grown_npc(index, settlement)
	GameState.notice.emit("¡%s creció gracias a tu ayuda! Abrió un puesto nuevo en la plaza y llegó un vecino más." % String(settlement["name"]))
