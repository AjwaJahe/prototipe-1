extends SceneTree

func _initialize() -> void:
	call_deferred("_run_audit")

func _run_audit() -> void:
	var packed := load("res://main.tscn") as PackedScene
	if packed == null:
		print("AUDIT_ERROR: main.tscn failed to load")
		quit(2)
		return
	var scene := packed.instantiate()
	var game := scene.get_node_or_null("GameManager")
	if game == null:
		print("AUDIT_ERROR: GameManager missing")
		quit(3)
		return
	game.set("auto_start", false)
	game.set("debug_start_in_ghost_mode", false)
	# Mulai audit langsung di fase HUNT agar timer/cutscene intro tidak mengubah posisi guru di tengah tes.
	game.set("phase", "HUNT")
	root.add_child(scene)
	current_scene = scene
	for i in range(240):
		await physics_frame
	var teacher := scene.get_node_or_null("Teacher") as CharacterBody3D
	var spawn := scene.get_node_or_null("SpawnManager/TeacherSpawn") as Node3D
	var agent := teacher.get_node_or_null("NavigationAgent3D") as NavigationAgent3D if teacher != null else null
	if teacher == null or spawn == null or agent == null:
		print("AUDIT_ERROR: teacher/spawn/agent missing")
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
	var initial_waypoint := teacher.get("_current_corridor_waypoint") as Node3D
	if initial_waypoint != null:
		agent.target_position = initial_waypoint.global_position
	teacher.set("_stuck_sample_initialized", false)
	teacher.set("_stuck_recovery_attempts", 0)
	var last_wp := ""
	var last_state := -1
	var reached: Array[String] = []
	var route_failures := 0
	print("PATROL_AUDIT_BEGIN spawn=", teacher.global_position, " waypoints=", teacher.get("_corridor_waypoints").size())
	for i in range(1800):
		await physics_frame
		var wp: Variant = teacher.get("_current_corridor_waypoint")
		var wp_name: String = (wp as Node3D).name if wp is Node3D else "null"
		var state := int(teacher.get("_current_state"))
		if wp_name != last_wp:
			var distance: float = teacher.global_position.distance_to((wp as Node3D).global_position) if wp is Node3D else -1.0
			print("WAYPOINT_CHANGE t=", snappedf(float(i) / 60.0, 0.1), " from=", last_wp, " to=", wp_name, " distance=", snappedf(distance, 0.1), " queue=", (teacher.get("_corridor_waypoint_queue") as Array).size())
			last_wp = wp_name
		if state != last_state:
			print("STATE_CHANGE t=", snappedf(float(i) / 60.0, 0.1), " state=", state, " pos=", teacher.global_position, " wp=", wp_name)
			last_state = state
		if i % 300 == 0:
			var distance: float = teacher.global_position.distance_to((wp as Node3D).global_position) if wp is Node3D else -1.0
			print("SAMPLE t=", snappedf(float(i) / 60.0, 0.1), " pos=", teacher.global_position, " vel=", teacher.velocity, " mode=", game.get("teacher_mode"), " wp=", wp_name, " dist=", snappedf(distance, 0.1), " nav_target=", agent.target_position, " next=", teacher.get("_cached_next_path_position"), " finished=", agent.is_navigation_finished(), " stuck=", snappedf(float(teacher.get("_stuck_timer")), 0.1), " jump=", teacher.get("_jump_recovery_active"), " queue=", (teacher.get("_corridor_waypoint_queue") as Array).size())
		if wp is Node3D and teacher.global_position.distance_to((wp as Node3D).global_position) <= 1.5 and not reached.has(wp_name):
			reached.append(wp_name)
			print("WAYPOINT_REACHED t=", snappedf(float(i) / 60.0, 0.1), " name=", wp_name, " total=", reached.size())
	print("PATROL_AUDIT_END reached=", reached, " count=", reached.size(), " final_pos=", teacher.global_position, " final_wp=", last_wp, " route_failures=", route_failures)
	quit()

