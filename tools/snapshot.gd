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
	# "arriba": cámara en su inclinación máxima (vista desde arriba).
	if args.size() > 5 and args[5] == "arriba":
		var rig := scene.get_node_or_null("CameraRig") as CameraRig
		if rig != null:
			rig.set("_pitch_deg", rig.pitch_max_deg)
			rig.set("_zoom", rig.zoom_max)
			for i in 40:
				await get_tree().process_frame
	# "borde": lleva al jugador cerca del borde oeste del mundo, mirando hacia afuera.
	if args.size() > 5 and args[5] == "borde":
		var player := scene.get_node("Player") as Player
		var world := scene.get_node("World") as WorldBuilder
		var x := -world.config.size * 0.5 + 12.0
		player.global_position = Vector3(x, world.surface_height_at(x, 20.0) + 1.0, 20.0)
		var rig := scene.get_node("CameraRig") as CameraRig
		rig.set("_yaw_deg", -90.0)
		rig.set("_pitch_deg", 12.0)
		for i in 120:
			await get_tree().process_frame
	# "cima": en la cima del borde norte, mirando hacia afuera.
	if args.size() > 5 and args[5] == "cima":
		var player := scene.get_node("Player") as Player
		var world := scene.get_node("World") as WorldBuilder
		var z := -world.config.size * 0.5 + 10.0
		player.global_position = Vector3(-90.0, world.surface_height_at(-90.0, z) + 1.0, z)
		var rig := scene.get_node("CameraRig") as CameraRig
		rig.set("_yaw_deg", 0.0)
		rig.set("_pitch_deg", 20.0)
		for i in 120:
			await get_tree().process_frame
	# "ayuda": abre la pantalla de Ayuda.
	if args.size() > 5 and args[5] == "ayuda":
		var help := scene.get_node("Hud").get("_help") as HelpOverlay
		help.toggle()
		print("ayuda visible=%s tam=%s hijos=%d" % [help.visible, help.size, help.get_child_count()])
		for i in 10:
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
