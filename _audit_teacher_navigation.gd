extends SceneTree

func _initialize() -> void:
	call_deferred("_run_audit")

func _run_audit() -> void:
	var packed := load("res://main.tscn") as PackedScene
	if packed == null:
		_report("ERROR: main.tscn failed to load")
		quit(2)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in range(180):
		await physics_frame
	var teacher := scene.get_node_or_null("Teacher") as CharacterBody3D
	var game := scene.get_node_or_null("GameManager")
	var spawn := scene.get_node_or_null("SpawnManager/TeacherSpawn") as Node3D
	if teacher == null or game == null or spawn == null:
		_report("ERROR missing teacher/game/spawn")
		quit(3)
		return
	game.set("phase", "HUNT")
	game.set("teacher_mode", "teacher")
	teacher.global_position = spawn.global_position
	teacher.velocity = Vector3.ZERO
	teacher.set("_startup_room_exit_complete", false)
	var agent := teacher.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	_report("SIM_BEGIN spawn=" + str(teacher.global_position))
	for i in range(900):
		await physics_frame
		if i % 60 == 0:
			var wp: Variant = teacher.get("_current_corridor_waypoint")
			var wp_name: String = (wp as Node3D).name if wp is Node3D else "null"
			_report("t=" + str(i / 60) + " pos=" + str(teacher.global_position) + " vel=" + str(teacher.velocity) + " state=" + str(teacher.get("_current_state")) + " wp=" + wp_name + " agent_target=" + str(agent.target_position) + " finished=" + str(agent.is_navigation_finished()) + " next=" + str(agent.get_next_path_position()) + " stuck=" + str(teacher.get("_stuck_timer")))
	_report("SIM_END pos=" + str(teacher.global_position))
	quit()

func _report(line: String) -> void:
	print(line)
