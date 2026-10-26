extends Node3D

## Gameplay layer untuk furnitur interaktif Map58.
## Tidak memindahkan atau mengubah mesh/furnitur yang sudah ada.

const HIDE_SCRIPT := preload("res://Map58HidingSpot.gd")
const CRATE_HIDE_SCRIPT := preload("res://Map58CrateHiding.gd")
const CABINET_SCRIPT := preload("res://Map58CabinetInteractive.gd")
const CLASS_CUPBOARD_SCRIPT := preload("res://Map58ClassroomCupboard.gd")
const TEACHER_DESK_SCRIPT := preload("res://Map58TeacherDeskInteraction.gd")


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	var furniture := get_node_or_null("../Furniture")
	if furniture == null:
		push_warning("Map58FurnitureGameplay: node Furniture tidak ditemukan.")
		return
	_scan_furniture(furniture)


func _scan_furniture(node: Node) -> void:
	if node is Node3D:
		var node_3d := node as Node3D
		var node_name := String(node_3d.name)

		if node_name == "TeacherDesk":
			if node_3d.get_script() != TEACHER_DESK_SCRIPT:
				node_3d.set_script(TEACHER_DESK_SCRIPT)
				node_3d.call_deferred("configure")
		elif node_name == "Cupboard":
			if node_3d.get_script() != CLASS_CUPBOARD_SCRIPT:
				node_3d.set_script(CLASS_CUPBOARD_SCRIPT)
			node_3d.call_deferred("configure")
		elif node_name == "Cabinet" and node_3d.get_parent() != null and String(node_3d.get_parent().name) == "UKS_Furniture":
			if node_3d.get_script() != CABINET_SCRIPT:
				node_3d.set_script(CABINET_SCRIPT)
			node_3d.call_deferred("configure")
		elif node_name == "LargeStorageCrate":
			_attach_crate_hiding(node_3d)
		elif node_name == "Bed_Left" or node_name == "Bed_Right":
			_attach_under_bed_spot(node_3d)
		elif _is_tall_hide_candidate(node_3d):
			_attach_hiding_spots(node_3d)

	for child in node.get_children():
		_scan_furniture(child)


func _attach_under_bed_spot(bed: Node3D) -> void:
	if bed.get_node_or_null("Map58HideSpotUnderBed") != null:
		return

	var area := Area3D.new()
	area.name = "Map58HideSpotUnderBed"
	area.position = Vector3(0.0, 0.48, 0.78)
	area.set_script(HIDE_SCRIPT)
	area.set_meta("hide_style", "under_bed")
	area.set_meta("display_name", "Bersembunyi di bawah kasur")

	var collision := CollisionShape3D.new()
	collision.name = "InteractionShape"
	var sphere := SphereShape3D.new()
	sphere.radius = 0.95
	collision.shape = sphere
	area.add_child(collision)
	bed.add_child(area)


func _is_tall_hide_candidate(node: Node3D) -> bool:
	var valid_names := ["Cupboard", "Cabinet", "Wardrobe", "Locker", "Closet", "Lemari"]
	if not valid_names.has(String(node.name)):
		return false

	var collision_root := node.get_node_or_null("FurnitureCollision")
	if collision_root == null:
		collision_root = node.get_node_or_null("Collision")

	var shape: CollisionShape3D = null
	if collision_root != null:
		shape = _find_collision_shape(collision_root)
	else:
		shape = node.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape == null:
			shape = node.get_node_or_null("FurnitureCollisionShape") as CollisionShape3D

	if shape == null or not shape.shape is BoxShape3D:
		return false
	var box := shape.shape as BoxShape3D
	return box.size.y >= 2.0


func _find_collision_shape(node: Node) -> CollisionShape3D:
	for child in node.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
		var nested := _find_collision_shape(child)
		if nested != null:
			return nested
	return null


func _attach_hiding_spots(cabinet: Node3D) -> void:
	if cabinet.get_node_or_null("Map58HideSpotFront") != null:
		return

	var offsets := [Vector3(0.72, 1.15, 0.0), Vector3(-0.72, 1.15, 0.0)]
	for i in range(offsets.size()):
		var area := Area3D.new()
		area.name = "Map58HideSpotFront" + str(i + 1)
		area.position = offsets[i]
		area.set_script(HIDE_SCRIPT)

		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var sphere := SphereShape3D.new()
		sphere.radius = 0.70
		collision.shape = sphere
		area.add_child(collision)
		cabinet.add_child(area)
		area.set_meta("display_name", "Tempat Persembunyian " + String(cabinet.name))


func _attach_crate_hiding(crate: Node3D) -> void:
	if crate.get_node_or_null("Map58CrateHiding") != null:
		return
	var area := Area3D.new()
	area.name = "Map58CrateHiding"
	area.set_script(CRATE_HIDE_SCRIPT)
	var collision := CollisionShape3D.new()
	collision.name = "InteractionShape"
	var sphere := SphereShape3D.new()
	sphere.radius = 2.0
	collision.shape = sphere
	area.add_child(collision)
	crate.add_child(area)
	area.set_meta("hide_style", "crate")
	area.set_meta("display_name", "Bersembunyi di dalam peti")
