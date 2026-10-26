extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://main.tscn") as PackedScene
	var scene := packed.instantiate()
	var game := scene.get_node_or_null("GameManager")
	game.set("auto_start", false)
	game.set("debug_start_in_ghost_mode", false)
	root.add_child(scene)
	current_scene = scene
	for i in range(240):
		await physics_frame
	var teacher := scene.get_node_or_null("Teacher") as CharacterBody3D
	var spawn := scene.get_node_or_null("SpawnManager/TeacherSpawn") as Node3D
	var agent := teacher.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	var corridor := scene.get_node_or_null("Map58/Rooms/Corridor")
	if teacher == null or spawn == null or agent == null or corridor == null:
		print("NAVPATH_AUDIT_ERROR: required node missing")
		quit(2)
		return
	var map := agent.get_navigation_map()
	var origin := Vector3(spawn.global_position.x, 0.0, spawn.global_position.z)
	print("NAVPATH_AUDIT_BEGIN map_valid=", map.is_valid(), " origin=", origin)
	for node in corridor.get_children():
		if node is not Marker3D:
			continue
		var waypoint := node as Marker3D
		var goal := waypoint.global_position
		var closest := NavigationServer3D.map_get_closest_point(map, goal)
		var path := NavigationServer3D.map_get_path(map, origin, goal, true)
		var length := 0.0
		for i in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])
		print("WAYPOINT_PATH name=", waypoint.name, " goal=", goal, " closest_delta=", snappedf(closest.distance_to(goal), 0.1), " path_points=", path.size(), " path_length=", snappedf(length, 0.1), " end=", path[path.size() - 1] if path.size() > 0 else Vector3.ZERO)
		for i in range(mini(path.size(), 8)):
			print(" PATH_POINT ", waypoint.name, " #", i, " ", path[i])
	print("NAVPATH_AUDIT_END")
	quit()
