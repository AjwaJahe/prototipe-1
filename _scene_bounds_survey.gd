extends SceneTree
var lines := PackedStringArray()
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for path in ["res://main.tscn", "res://map58/Map58.tscn", "res://map_58.tscn"]:
		var ps := load(path) as PackedScene
		if ps == null:
			lines.append("LOAD_FAIL|" + path)
			continue
		var scene := ps.instantiate()
		root.add_child(scene)
		await process_frame
		lines.append("\nSCENE|" + path + "|root=" + _v(scene.global_position if scene is Node3D else Vector3.ZERO))
		_walk(scene, path)
		root.remove_child(scene)
		scene.free()
		await process_frame
	var f := FileAccess.open("res://_scene_bounds_survey.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))
		f.close()
	print("\n".join(lines))
	quit()
func _walk(n: Node, path: String) -> void:
	if n is MeshInstance3D:
		var m := n as MeshInstance3D
		var nm := String(m.name)
		if nm.to_lower().contains("floor") or nm.to_lower().contains("basket") or nm.to_lower().contains("entrance") or nm.to_lower().contains("doorfill"):
			var a := m.get_aabb()
			var corners := [
				Vector3(a.position.x,a.position.y,a.position.z),
				Vector3(a.end.x,a.position.y,a.position.z),
				Vector3(a.position.x,a.end.y,a.position.z),
				Vector3(a.position.x,a.position.y,a.end.z),
				Vector3(a.end.x,a.end.y,a.position.z),
				Vector3(a.end.x,a.position.y,a.end.z),
				Vector3(a.position.x,a.end.y,a.end.z),
				Vector3(a.end.x,a.end.y,a.end.z)
			]
			var lo := Vector3(INF,INF,INF)
			var hi := Vector3(-INF,-INF,-INF)
			for c in corners:
				var w: Vector3 = m.global_transform * c
				lo = lo.min(w)
				hi = hi.max(w)
			lines.append("BOUNDS|" + path + "|" + str(m.get_path()) + "|min=" + _v(lo) + "|max=" + _v(hi) + "|center=" + _v((lo+hi)*0.5))
	for c in n.get_children():
		_walk(c,path)
func _v(v: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [v.x,v.y,v.z]
