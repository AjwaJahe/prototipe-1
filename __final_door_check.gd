extends SceneTree

func _init() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var root: Node = packed.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame
	await process_frame

	var map: Node = root.get_node_or_null("Map58")
	var door_walls: Node = map.get_node_or_null("DoorWalls") if map != null else null
	var furniture: Node = root.get_node_or_null("Furniture")
	var door_count := 0
	if furniture != null:
		for c: Node in furniture.get_children():
			if String(c.name).begins_with("Pintu"):
				door_count += 1

	var out: FileAccess = FileAccess.open("res://__final_door_check.txt", FileAccess.WRITE)
	out.store_line("main_loaded=true")
	out.store_line("door_count=" + str(door_count))
	out.store_line("door_walls_loaded=" + str(door_walls != null))
	out.store_line("door_walls_count=" + str(door_walls.get_child_count() if door_walls != null else -1))

	var sample_wall: MeshInstance3D = door_walls.get_node_or_null("WallAbove_PintuKelas_11_North_A") as MeshInstance3D if door_walls != null else null
	out.store_line("sample_wall_loaded=" + str(sample_wall != null))
	out.store_line("sample_wall_material=" + str(sample_wall.material_override if sample_wall != null else null))

	var door: Node = furniture.get_node_or_null("PintuKelas_11_North_A") if furniture != null else null
	out.store_line("north_door_loaded=" + str(door != null))
	var leaf: MeshInstance3D = door.get_node_or_null("DoorPivot/DoorLeaf") as MeshInstance3D if door != null else null
	if leaf != null and leaf.material_override is BaseMaterial3D:
		out.store_line("north_door_cull=" + str((leaf.material_override as BaseMaterial3D).cull_mode))

	out.close()
	quit(0)
