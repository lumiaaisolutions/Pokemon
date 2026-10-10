extends Node
## Captura una escena con el render real (no headless) para revisar cómo se ve.
## Uso: godot --path . tools/snapshot.tscn -- <escena.tscn> <salida.png> [cuadros] [personaje] [paso]
## Si se pasa personaje, lo fija en GameState antes de cargar (para ver el mundo con él).
## paso: en la selección de personaje, abre ese paso (1 = personajes, 2 = nombre…).

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else "res://ui/character_select/character_select.tscn"
	var out: String = args[1] if args.size() > 1 else "user://snapshot.png"
	var frames: int = int(args[2]) if args.size() > 2 else 30
	if args.size() > 3:
		GameState.character_id = args[3]
		GameState.player_name = PlayerCharacters.find(args[3])["name"]
	var scene := (load(scene_path) as PackedScene).instantiate()
	add_child(scene)
	if args.size() > 4 and scene.has_method("_show_step"):
		await get_tree().process_frame
		if args.size() > 3:
			var entry := PlayerCharacters.find(args[3])
			scene.set("_gender", entry["gender"])
			scene.call("_select_character", entry)
		scene.call("_show_step", int(args[4]))
	for i in frames:
		await get_tree().process_frame
	# "desmayo": tumba al jugador para ver el estado de desmayo.
	if args.size() > 5 and args[5] == "desmayo":
		var player := scene.get_node_or_null("Player") as Player
		if player != null:
			player.take_damage(1000.0)
			for i in 120:
				await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("captura: ", out)
	get_tree().quit()
