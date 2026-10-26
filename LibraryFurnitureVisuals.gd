extends Node3D
## Rebuilds library furniture as a single consistent set of lightweight primitives.
## Existing room layout is preserved; only children of FurnitureRoot are replaced.

var _wood: StandardMaterial3D
var _wood_dark: StandardMaterial3D
var _shelf_back: StandardMaterial3D
var _book_mats: Array[StandardMaterial3D] = []
var _metal: StandardMaterial3D
var _paper: StandardMaterial3D

func _ready() -> void:
	call_deferred("_rebuild_library")

func _rebuild_library() -> void:
	var root := get_node_or_null("FurnitureRoot") as Node3D
	if root == null:
		push_error("LibraryFurnitureVisuals: FurnitureRoot tidak ditemukan.")
		return
	# Rebuild in small, testable stages. Stage 1: one double-sided shelf only.
	for child in root.get_children():
		root.remove_child(child)
		child.free()
	_create_materials()
	_build_shelf(root, "Shelf_Test_DoubleSided", Vector3(-13.0, 0.0, -9.7), true, 0)
	print("LibraryFurnitureVisuals: tahap 1 selesai — satu rak dua sisi dibuat.")

func _create_materials() -> void:
	_wood = _material(Color(0.32, 0.17, 0.075), 0.86)
	_wood_dark = _material(Color(0.16, 0.075, 0.035), 0.9)
	_shelf_back = _material(Color(0.23, 0.12, 0.055), 0.92)
	_metal = _material(Color(0.58, 0.42, 0.19), 0.35, 0.65)
	_paper = _material(Color(0.79, 0.71, 0.54), 0.95)
	_book_mats.clear()
	for color in [
		Color(0.46, 0.09, 0.07), Color(0.08, 0.23, 0.20),
		Color(0.11, 0.19, 0.39), Color(0.55, 0.34, 0.10),
		Color(0.32, 0.13, 0.34), Color(0.67, 0.62, 0.45),
		Color(0.18, 0.29, 0.13)
	]:
		_book_mats.append(_material(color, 0.82))

