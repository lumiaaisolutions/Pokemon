class_name MusicDirector
extends Node
## Elige la música según dónde estás (estilo BW/BW2), cada medio segundo:
## 1. Combate en arena: salvaje, fuerte (Alfa o dominante), legendario o entrenador.
## 2. Interiores: Centro Pokémon, laboratorio, gimnasio, Liga, alcantarillas, cuevas,
##    minas, torre, mansión, central, base criminal, distorsión, barco hundido…
## 3. Montado: surf, bicicleta o volando.
## 4. Pueblos y ciudades: cada asentamiento tiene su tema fijo (por tipo y bioma).
## 5. Lugares especiales cercanos (ruinas, gruta, rancho, volcán…).
## 6. Rutas por bioma y estación (Ruta 19, 2, 6, 4, 22, 12, 10, 23, Bosque Perdido…).

const STATIC_TOWN := {"city": ["bw1_city_castelia", "bw1_city_nimbasa", "bw1_city_driftveil", "bw1_city_mistralton", "bw1_city_opelucid", "bw2_city_virbank"],
		"town": ["bw2_town_aspertia", "bw1_town_accumula", "bw1_city_striaton", "bw1_city_nacrene", "bw2_town_floccesy"],
		"village": ["bw1_village_lacunosa", "bw1_village_anville", "bw2_town_floccesy"],
		"cabins": ["bw2_town_floccesy", "bw1_village_anville"]}
const INTERIOR := {"center": "bw1_pokecenter", "mart": "bw2_pokemart", "lab": "bw1_lab", "gym": "bw1_gym", "league": "bw1_league",
		"contest": "bw1_city_nimbasa", "sewer": "bw2_sewers", "cave": "bw1_cave_chargestone", "mine": "bw2_underground_ruins",
		"tower": "bw1_tower_dragonspiral", "mansion": "bw2_strange_house", "power_plant": "bw2_plasma_frigate", "lab_ruins": "bw2_black_tower",
		"villain_base": "bw1_villain_base", "distortion": "bw2_white_treehollow", "shipwreck": "bw1_undersea", "victory_road": "bw1_victory_road"}
const PLACES := {"ruins": "bw1_ruins_relic", "grotto": "bw2_grotto", "ranch": "bw2_ranch", "berry_farm": "bw2_ranch", "volcano": "bw2_reversal_mountain",
		"floating_ruins": "bw2_black_tower", "giant_tree": "bw1_forest_white", "sanctuary": "bw1_n_castle", "league": "bw1_victory_road",
		"safari": "bw1_route10", "oasis": "bw1_route4_summer", "hot_spring": "bw2_reversal_mountain"}

@export var main_path: NodePath = NodePath("..")

var _main: Node
var _timer := 0.0


func _ready() -> void:
	_main = get_node(main_path)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	AudioBus.play_music(pick())


