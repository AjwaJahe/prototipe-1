@tool
extends Node3D


var _created := false


func _ready() -> void:
	call_deferred("_create_map_collision")


func _create_map_collision() -> void:

	if _created:
		return

	var visual := get_node_or_null("Visual")

	if visual == null:
		push_warning(
			"Map58 Collision: node Visual tidak ditemukan."
		)
		return


	var meshes: Array[MeshInstance3D] = []

	_collect_meshes(
		visual,
		meshes
	)


	if meshes.is_empty():
		push_warning(
			"Map58 Collision: tidak menemukan MeshInstance3D."
		)
		return


	var collision_root := Node3D.new()
	collision_root.name = "Map58Collision"

	add_child(collision_root)


	var floor_count := 0
	var wall_count := 0


	for mesh_instance in meshes:

		if mesh_instance == null:
			continue

		if mesh_instance.mesh == null:
			continue


		var mesh_name := mesh_instance.name.to_lower()


		# Jangan buat collision untuk furniture.
		if "administrasi" in mesh_name:
			continue

		if "desk" in mesh_name:
			continue

		if "reception" in mesh_name:
			continue


		var aabb: AABB = mesh_instance.get_aabb()


		# ==================================================
		# FLOOR
		# ==================================================

		if (
			"ground" in mesh_name
			or "floor" in mesh_name
			or "lantai" in mesh_name
		):

			_create_collision(
				collision_root,
				mesh_instance,
				true
			)

			floor_count += 1

			continue


		# ==================================================
		# WALL
		#
		# Map58.glb dibuat dengan tinggi dinding sekitar 9.6
		# pada sumbu lokal Z.
		# ==================================================

		if aabb.size.z >= 8.0:

			_create_collision(
				collision_root,
				mesh_instance,
				false
			)

			wall_count += 1


	_created = true


	print(
		"Map58 collision dibuat | floor: ",
		floor_count,
		" | walls: ",
		wall_count
	)


func _collect_meshes(
	node: Node,
	result: Array[MeshInstance3D]
) -> void:

	if node is MeshInstance3D:
		result.append(
			node as MeshInstance3D
		)


	for child in node.get_children():

		_collect_meshes(
			child,
			result
		)


func _create_collision(
	collision_root: Node3D,
	mesh_instance: MeshInstance3D,
	is_floor: bool
) -> void:

	var mesh := mesh_instance.mesh

	if mesh == null:
		return


	var shape := mesh.create_trimesh_shape()

	if shape == null:
		push_warning(
			"Map58 Collision: gagal membuat shape untuk " +
			mesh_instance.name
		)
		return


	var body := StaticBody3D.new()

	body.name = mesh_instance.name + "_StaticBody3D"

	collision_root.add_child(body)


	var collision := CollisionShape3D.new()

	collision.name = "CollisionShape3D"

	collision.shape = shape

	body.add_child(collision)


	# Collision mengikuti posisi, rotasi, dan scale
	# mesh sumber.
	body.global_transform = mesh_instance.global_transform