func _material(color: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

func _box(parent: Node3D, label: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	item.mesh = mesh
	item.position = pos
	parent.add_child(item)
	return item

func _add_box_collision(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = pos
	parent.add_child(collision)

func _build_shelf(root: Node3D, label: String, pos: Vector3, along_left_wall: bool, pattern: int) -> void:
	var shelf := Node3D.new()
	shelf.name = label
	shelf.position = pos
	if along_left_wall:
		shelf.rotation.y = PI * 0.5
	root.add_child(shelf)

	var width := 5.55
	var height := 3.35
	var depth := 0.62
	# No rear panel or center spine: both sides stay fully accessible.
	_box(shelf, "LeftUpright", Vector3(-width * 0.5 + 0.07, height * 0.5, 0), Vector3(0.14, height, depth), _wood_dark)
	_box(shelf, "RightUpright", Vector3(width * 0.5 - 0.07, height * 0.5, 0), Vector3(0.14, height, depth), _wood_dark)
	_box(shelf, "TopCap", Vector3(0, height - 0.07, 0), Vector3(width, 0.14, depth), _wood)
	_box(shelf, "BottomPlinth", Vector3(0, 0.12, 0), Vector3(width, 0.24, depth), _wood)
	for level in range(4):
		var y := 0.28 + float(level) * 0.72
		_box(shelf, "ShelfBoard_%d" % level, Vector3(0, y, 0), Vector3(width - 0.18, 0.09, depth), _wood)

	# Every rack gets a different arrangement: tightly packed, leaning, gaps,
	# short horizontal stacks, or mixed-height groups. All books fit the bays.
	# Physical collision for the frame and boards; book meshes remain visual-only.
	var solid := StaticBody3D.new()
	solid.name = "ShelfCollision"
	shelf.add_child(solid)
	_add_box_collision(solid, Vector3(-width * 0.5 + 0.07, height * 0.5, 0), Vector3(0.14, height, depth))
	_add_box_collision(solid, Vector3(width * 0.5 - 0.07, height * 0.5, 0), Vector3(0.14, height, depth))
	_add_box_collision(solid, Vector3(0, 0.12, 0), Vector3(width, 0.24, depth))
	for level in range(4):
		var board_y := 0.28 + float(level) * 0.72
		_add_box_collision(solid, Vector3(0, board_y, 0), Vector3(width - 0.18, 0.09, depth))

	for level in range(4):
		var y := 0.34 + float(level) * 0.72
		var x := -2.48
		var book_index := 0
		while x < 2.38:
			var w := 0.16 + float((book_index + pattern) % 3) * 0.035
			var h := 0.34 + float((book_index * 3 + pattern + level) % 5) * 0.055
			var gap := 0.025
			if pattern == 1 and book_index % 5 == 2:
				gap += 0.16
			elif pattern == 2 and book_index % 4 == 0:
				gap += 0.08
			elif pattern == 3 and book_index % 6 == 3:
				# A short horizontal stack in this bay.
				_box(shelf, "BookStack_%d_%d_Front" % [level, book_index], Vector3(x + 0.11, y + 0.07, -0.18), Vector3(0.36, 0.12, 0.20), _book_mats[(book_index + pattern) % _book_mats.size()])
				_box(shelf, "BookStack_%d_%d_Back" % [level, book_index], Vector3(x + 0.11, y + 0.07, 0.18), Vector3(0.36, 0.12, 0.20), _book_mats[(book_index + pattern + 2) % _book_mats.size()])
				x += 0.40 + gap
				book_index += 1
				continue
			var book := _box(shelf, "Book_%d_%d" % [level, book_index], Vector3(x + w * 0.5, y + h * 0.5, -0.20), Vector3(w, h, 0.20), _book_mats[(book_index * 2 + pattern + level) % _book_mats.size()])
			if pattern == 1 and book_index % 4 == 1:
				book.rotation.z = deg_to_rad(7.0)
			elif pattern == 2 and book_index % 3 == 0:
				book.rotation.z = deg_to_rad(-5.0)
			elif pattern == 4 and book_index % 5 == 0:
				book.rotation.z = deg_to_rad(4.0)
			# Matching book on the reverse face; independent transforms keep both sides legible.
			var reverse_book := _box(shelf, "BookBack_%d_%d" % [level, book_index], Vector3(x + w * 0.5, y + h * 0.5, 0.20), Vector3(w, h, 0.20), _book_mats[(book_index * 3 + pattern + level + 1) % _book_mats.size()])
			if pattern == 1 and book_index % 4 == 2:
				reverse_book.rotation.z = deg_to_rad(-6.0)
			elif pattern == 3 and book_index % 5 == 1:
				reverse_book.rotation.z = deg_to_rad(5.0)
			x += w + gap
			book_index += 1

func _build_computer_desk(root: Node3D, label: String, pos: Vector3, index: int) -> void:
	var desk := Node3D.new()
	desk.name = label
	desk.position = pos
	root.add_child(desk)
	var length := 13.5
	_box(desk, "TableTop", Vector3(0, 0.92, 0), Vector3(length, 0.18, 1.35), _wood)
	for x in [-6.2, -2.1, 2.1, 6.2]:
		for z in [-0.48, 0.48]:
			_box(desk, "Leg_%d_%d" % [int(x * 10), int(z * 10)], Vector3(x, 0.45, z), Vector3(0.14, 0.9, 0.14), _wood_dark)
	# Three integrated drawer fronts along the accessible long edge.
	for i in range(3):
		var x := -4.5 + float(i) * 4.5
		_build_drawer(desk, "Drawer_%d" % (i + 1), Vector3(x, 0.70, 0.53), 1.05)
		_build_computer_and_chair(desk, i + 1, x)

func _build_computer_and_chair(desk: Node3D, number: int, x: float) -> void:
	var screen := _material(Color(0.025, 0.045, 0.055), 0.28, 0.12)
	var screen_glow := _material(Color(0.16, 0.32, 0.36), 0.38)
	var plastic := _material(Color(0.075, 0.08, 0.085), 0.62)
	var computer := Node3D.new()
	computer.name = "Computer_%02d" % number
	computer.position = Vector3(x, 0.0, -0.05)
	desk.add_child(computer)
	_box(computer, "Monitor", Vector3(0, 1.38, -0.12), Vector3(0.92, 0.58, 0.09), screen)
	_box(computer, "ScreenGlow", Vector3(0, 1.39, -0.17), Vector3(0.80, 0.45, 0.012), screen_glow)
	_box(computer, "MonitorStand", Vector3(0, 1.07, -0.12), Vector3(0.12, 0.12, 0.12), plastic)
	_box(computer, "Keyboard", Vector3(0, 1.02, 0.30), Vector3(0.62, 0.035, 0.22), plastic)
	_box(computer, "Mouse", Vector3(0.43, 1.035, 0.30), Vector3(0.09, 0.045, 0.13), plastic)

	var chair := Node3D.new()
	chair.name = "Chair_%02d" % number
	chair.position = Vector3(x, 0.0, 1.55)
	desk.add_child(chair)
	var seat_mat := _material(Color(0.12, 0.13, 0.14), 0.9)
	_box(chair, "Seat", Vector3(0, 0.55, 0), Vector3(0.9, 0.14, 0.78), seat_mat)
	_box(chair, "Back", Vector3(0, 0.98, 0.30), Vector3(0.9, 0.78, 0.14), seat_mat)
	for cx in [-0.34, 0.34]:
		for cz in [-0.28, 0.28]:
			_box(chair, "Leg_%s_%s" % [str(cx), str(cz)], Vector3(cx, 0.25, cz), Vector3(0.09, 0.5, 0.09), _metal)

func _build_reading_table(root: Node3D, label: String, pos: Vector3, add_drawer: bool) -> void:
	var table := Node3D.new()
	table.name = label
	table.position = pos
	root.add_child(table)
	_box(table, "TableTop", Vector3(0, 0.92, 0), Vector3(3.8, 0.18, 2.0), _wood)
	for x in [-1.65, 1.65]:
		for z in [-0.78, 0.78]:
			_box(table, "Leg_%d_%d" % [int(x * 10), int(z * 10)], Vector3(x, 0.45, z), Vector3(0.13, 0.9, 0.13), _wood_dark)
	if add_drawer:
		_build_drawer(table, "Drawer_01", Vector3(0, 0.70, 0.85), 0.95)
	# A small stack of books is dressing only, not an interactive pickup.
	_box(table, "BookStack_Base", Vector3(-0.85, 1.04, -0.25), Vector3(0.72, 0.10, 0.48), _book_mats[2])
	_box(table, "BookStack_Top", Vector3(-0.82, 1.14, -0.25), Vector3(0.62, 0.09, 0.43), _book_mats[0])

func _build_librarian_desk(root: Node3D, label: String, pos: Vector3) -> void:
	var desk := Node3D.new()
	desk.name = label
	desk.position = pos
	root.add_child(desk)
	_box(desk, "Top", Vector3(0, 0.92, 0), Vector3(4.0, 0.18, 1.5), _wood)
	for x in [-1.72, 1.72]:
		for z in [-0.55, 0.55]:
			_box(desk, "Leg_%d_%d" % [int(x * 10), int(z * 10)], Vector3(x, 0.45, z), Vector3(0.16, 0.9, 0.16), _wood_dark)
	_build_drawer(desk, "Drawer_01", Vector3(0, 0.70, 0.60), 1.0)

func _build_drawer(parent: Node3D, label: String, pos: Vector3, width: float) -> void:
	var drawer := Area3D.new()
	drawer.name = label
	drawer.position = pos
	drawer.set_script(load("res://LibraryDrawerInteract.gd"))
	drawer.set_meta("drawer_width", width)
	drawer.collision_layer = 1
	drawer.collision_mask = 1
	parent.add_child(drawer)

	var collision := CollisionShape3D.new()
	collision.name = "InteractionShape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.25, 0.28)
	collision.shape = shape
	collision.position = Vector3(0, 0, 0.06)
	drawer.add_child(collision)
