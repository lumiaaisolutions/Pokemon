extends Node
## Estado global de la partida: equipo, inventario, progreso y banderas del mundo.

## Probabilidad de que un legendario ya capturado reaparezca (se tira una vez por sesión).
const LEGENDARY_RESPAWN_CHANCE := 0.02

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


## Marca un legendario como capturado (lo llamará la captura en la Fase 4).
func mark_legendary_caught(identifier: String) -> void:
	legendary_caught[identifier] = true
	_legendary_respawn_roll[identifier] = false
