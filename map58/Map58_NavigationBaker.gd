extends NavigationRegion3D

## Bake NavigationMesh dari model Map58 (Visual) saat game dimulai jika
## navigation mesh belum pernah di-bake di editor.

@export var source_path: NodePath = ^"../Visual"


func _ready() -> void:
	if navigation_mesh == null:
		push_warning("Map58 NavigationBaker: NavigationMesh belum di-assign.")
		return

	# Samakan ukuran voxel navigation map dengan NavigationMesh agar rasterisasi
	# tepi jalur konsisten dan tidak menghasilkan warning cell size/height mismatch.
	var navigation_map := get_navigation_map()
	if navigation_map.is_valid():
		NavigationServer3D.map_set_cell_size(navigation_map, navigation_mesh.cell_size)
		NavigationServer3D.map_set_cell_height(navigation_map, navigation_mesh.cell_height)

	var source := get_node_or_null(source_path)
	if source != null:
		source.add_to_group(navigation_mesh.geometry_source_group_name)

	# Navmesh harus memasukkan furnitur dan bangku tribun yang berada di luar Map58/Visual.
	# Tanpa sumber ini, guru merencanakan rute seolah-olah meja/lemari tidak ada.
	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root.get_node_or_null("Main")
	if scene_root != null:
		var furniture_root := scene_root.get_node_or_null("Furniture")
		if furniture_root != null:
			# Kelompokkan per sub-scene furnitur, bukan root Furniture secara utuh,
			# supaya daun pintu yang bisa bergerak tidak ikut terukir sebagai tembok permanen.
			for furniture_part in furniture_root.get_children():
				var part_name := String(furniture_part.name).to_lower()
				if "pintu" in part_name or "door" in part_name:
					continue
				furniture_part.add_to_group(navigation_mesh.geometry_source_group_name)

		for source_path_outside_map in ["BasketballBleachers"]:
			var external_source := scene_root.get_node_or_null(NodePath(source_path_outside_map))
			if external_source != null:
				external_source.add_to_group(navigation_mesh.geometry_source_group_name)

	var scene_root_for_caps := get_tree().current_scene
	if scene_root_for_caps != null:
		var map_root_for_caps := scene_root_for_caps.get_node_or_null("Map58")
		if map_root_for_caps != null:
			var wall_caps := map_root_for_caps.get_node_or_null("Map58_WallAboveOpenings")
			if wall_caps != null:
				wall_caps.add_to_group(navigation_mesh.geometry_source_group_name)

	if navigation_mesh.get_polygon_count() == 0:
		call_deferred("_bake_when_ready")


func _bake_when_ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

	# The map collision is generated deferred by Map58_FloorCollision.gd.
	# Bake from StaticBody3D/CollisionShape3D geometry so desks and walls become
	# obstacles, rather than treating their render meshes as walkable surfaces.
	var map_root := get_parent()
	if map_root != null:
		var collision_root := map_root.get_node_or_null("Map58Collision")
		if collision_root != null:
			collision_root.add_to_group(navigation_mesh.geometry_source_group_name)
		else:
			push_warning("Map58 NavigationBaker: Map58Collision belum tersedia saat bake.")

	# Geometry source groups are collected relative to NavigationRegion3D.
	# Visual, Furniture, tribun, and wall caps are siblings elsewhere in the scene,
	# so assigning their group alone does not guarantee they enter the bake.
	# Temporarily attach only the explicitly grouped source roots to this region
	# while bake_navigation_mesh() collects geometry, then restore every parent
	# and sibling index immediately so gameplay NodePaths remain unchanged.
	var sources: Array[Node3D] = []
	var original_parents: Array[Node] = []
	var original_indices: Array[int] = []
	# Snapshot every original index before moving any sibling; otherwise indices
	# shift as earlier siblings are removed and restoration can reorder the scene.
	for node in get_tree().get_nodes_in_group(navigation_mesh.geometry_source_group_name):
		var source := node as Node3D
		if source == null or source == self or is_ancestor_of(source):
			continue
		var parent := source.get_parent()
		if parent == null:
			continue
		sources.append(source)
		original_parents.append(parent)
		original_indices.append(source.get_index())

	for source in sources:
		source.reparent(self, true)

	bake_navigation_mesh(true)

	# Restore in original scene-tree order to preserve NodePaths and sibling order.
	for i in range(sources.size()):
		var source := sources[i]
		var parent := original_parents[i]
		if not is_instance_valid(source) or not is_instance_valid(parent):
			continue
		source.reparent(parent, true)
		parent.move_child(source, mini(original_indices[i], parent.get_child_count() - 1))

	print("Map58 NavigationBaker: sumber geometri sementara = ", sources.size())
	await bake_finished
	print("Map58 NavigationBaker: bake selesai, polygon navmesh = ", navigation_mesh.get_polygon_count())
