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
	# "hora:H": pone el reloj a la hora H (p. ej. hora:22). También como 7.º argumento
	# para combinarla con otra opción (p. ej. pueblo hora:21).
	var hour_arg := args[5] if args.size() > 5 and args[5].begins_with("hora:") else (args[6] if args.size() > 6 and args[6].begins_with("hora:") else "")
	if hour_arg != "":
		GameState.play_time = (float(hour_arg.substr(5)) - GameState.START_HOUR) * 60.0
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
		GameState.world_flags["ride_license"] = true
		GameState.world_flags["fly_license"] = true
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
	# "poi:tipo": el jugador frente al punto de interés de ese tipo más cercano al inicio.
	if args.size() > 5 and args[5].begins_with("poi:"):
		var world := scene.get_node("World") as WorldBuilder
		var player := scene.get_node("Player") as Player
		var pois := scene.get_node("PointsOfInterest") as PointsOfInterest
		var want := args[5].substr(4)
		var start := world.start_position()
		var found: Dictionary = {}
		for ring in range(1, 18):
			for k in ring * 8:
				var a := TAU * k / (ring * 8.0)
				var key := Vector2i(int(floor((start.x + cos(a) * ring * 128.0) / 128.0)), int(floor((start.z + sin(a) * ring * 128.0) / 128.0)))
				var p := pois.plan(key)
				if not p.is_empty() and p["kind"] == want and found.is_empty():
					found = p
		if not found.is_empty():
			var at := Vector3(float(found["x"]), 0, float(found["z"]) + 7.0)
			world.ensure_area(at)
			player.global_position = Vector3(at.x, world.surface_height_at(at.x, at.z) + 0.5, at.z)
			var rig := scene.get_node("CameraRig") as CameraRig
			rig.set("_yaw_deg", 0.0)
			rig.set("_pitch_deg", 22.0)
			print("poi en ", found)
			for i in 150:
				await get_tree().process_frame
	# "lago:N": el jugador en la orilla del lago N (o del primero en pantano con "lago:pantano").
	if args.size() > 5 and args[5].begins_with("lago:"):
		var world := scene.get_node("World") as WorldBuilder
		var player := scene.get_node("Player") as Player
		var which := args[5].substr(5)
		var lake: Vector4 = world.layout.lakes[0]
		if which == "charca":
			# Primera charca de pantano cerca del inicio (zonas en espiral).
			var o := world.start_position()
			var found := false
			for ring in range(1, 30):
				for k in 16:
					var a := TAU * k / 16.0
					var ponds: Array = world._ponds_at(o.x + cos(a) * ring * 64.0, o.z + sin(a) * ring * 64.0)
					if not ponds.is_empty() and not found:
						var p4: Vector4 = ponds[0]
						lake = Vector4(p4.x, p4.y, p4.z, p4.w)
						found = true
		elif which == "pantano":
			for l: Vector4 in world.layout.lakes:
				if world.layout.biome_at(l.x, l.y) in [RegionLayout.Biome.SWAMP, RegionLayout.Biome.TOXIC_SWAMP]:
					lake = l
					break
		elif which.is_valid_int():
			lake = world.layout.lakes[mini(int(which), world.layout.lakes.size() - 1)]
		var at := Vector2(lake.x, lake.y) + Vector2(1, 0) * (lake.z + 14.0)
		world.ensure_area(Vector3(at.x, 0, at.y))
		player.global_position = Vector3(at.x, world.surface_height_at(at.x, at.y) + 0.5, at.y)
		var rig := scene.get_node("CameraRig") as CameraRig
		rig.set("_yaw_deg", 90.0)
		rig.set("_pitch_deg", 12.0)
		print("lago en ", lake, " bioma ", world.layout.biome_at(lake.x, lake.y))
		for i in 120:
			await get_tree().process_frame
	# "edificio:tipo:grados": el jugador a 9 m del primer edificio de ese tipo (center,
	# house, mart…) en el ángulo dado (0 = de frente, 180 = por detrás), mirándolo.
	if args.size() > 5 and args[5].begins_with("edificio:"):
		var parts := args[5].split(":")
		var world := scene.get_node("World") as WorldBuilder
		var player := scene.get_node("Player") as Player
		var target: Dictionary = {}
		var owner_town: Dictionary = {}
		for s: Dictionary in world.layout.settlements:
			for b: Dictionary in s["buildings"]:
				if b["kind"] == parts[1] and target.is_empty():
					target = b
					owner_town = s
		if not target.is_empty():
			var front := Vector2(float(owner_town["x"]) - float(target["x"]), float(owner_town["z"]) - float(target["z"])).normalized()
			var dir := front.rotated(deg_to_rad(float(parts[2]) if parts.size() > 2 else 0.0))
			var at := Vector2(float(target["x"]), float(target["z"])) + dir * 9.0
			world.ensure_area(Vector3(at.x, 0, at.y))
			player.global_position = Vector3(at.x, world.surface_height_at(at.x, at.y) + 0.5, at.y)
			var rig := scene.get_node("CameraRig") as CameraRig
			rig.set("_yaw_deg", rad_to_deg(atan2(dir.x, dir.y)))
			rig.set("_pitch_deg", 25.0)
			for i in 90:
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
	# "bioma:NOMBRE": lleva al jugador al punto más cercano al inicio de ese bioma (nombre
	# del enum RegionLayout.Biome, p. ej. "bioma:FOREST"); gira la cámara con "giro:N"
	# grados de yaw como argumento extra (revisión de vegetación 3D, 2026-10-10).
	if args.size() > 5 and args[5].begins_with("bioma:"):
		var world := scene.get_node("World") as WorldBuilder
		var player := scene.get_node("Player") as Player
		var want: RegionLayout.Biome = RegionLayout.Biome[args[5].substr(6).to_upper()]
		var o := world.start_position()
		var found := Vector3.INF
		for ring in range(0, 90):
			for k in maxi(ring * 6, 1):
				var a := TAU * k / maxf(ring * 6.0, 1.0)
				var x := o.x + cos(a) * ring * 48.0
				var z := o.z + sin(a) * ring * 48.0
				if world.layout.biome_at(x, z) == want and world._dry_land(x, z, 6.0) and world.settlement_at(x, z, 20.0).is_empty():
					found = Vector3(x, 0, z)
					break
			if found != Vector3.INF:
				break
		if found == Vector3.INF:
			print("bioma no encontrado cerca del inicio: ", args[5])
		else:
			world.ensure_area(found)
			player.global_position = Vector3(found.x, world.surface_height_at(found.x, found.z) + 0.5, found.z)
			print("bioma %s en %s" % [args[5], found])
		var bioma_rig := scene.get_node("CameraRig") as CameraRig
		bioma_rig.snap()
		var giro_arg := ""
		for extra in args.slice(6):
			if extra.begins_with("giro:"):
				giro_arg = extra
		bioma_rig.set("_yaw_deg", float(giro_arg.substr(5)) if giro_arg != "" else 0.0)
		bioma_rig.set("_pitch_deg", 18.0)
		for i in 150:
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
