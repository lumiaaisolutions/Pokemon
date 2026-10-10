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
	# "surf": compañero de tipo Agua y el jugador en el lago.
	if args.size() > 5 and args[5] == "surf":
		var player := scene.get_node("Player") as Player
		var world := scene.get_node("World") as WorldBuilder
		var old := scene.get("companion") as PokemonActor
		if old != null:
			old.queue_free()
		scene.call("_create_companion", load("res://creatures/data/species/lapras.tres"), false, player.global_position + Vector3(1.5, 0.3, 0.0))
		var lake := world.config.lake_center
		player.global_position = Vector3(lake.x, world.water_level_at(lake.x, lake.y) - 0.5, lake.y)
		for i in 120:
			await get_tree().process_frame
	# "barra": un salvaje herido frente al jugador (para ver su recuadro de vida).
	if args.size() > 5 and args[5] == "barra":
		var player := scene.get_node("Player") as Player
		var spawner := scene.get_node("Spawner") as WildSpawner
		spawner.set_process(false)
		var world := scene.get_node("World") as WorldBuilder
		var p := player.global_position + Vector3(1.5, 0.0, -6.0)
		p.y = world.surface_height_at(p.x, p.z)
		var wild := spawner.spawn_species(load("res://creatures/data/species/nidoran-f.tres"), p, false, false)
		wild.set_physics_process(false)
		wild.hp = wild.hp_max * 0.4
		(wild.get_node("HealthBar") as HealthBar3D).set_ratio(0.4)
		for i in 30:
			await get_tree().process_frame
	# "menu:N": abre el menú en la pestaña N (0 Equipo, 1 Mochila, 2 Pokédex…), con datos
	# de ejemplo en la Pokédex y el equipo.
	if args.size() > 5 and args[5].begins_with("menu:"):
		for id in ["bulbasaur", "pikachu", "greninja", "charmander", "eevee"]:
			GameState.mark_seen(id)
		GameState.add_caught(load("res://creatures/data/species/greninja.tres"), false, 0.7, 0, 1.1)
		GameState.add_caught(load("res://creatures/data/species/pikachu.tres"), true, 1.0, 1, 0.9)
		GameState.dex_count("greninja", "fights")
		var menu := scene.get_node("MenuLayer/GameMenu") as GameMenu
		menu.selected_member = 1
		menu.open()
		menu.show_tab(int(args[5].substr(5)))
		for i in 3:
			await get_tree().process_frame
		menu.show_tab(int(args[5].substr(5)))
		for i in 20:
			await get_tree().process_frame
	# "hora:H": pone el reloj a la hora H (p. ej. hora:22).
	if args.size() > 5 and args[5].begins_with("hora:"):
		GameState.play_time = (float(args[5].substr(5)) - GameState.START_HOUR) * 60.0
		if GameState.play_time < 0.0:
			GameState.play_time += GameState.DAY_SECONDS
		for i in 30:
			await get_tree().process_frame
	# "pueblo": vista amplia del pueblo inicial desde arriba.
	if args.size() > 5 and args[5] == "pueblo":
		var rig := scene.get_node("CameraRig") as CameraRig
		rig.set("_pitch_deg", 45.0)
		rig.set("_zoom", rig.zoom_max)
		rig.set("_yaw_deg", 30.0)
		for i in 60:
			await get_tree().process_frame
	# "vuelo": monta un Charizard y sube 40 m para ver la región desde el aire.
	if args.size() > 5 and args[5] == "vuelo":
		var player := scene.get_node("Player") as Player
		var old := scene.get("companion") as PokemonActor
		if old != null:
			old.queue_free()
		scene.call("_create_companion", load("res://creatures/data/species/charizard.tres"), false, player.global_position + Vector3(1.5, 0.3, 0.0))
		for i in 10:
			await get_tree().process_frame
		scene.call("toggle_ride")
		player.take_off()
		player.global_position.y += 40.0
		var rig := scene.get_node("CameraRig") as CameraRig
		rig.set("_pitch_deg", 25.0)
		rig.set("_zoom", rig.zoom_max)
		for i in 150:
			await get_tree().process_frame
	# "interior:tipo": entra al interior más cercano de ese tipo (center, mart, cave…).
	if args.size() > 5 and args[5].begins_with("interior:"):
		var kind := args[5].substr(9)
		var world := scene.get_node("World") as WorldBuilder
		var services := world.structures.services
		var player := scene.get_node("Player") as Player
		if kind in Interiors.DUNGEONS:
			var place: Dictionary = world.layout.places_of(kind if kind != "sewer" else "cave")[0]
			services.enter_interior(kind, {}, place)
		else:
			var settlement: Dictionary = world.layout.settlements[0]
			for s: Dictionary in world.layout.settlements:
				if (s["buildings"] as Array).any(func(b: Dictionary) -> bool: return b["kind"] == kind):
					settlement = s
					break
			var building: Dictionary = (settlement["buildings"] as Array).filter(func(b: Dictionary) -> bool: return b["kind"] == kind)[0]
			services.enter_interior(kind, settlement, building)
		for i in 90:
			await get_tree().process_frame
		var rig := scene.get_node("CameraRig") as CameraRig
		rig.set("_pitch_deg", 50.0)
		for i in 30:
			await get_tree().process_frame
		print("interior en ", player.global_position)
	# "clima:N": fuerza el clima N (0 despejado, 2 lluvia, 3 tormenta, 4 nieve, 6 arena, 8 niebla).
	if args.size() > 5 and args[5].begins_with("clima:"):
		Weather.forced = int(args[5].substr(6))
		for i in 200:
			await get_tree().process_frame
	# "lugar:tipo": lleva al jugador frente al primer lugar especial de ese tipo.
	if args.size() > 5 and args[5].begins_with("lugar:"):
		var world := scene.get_node("World") as WorldBuilder
		var player := scene.get_node("Player") as Player
		var place: Dictionary = world.layout.places_of(args[5].substr(6))[0]
		var x := float(place["x"]) + 6.0
		var z := float(place["z"]) + 22.0
		world.ensure_area(Vector3(x, 0, z))
		player.global_position = Vector3(x, world.height_at(x, z) + 1.0, z)
		var rig := scene.get_node("CameraRig") as CameraRig
		rig.snap()
		rig.set("_pitch_deg", 20.0)
		rig.set("_zoom", rig.zoom_max)
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
