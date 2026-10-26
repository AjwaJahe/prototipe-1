extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://main.tscn") as PackedScene
	if packed == null:
		print("DIAG_ERROR: main.tscn load failed")
		quit(2)
		return
	var scene := packed.instantiate()
	var game := scene.get_node_or_null("GameManager")
	if game == null:
		print("DIAG_ERROR: GameManager missing")
		quit(3)
		return
	game.set("auto_start", false)
	game.set("debug_start_in_ghost_mode", false)
	game.set("phase", "HUNT")
	root.add_child(scene)
	current_scene = scene
	for i in range(240):
		await physics_frame
	var teacher := scene.get_node_or_null("Teacher") as CharacterBody3D
	var spawn := scene.get_node_or_null("SpawnManager/TeacherSpawn") as Node3D
	if teacher == null or spawn == null:
		print("DIAG_ERROR: teacher/spawn missing")
		quit(4)
		return
	game.set("phase", "HUNT")
	game.set("teacher_mode", "teacher")
	teacher.set("_startup_room_exit_complete", true)
	teacher.global_position = Vector3(spawn.global_position.x, 0.0, spawn.global_position.z)
	teacher.velocity = Vector3.ZERO
	teacher.set("_current_state", 0)
	teacher.set("_current_target", null)
	teacher.set("_current_corridor_waypoint", null)
	teacher.set("_corridor_waypoint_queue", [])
	teacher.call("_choose_next_corridor_waypoint")
	var agent := teacher.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if agent != null and teacher.get("_current_corridor_waypoint") is Node3D:
		agent.target_position = (teacher.get("_current_corridor_waypoint") as Node3D).global_position
	teacher.set("_stuck_sample_initialized", false)
	teacher.set("_stuck_recovery_attempts", 0)
	var previous := teacher.global_position
	print("DIAG_BEGIN pos=", previous, " phase=", game.get("phase"), " mode=", game.get("teacher_mode"))
	for i in range(1800):
		await physics_frame
		var current := teacher.global_position
		var delta_pos := current.distance_to(previous)
		if delta_pos > 3.0:
			var wp: Variant = teacher.get("_current_corridor_waypoint")
			print("LARGE_DISPLACEMENT t=", snappedf(float(i) / 60.0, 0.01),
				" delta=", snappedf(delta_pos, 0.01), " from=", previous, " to=", current,
				" velocity=", teacher.velocity, " phase=", game.get("phase"),
				" mode=", game.get("teacher_mode"), " intro_departure=", game.get("intro_departure_active"),
				" startup_exit=", teacher.get("_startup_room_exit_complete"),
				" state=", teacher.get("_current_state"),
				" waypoint=", (wp as Node3D).name if wp is Node3D else "null",
				" nav_target=", agent.target_position if agent != null else Vector3.ZERO)
		if i % 300 == 0:
			print("SAMPLE t=", snappedf(float(i) / 60.0, 0.1), " pos=", current,
				" velocity=", teacher.velocity, " phase=", game.get("phase"),
				" mode=", game.get("teacher_mode"), " intro_departure=", game.get("intro_departure_active"),
				" state=", teacher.get("_current_state"), " stuck=", teacher.get("_stuck_timer"))
		previous = current
	print("DIAG_END pos=", teacher.global_position, " phase=", game.get("phase"))
	quit()
