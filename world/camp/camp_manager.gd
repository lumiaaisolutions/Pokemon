class_name CampManager
extends Node3D
## Tiendas de campaña del jugador (campamento, comida y hambre; acordado con Fernando
## el 2026-10-10): se arman desde la Mochila en un lugar plano fuera de los pueblos
## (reutiliza el campamento del viajero, ver world/npc/camp.gd). Junto a la tienda, E
## abre un menú: Dormir (solo de noche, hasta las 7:00; cura al jugador y a su equipo,
## no el hambre), Cocinar (ver ui/camp/cooking_ui.gd) o Recoger. Si no se recoge, se
## queda ahí: persiste en GameState.world_flags["tents"] y se reconstruye al cargar.

@export var world_path: NodePath = NodePath("../World")
@export var player_path: NodePath = NodePath("../Player")

var world: WorldBuilder
var player: Player

## Cada entrada: {"camp": Camp, "point": Dictionary, "pos": Vector3}.
var _tents: Array[Dictionary] = []


func _ready() -> void:
	world = get_node(world_path) as WorldBuilder
	player = get_node(player_path) as Player
	for saved: Array in GameState.world_flags.get("tents", []):
		_spawn(Vector3(float(saved[0]), float(saved[1]), float(saved[2])), false)


func tents() -> Array[Dictionary]:
	return _tents


## ¿Se puede armar una tienda en (x, z) de near? Fuera de los pueblos, en tierra firme
## y sin encimarse con otra estructura o lugar especial.
func can_place_at(near: Vector3) -> bool:
	if world == null:
		return false
	if not world.is_inside(near.x, near.z, 10.0):
		return false
	if not world.settlement_at(near.x, near.z, 10.0).is_empty():
		return false
	if not world.structures.place_at(near.x, near.z, 6.0).is_empty():
		return false
	return world._dry_land(near.x, near.z, 2.5)


## Arma una tienda cerca de near (frente al jugador). Devuelve {"ok", "message"}.
func pitch_tent(near: Vector3) -> Dictionary:
	if not can_place_at(near):
		return {"ok": false, "message": "Aquí no puedes armar la tienda: busca un lugar plano fuera del pueblo."}
	var at := Vector3(near.x, world.surface_height_at(near.x, near.z), near.z)
	_spawn(at, true)
	return {"ok": true, "message": "¡Armaste tu tienda de campaña! Interactúa junto a ella para dormir, cocinar o recogerla."}


func _spawn(at: Vector3, animate: bool) -> void:
	var camp := Camp.create(self, at, _tents.size())
	var entry := {"camp": camp, "pos": at}
	entry["point"] = world.structures.add_point(at + Vector3(0, 0.5, 1.6), "Usar la tienda de campaña", _open_menu.bind(entry), 2.6)
	_tents.append(entry)
	_save()
	if animate:
		camp.pitch(player)
	else:
		# Ya estaba armada de antes (reconstrucción al cargar la partida): sin animación.
		camp.set_lit_instant()


func _save() -> void:
	var saved: Array = []
	for entry: Dictionary in _tents:
		var pos: Vector3 = entry["pos"]
		saved.append([pos.x, pos.y, pos.z])
	GameState.world_flags["tents"] = saved


func _open_menu(entry: Dictionary) -> void:
	var dialog := get_tree().get_first_node_in_group(&"dialog_box") as DialogBox
	if dialog == null:
		return
	var on_choice := func(choice: int) -> void:
		if choice == 0:
			sleep()
		elif choice == 1:
			open_cooking()
		elif choice == 2:
			pack_tent(entry)
	dialog.open("Tienda de campaña", ["¿Qué quieres hacer?"], null, ["Dormir", "Cocinar", "Recoger", "Nada"], on_choice)


## Dormir solo de noche: avanza hasta las 7:00 y cura al jugador y a su equipo (NO el
## hambre, que sigue bajando igual que si estuviera despierto).
func sleep() -> void:
	if not GameState.is_night():
		GameState.notice.emit("Solo puedes dormir de noche en tu tienda.")
		return
	GameState.sleep_until_morning()
	for member: Dictionary in GameState.party:
		member["hp_ratio"] = 1.0
	var main := get_parent()
	var companion := main.get("companion") as PokemonActor if main != null else null
	if companion != null:
		companion.recover(1.0)
	if player != null:
		player.heal(player.config.health_max)
	GameState.notice.emit("Dormiste en tu tienda. ¡Buenos días! Tú y tu equipo están descansados (el hambre sigue igual).")


func open_cooking() -> void:
	var main := get_parent()
	var layer := main.get_node_or_null("MenuLayer") as CanvasLayer if main != null else null
	if layer == null or layer.has_node("Cooking"):
		return
	var ui := CookingUI.new()
	ui.name = "Cooking"
	ui.main = main
	layer.add_child(ui)
	ui.open()


func pack_tent(entry: Dictionary) -> void:
	world.structures.remove_point(entry["point"])
	(entry["camp"] as Camp).pack(player)
	_tents.erase(entry)
	_save()
	GameState.add_item("tent", 1)
	GameState.notice.emit("Recogiste tu tienda de campaña.")
