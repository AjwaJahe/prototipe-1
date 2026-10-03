extends Node3D

var collision_created := false


func _ready() -> void:
	call_deferred("_create_floor_collision")


func _create_floor_collision() -> void:
	if collision_created:
		return

	var floor_nodes: Array[Node] = find_children(
		"*",
		"MeshInstance3D",
		true,
		false
	)

	var created := 0

	for child: Node in floor_nodes:
		var mesh_instance := child as MeshInstance3D

		if mesh_instance == null:
			continue

		if mesh_instance.mesh == null:
			continue

		var mesh_name := mesh_instance.name.to_lower()

		# Cari mesh lantai.
		if mesh_name != "ground" and not mesh_name.contains("floor"):
			continue

		var shape := mesh_instance.mesh.create_trimesh_shape()

		if shape == null:
			continue

		var body := StaticBody3D.new()
		body.name = "FloorBody_%d" % created
		body.collision_layer = 1
		body.collision_mask = 1

		add_child(body)

		var collision := CollisionShape3D.new()
		collision.name = "FloorShape"
		collision.shape = shape

		body.add_child(collision)

		# Ikuti transform mesh lantai asli.
		collision.global_transform = mesh_instance.global_transform

		created += 1

	collision_created = true

	print("Floor collision dibuat: ", created)