## Pista que toca ahora.
func pick() -> String:
	var player := _main.get_node_or_null("Player") as Player
	var world := _main.get_node_or_null("World") as WorldBuilder
	if player == null or world == null:
		return ""
	# 1. Combate.
	var battle := _main.get_node_or_null("Battle") as BattleManager
	if battle != null and battle.active and battle.opponent != null and is_instance_valid(battle.opponent):
		var opponent := battle.opponent
		if not battle.trainer.is_empty():
			return "bw2_battle_trainer2" if absi(hash(String(battle.trainer.get("id", "")))) % 2 == 0 else "bw1_battle_trainer"
		if opponent.legendary:
			return "bw1_battle_legendary"
		if opponent.has_meta("Alfa") or opponent.has_meta("dominante"):
			return "bw1_battle_strong"
		return "bw2_battle_wild2" if absi(hash(opponent.species.identifier)) % 2 == 0 else "bw1_battle_wild"
	var services := world.structures.services if world.structures != null else null
	if services != null and services.trial_active():
		var interior: String = services.interiors.current.get("kind", "") if services.interiors.is_inside() else ""
		return {"gym": "bw2_battle_gym2", "league": "bw1_battle_elite", "villain_base": "bw2_battle_plasma2"}.get(interior, "bw2_battle_trainer2")
	# 2. Interiores.
	if services != null and services.interiors.is_inside():
		var kind: String = services.interiors.current.get("kind", "")
		if kind in ["house", "cabin"]:
			return _town_track(services.interiors.current.get("settlement", {}), world)
		return INTERIOR.get(kind, "bw1_pokecenter")
	var pos := player.global_position
	# 3. Montado o nadando.
	if player.riding != null or (player.mode == Player.Mode.SWIM and world.region_biome_at(pos.x, pos.z) == RegionLayout.Biome.SEA):
		return "bw1_surf"
	if player.ride == Player.Ride.BIKE:
		return "bw1_bicycle"
	if player.ride == Player.Ride.FLY:
		return "bw1_bridge"
	# 4. Pueblos.
	var settlement := world.settlement_at(pos.x, pos.z, 20.0)
	if not settlement.is_empty() and settlement.get("kind", "") != "sanctuary":
		return _town_track(settlement, world)
	# 5. Lugares especiales.
	if world.structures != null:
		var place := world.structures.place_at(pos.x, pos.z, 40.0)
		if not place.is_empty() and PLACES.has(place["kind"]):
			return PLACES[place["kind"]]
	# 6. Rutas por bioma y estación.
	return _route_track(world.region_biome_at(pos.x, pos.z), Weather.season(GameState.game_day()))


func _town_track(settlement: Dictionary, world: WorldBuilder) -> String:
	if settlement.is_empty():
		return "bw1_pokecenter"
	var settlements := world.layout.settlements
	if not settlements.is_empty() and settlement.get("name", "") == settlements[0].get("name", ""):
		return "bw1_town_start"
	var biome: int = settlement.get("biome", 0)
	match biome:
		RegionLayout.Biome.TUNDRA:
			return "bw1_city_icirrus"
		RegionLayout.Biome.BEACH:
			return "bw2_city_humilau" if settlement.get("kind", "") == "city" else ("bw1_village_undella_summer" if Weather.season(GameState.game_day()) == 1 else "bw1_village_undella")
		RegionLayout.Biome.DESERT, RegionLayout.Biome.VOLCANO, RegionLayout.Biome.CANYON:
			return "bw2_village_lentimas"
	var list: Array = STATIC_TOWN.get(settlement.get("kind", "town"), STATIC_TOWN["town"])
	return list[absi(hash(String(settlement.get("name", "")))) % list.size()]


static func _route_track(biome: int, season: int) -> String:
	var spring := season <= 1
	match biome:
		RegionLayout.Biome.MEADOW, RegionLayout.Biome.FLOWERS:
			return ["bw2_route19_spring", "bw2_route19_summer", "bw2_route19_autumn", "bw2_route19_winter"][season]
		RegionLayout.Biome.SAVANNA:
			return "bw1_route2_spring" if spring else "bw1_route2_autumn"
		RegionLayout.Biome.FOREST, RegionLayout.Biome.JUNGLE:
			return "bw1_route6_spring" if spring else "bw1_route6_autumn"
		RegionLayout.Biome.DARK_FOREST, RegionLayout.Biome.MUSHROOM, RegionLayout.Biome.SWAMP, RegionLayout.Biome.TOXIC_SWAMP:
			return "bw1_forest_lostlorn"
		RegionLayout.Biome.DESERT, RegionLayout.Biome.CANYON, RegionLayout.Biome.MESA:
			return ["bw1_route4_spring", "bw1_route4_summer", "bw1_route4_autumn", "bw1_route4_winter"][season]
		RegionLayout.Biome.MOUNTAIN:
			return "bw2_route23"
		RegionLayout.Biome.TUNDRA:
			return "bw1_route12_autumn"
		RegionLayout.Biome.VOLCANO:
			return "bw2_reversal_mountain"
		RegionLayout.Biome.BEACH, RegionLayout.Biome.SEA:
			return "bw2_route22_spring" if spring else "bw2_route22_autumn"
	return "bw1_route1"
