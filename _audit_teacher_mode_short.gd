extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://main.tscn") as PackedScene
	var scene := packed.instantiate()
	var game := scene.get_node_or_null("GameManager")
	game.set("auto_start", false)
	game.set("debug_start_in_ghost_mode", false)
	# Audit harus mulai di HUNT sebelum scene diproses agar fase intro tidak berjalan di latar.
	game.set("phase", "HUNT")
	root.add_child(scene)
	current_scene = scene
	for i in range(240):
		await physics_frame
	var teacher := scene.get_node_or_null("Teacher") as CharacterBody3D
	var spawn := scene.get_node_or_null("SpawnManager/TeacherSpawn") as Node3D
	game.set("phase", "HUNT")
	game.set("teacher_mode", "teacher")
	teacher.set("_startup_room_exit_complete", true)
	teacher.global_position = spawn.global_position
	teacher.velocity = Vector3.ZERO
	teacher.set("_current_state", 0)
	teacher.set("_current_target", null)
	teacher.set("_current_corridor_waypoint", null)
	teacher.set("_corridor_waypoint_queue", [])
	teacher.call("_choose_next_corridor_waypoint")
	print("MODE_AUDIT_BEGIN auto_start=", game.get("auto_start"), " debug=", game.get("debug_start_in_ghost_mode"), " mode=", game.get("teacher_mode"), " phase=", game.get("phase"), " spawn=", teacher.global_position)
	for i in range(720):
		await physics_frame
		if i % 60 == 0:
			var wp: Variant = teacher.get("_current_corridor_waypoint")
			print("MODE_SAMPLE t=", i / 60, " mode=", game.get("teacher_mode"), " phase=", game.get("phase"), " state=", teacher.get("_current_state"), " pos=", teacher.global_position, " vel=", teacher.velocity, " wp=", (wp as Node3D).name if wp is Node3D else "null", " nav_target=", teacher.get_node("NavigationAgent3D").target_position, " jump=", teacher.get("_jump_recovery_active"))
	print("MODE_AUDIT_END")
	quit()
