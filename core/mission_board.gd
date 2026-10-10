class_name MissionBoard
extends RefCounted
## Todas las misiones del jugador en un solo lugar (tablero, acordado con Fernando el
## 2026-10-10): actividades del Rotom, misiones de megapiedra, la foto del día, los
## héroes con rumor y la investigación más avanzada. Cada misión:
## {category, title, detail, progress (0–1), reward, icon}.

const CATEGORIES := {
	"rotom": ["Rotom", Color(0.95, 0.5, 0.2), "Rotom"],
	"mega": ["Megapiedras", Color(0.85, 0.45, 0.85), "Pokémon"],
	"photo": ["Foto del día", Color(0.35, 0.55, 0.95), "Mapa"],
	"hero": ["Héroes", Color(0.95, 0.75, 0.15), "Logros"],
	"research": ["Investigación", Color(0.2, 0.65, 0.75), "Pokédex"],
}


static func collect(tree: SceneTree) -> Array:
	var result: Array = []
	for activity: Dictionary in GameState.activities:
		if activity.get("done", false) or activity.get("failed", false):
			continue
		var target := maxf(float(activity["target"]), 1.0)
		var days := int(activity["deadline_day"]) - GameState.game_day()
		result.append({"category": "rotom", "title": activity["title"], "progress": float(activity["progress"]) / target,
				"detail": "%d / %d · quedan %d días" % [int(activity["progress"]), int(target), maxi(days, 0)],
				"reward": "$%d y %s × %d" % [int(activity["money"]), Items.display_name(activity["item"]), int(activity["item_amount"])]})
	for mission: Dictionary in MegaMissions.all():
		if mission.get("done", false):
			continue
		var goal := float(MegaMissions.CATCH_TARGET if mission["kind"] == "catch" else (Research.COMPLETE_POINTS if mission["kind"] == "research" else 1))
		result.append({"category": "mega", "title": MegaMissions.describe(mission), "progress": clampf(MegaMissions.progress(mission) / goal, 0.0, 1.0),
				"detail": "Misión de megapiedra", "reward": Items.display_name("stone-" + String(mission["mega"]))})
	var photo := tree.get_first_node_in_group(&"photo_mode") as PhotoMode
	if photo != null:
		var current := photo.mission()
		if not current.is_empty() and not current.get("done", false):
			result.append({"category": "photo", "title": "Fotografía a un %s" % MenuStyle.species(current["species"]).display_name,
					"progress": 0.0, "detail": "Tecla %s para la cámara" % InputHints.hint("photo"), "reward": "$%d y un objeto" % PhotoMode.REWARD_MONEY})
	var heroes := tree.get_first_node_in_group(&"heroes") as Heroes
	if heroes != null:
		for id: String in heroes.rumored_today():
			if heroes.beaten_today(id):
				continue
			var spot := heroes.location(id)
			result.append({"category": "hero", "title": "Reta a %s" % PlayerCharacters.find(id)["name"], "progress": 0.0,
					"detail": "Rumor: cerca de %s (8:00–20:00)" % spot.get("name", "?"), "reward": "Dinero y un objeto raro"})
	# Investigación: las 3 especies más cerca de completarse.
	var research: Array = []
	for id: String in GameState.dex:
		var points := Research.points(id)
		if points > 0 and points < Research.COMPLETE_POINTS:
			research.append([id, points])
	research.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	for pair: Array in research.slice(0, 3):
		var species := MenuStyle.species(pair[0])
		if species != null:
			result.append({"category": "research", "title": "Completa la investigación de %s" % species.display_name,
					"progress": float(pair[1]) / Research.COMPLETE_POINTS, "detail": "%d / %d puntos" % [int(pair[1]), Research.COMPLETE_POINTS], "reward": "Premios del profesor"})
	return result


## Las 3 del tablero en pantalla: en curso, con más avance primero.
static func top(tree: SceneTree, count: int = 3) -> Array:
	var all := collect(tree)
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["progress"]) > float(b["progress"]))
	return all.slice(0, count)
