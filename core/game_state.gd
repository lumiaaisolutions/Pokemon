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
## Pokéballs (el inventario completo llega en la Fase 5).
var pokeballs: int = 20

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
func add_caught(species: SpeciesData, shiny: bool, hp_ratio: float) -> String:
	var entry := {"species": species.identifier, "shiny": shiny, "hp_ratio": hp_ratio}
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
	money -= lost
	return lost


## Valor de la dificultad actual ("damage", "money_loss" o "recovery").
func difficulty_value(key: String) -> float:
	return float(DIFFICULTIES[clampi(difficulty, 0, DIFFICULTIES.size() - 1)][key])


## Marca un legendario como capturado (lo llamará la captura en la Fase 4).
func mark_legendary_caught(identifier: String) -> void:
	legendary_caught[identifier] = true
	_legendary_respawn_roll[identifier] = false
