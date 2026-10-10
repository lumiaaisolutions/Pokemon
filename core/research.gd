class_name Research
extends RefCounted
## Investigación de la Pokédex (estilo Leyendas Arceus): tareas por especie con metas;
## cada meta cumplida da 10 puntos. Nivel = puntos / 10 (máx. 10); con 100 puntos la
## especie queda "completada". El profesor premia al completar o capturar especies.

## [clave del contador en GameState.dex, texto, metas]
const TASKS := [
	["seen", "Encuentros", [1, 5, 10, 20]],
	["caught", "Capturas", [1, 2, 3, 5, 10]],
	["behind", "Capturas por la espalda", [1, 3, 5]],
	["fights", "Verlo pelear con otro salvaje", [1, 3]],
	["stunned", "Verlo debilitado en una pelea", [1, 3, 5]],
	["battles", "Vencerlo en combate", [1, 3]],
	["photos", "Fotografiarlo", [1, 3]],
]
const POINTS_PER_GOAL := 10
const COMPLETE_POINTS := 100
## Premios del profesor por especies capturadas: [cantidad, objeto, unidades, texto].
const REWARDS := [
	[1, "great-ball", 5, "¡Tu primera captura! Ten estas Super Balls."],
	[5, "potion", 5, "5 especies capturadas: aquí tienes Pociones."],
	[10, "ultra-ball", 5, "10 especies: Ultra Balls para los difíciles."],
	[25, "rare-candy", 3, "25 especies: Caramelos Raros para entrenar."],
	[50, "master-ball", 1, "50 especies: ¡una Master Ball!"],
	[100, "lucky-egg", 3, "100 especies: Huevos Suerte para buscar shinies."],
	[400, "shiny-charm", 1, "¡400 especies! El Amuleto Iris: más shinies (×3)."],
]


static func points(identifier: String) -> int:
	if not GameState.dex.has(identifier):
		return 0
	var entry: Dictionary = GameState.dex[identifier]
	var total := 0
	for task: Array in TASKS:
		for goal: int in task[2]:
			if int(entry.get(task[0], 0)) >= goal:
				total += POINTS_PER_GOAL
	return total


static func level(identifier: String) -> int:
	return mini(points(identifier) / 10, 10)


static func is_complete(identifier: String) -> bool:
	return points(identifier) >= COMPLETE_POINTS


## Siguiente meta de la tarea (o -1 si ya cumplió todas).
static func next_goal(identifier: String, task: Array) -> int:
	var value := int(GameState.dex.get(identifier, {}).get(task[0], 0))
	for goal: int in task[2]:
		if value < goal:
			return goal
	return -1


## Entrega los premios pendientes; devuelve los textos de los nuevos.
static func claim_rewards() -> Array[String]:
	var caught := 0
	for id: String in GameState.dex:
		caught += 1 if int(GameState.dex[id].get("caught", 0)) > 0 else 0
	var messages: Array[String] = []
	for reward: Array in REWARDS:
		var key := "dex_%d" % reward[0]
		if caught >= int(reward[0]) and not GameState.rewards_claimed.get(key, false):
			GameState.rewards_claimed[key] = true
			GameState.add_item(reward[1], reward[2])
			messages.append("Profesor: %s (%s × %d)" % [reward[3], Items.display_name(reward[1]), reward[2]])
	return messages
