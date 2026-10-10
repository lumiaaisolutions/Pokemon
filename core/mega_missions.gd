class_name MegaMissions
extends RefCounted
## Misiones de megapiedras (Fase 5.5), avisadas en el Rotom Móvil. Cuando en tu equipo
## hay un Pokémon que puede megaevolucionar (o su línea evolutiva llega a uno), se abre
## una misión de esa especie; al cumplirla recibes su megapiedra. Tres tipos (fijo por
## especie): capturar 2 más, completar su investigación o vencer a su Alfa o dominante
## en combate. La Piedra Llave sale del primer acertijo de ruinas resuelto.

const KINDS := ["catch", "research", "alpha"]
const CATCH_TARGET := 2
const FLAG := "mega_mission:"


static func _flags() -> Dictionary:
	return GameState.world_flags


## Especies que un Pokémon puede llegar a ser (él y sus evoluciones, 2 pasos).
static func _line(identifier: String) -> Array[String]:
	var result: Array[String] = [identifier]
	for option: Dictionary in Evolution.options(identifier):
		result.append(option["to"])
		for next: Dictionary in Evolution.options(option["to"]):
			result.append(next["to"])
	return result


static func kind_for(species: String) -> String:
	return KINDS[absi(hash(species)) % KINDS.size()]


## Misiones activas y cumplidas: [{mega, species, kind, start, done}].
static func all() -> Array:
	var result: Array = []
	for key: String in _flags():
		if key.begins_with(FLAG):
			result.append(_flags()[key])
	return result


## Abre misiones nuevas, revisa las abiertas y entrega megapiedras. Devuelve los avisos.
static func update() -> Array[String]:
	var messages: Array[String] = []
	var catalog := MegaCatalog.load_catalog()
	if catalog == null:
		return messages
	for member: Dictionary in GameState.party:
		for species in _line(member["species"]):
			for mega in catalog.for_species(species):
				var stone := "stone-" + mega.identifier
				if not Items.exists(stone) or _flags().has(FLAG + mega.identifier):
					continue
				var kind := kind_for(species)
				_flags()[FLAG + mega.identifier] = {"mega": mega.identifier, "species": species, "kind": kind,
						"start": int(GameState.dex_entry(species).get("caught", 0)), "done": GameState.item_count(stone) > 0}
				if GameState.item_count(stone) <= 0:
					var text := "Misión de megapiedra: %s" % describe(_flags()[FLAG + mega.identifier])
					GameState.add_news(text)
					messages.append("Rotom: ¡nueva %s!" % text.to_lower())
	for mission: Dictionary in all():
		if mission.get("done", false) or not _complete(mission):
			continue
		mission["done"] = true
		var stone := "stone-" + String(mission["mega"])
		GameState.add_item(stone, 1)
		Achievements.add("mega_stones")
		AudioBus.play_jingle("me_mission_clear")
		var text := "¡Misión cumplida! Recibiste %s." % Items.display_name(stone)
		GameState.add_news(text)
		messages.append(text + ("" if GameState.item_count("key-stone") > 0 else " Te falta la Piedra Llave: dicen que duerme en unas Ruinas Antiguas."))
	return messages


static func _complete(mission: Dictionary) -> bool:
	var species := String(mission["species"])
	match String(mission["kind"]):
		"catch":
			return progress(mission) >= CATCH_TARGET
		"research":
			return Research.is_complete(species)
		"alpha":
			return _flags().get("alpha_beaten:" + species, false)
	return false


static func progress(mission: Dictionary) -> int:
	match String(mission["kind"]):
		"catch":
			return mini(int(GameState.dex_entry(String(mission["species"])).get("caught", 0)) - int(mission["start"]), CATCH_TARGET)
		"research":
			return Research.points(String(mission["species"]))
		"alpha":
			return 1 if _flags().get("alpha_beaten:" + String(mission["species"]), false) else 0
	return 0


static func describe(mission: Dictionary) -> String:
	var species := MenuStyle.species(String(mission["species"]))
	var name := species.display_name if species != null else String(mission["species"])
	var stone := Items.display_name("stone-" + String(mission["mega"]))
	match String(mission["kind"]):
		"catch":
			return "%s · captura %d %s más (%d/%d)" % [stone, CATCH_TARGET, name, maxi(progress(mission), 0), CATCH_TARGET]
		"research":
			return "%s · completa la investigación de %s (%d/%d)" % [stone, name, mini(progress(mission), Research.COMPLETE_POINTS), Research.COMPLETE_POINTS]
		_:
			return "%s · vence en combate a un %s Alfa o dominante" % [stone, name]
