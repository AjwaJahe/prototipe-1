extends Node3D

# Test scene only. Map58 and the real Player files are not modified.
const INTERACT_DISTANCE := 6.0
const MAX_INVENTORY_SLOTS := 2
const HEAL_DURATION := 2.0
const BOARD_FRONT_Z := 0.081

@onready var player_body: CharacterBody3D = $Player/CharacterBody3D
@onready var camera: Camera3D = $Player/CharacterBody3D/Camera3D
@onready var board: StaticBody3D = $TestObjects/Blackboard
@onready var door: Node3D = $TestObjects/Door
@onready var door_collision: CollisionShape3D = $TestObjects/Door/CollisionShape3D
@onready var hide_spot: StaticBody3D = $TestObjects/HidingSpot
@onready var downed_friend: StaticBody3D = $TestObjects/DownedFriend

@onready var status_label: Label = $UI/TopLeft/Status
@onready var prompt_label: Label = $UI/CenterPrompt
@onready var held_label: Label = $UI/HeldItem
@onready var capacity_label: Label = $UI/BottomInventory/Capacity
@onready var progress_label: Label = $UI/HealProgress

var inventory: Array[String] = []
var selected_index := -1
var drawing := false
var drawing_has_points := false
var previous_board_point := Vector3.ZERO
var healing := false
var heal_elapsed := 0.0
var door_open := false
var is_hiding := false
var mouse_ui_mode := false
var next_draw_material: StandardMaterial3D
var slot_buttons: Array[Button] = []

const ITEM_DISPLAY := {
	"paper": "Kertas Soal",
	"chalk": "Kapur",
	"medkit": "Medkit",
}

const ITEM_SHORT := {
	"paper": "KERTAS",
	"chalk": "KAPUR",
	"medkit": "MEDKIT",
}

func _ready() -> void:
	next_draw_material = StandardMaterial3D.new()
	next_draw_material.albedo_color = Color(0.95, 0.95, 0.95)
	next_draw_material.roughness = 0.9

	for i in range(MAX_INVENTORY_SLOTS):
		var button := $UI/BottomInventory/Slots.get_child(i) as Button
		slot_buttons.append(button)
		button.pressed.connect(_on_slot_pressed.bind(i))

	progress_label.visible = false
	_set_ui_mouse_mode(true)
	_update_inventory_ui()
	_set_status("Test baru: interaksi berhenti pada objek terdekat. Pintu tertutup akan memblokir item di belakangnya.")

func _process(delta: float) -> void:
	_update_prompt()

	if drawing:
		_process_drawing()

	if healing:
		heal_elapsed += delta
		progress_label.text = "MENYEMBUHKAN %d%%" % int(clamp(heal_elapsed / HEAL_DURATION, 0.0, 1.0) * 100.0)
		if heal_elapsed >= HEAL_DURATION:
			_finish_heal()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_set_ui_mouse_mode(not mouse_ui_mode)
			return
		if event.keycode == KEY_1 or event.keycode == KEY_2:
			_select_slot(event.keycode - KEY_1)
			return
		if event.keycode == KEY_P:
			_drop_selected()
			return

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Saat mouse sedang dipakai untuk UI, klik pada HUD tidak boleh menjalankan 3D interaction.
		if mouse_ui_mode and _mouse_over_ui(event.position):
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_left_press()
			else:
				_left_release()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_right_press()
			else:
				_right_release()

func _left_press() -> void:
	if mouse_ui_mode:
		_set_ui_mouse_mode(false)

	var target := _get_interaction_target()
	if target == null:
		_set_status("Tidak ada objek yang bisa diinteraksikan tepat di depanmu.")
		return

	var kind := String(target.get_meta("interaction_type", ""))
	match kind:
		"item":
			_pick_item(target)
		"door":
			_toggle_door()
		"blackboard":
			_start_drawing()
		_:
			_set_status("Objek ditemukan, tetapi belum memiliki aksi test.")

func _left_release() -> void:
	if not drawing:
		return

	drawing = false
	if drawing_has_points:
		_remove_one_item("paper")
		_remove_one_item("chalk")
		_select_valid_slot_after_inventory_change()
		_update_inventory_ui()
		_set_status("Jawaban test selesai. 1 kertas + 1 kapur digunakan.")
	else:
		_set_status("Belum ada goresan, jadi kertas dan kapur tidak digunakan.")

func _right_press() -> void:
	var target := _get_interaction_target()
	if target == null:
		_set_status("Klik kanan tidak melakukan apa-apa di sini.")
		return

	var kind := String(target.get_meta("interaction_type", ""))
	match kind:
		"hiding":
			is_hiding = not is_hiding
			_set_status("Kamu sekarang %s di tempat persembunyian." % ("bersembunyi" if is_hiding else "keluar dari persembunyian"))
		"downed_friend":
			if _get_selected_item() != "medkit":
				_set_status("Pilih Medkit di inventory terlebih dahulu.")
				return
			if bool(target.get_meta("healed", false)):
				_set_status("Teman ini sudah disembuhkan.")
				return
			healing = true
			heal_elapsed = 0.0
			progress_label.visible = true
			progress_label.text = "MENYEMBUHKAN 0%"
			_set_status("Tahan klik kanan sampai selesai.")
		_:
			_set_status("Klik kanan tidak melakukan apa-apa pada objek ini.")

func _right_release() -> void:
	if healing:
		healing = false
		progress_label.visible = false
		if heal_elapsed < HEAL_DURATION:
			_set_status("Penyembuhan dibatalkan.")

func _start_drawing() -> void:
	if _get_selected_item() != "paper":
		_set_status("Pilih Kertas Soal terlebih dahulu.")
		return
	if not inventory.has("chalk"):
		_set_status("Tidak punya kapur. Ambil kapur terlebih dahulu.")
		return

	drawing = true
	drawing_has_points = false
	previous_board_point = Vector3.ZERO
	_set_status("Menggambar di papan tulis... tahan klik kiri dan gerakkan pandangan.")

func _process_drawing() -> void:
	var hit := _raycast_from_camera()
	if hit.is_empty():
		return

	var target := _find_interaction_node(hit.collider)
	if target != board:
		return

	var local_point: Vector3 = board.global_transform.affine_inverse() * hit.position
	local_point.z = BOARD_FRONT_Z

	if not drawing_has_points:
		previous_board_point = local_point
		drawing_has_points = true
		return

	if previous_board_point.distance_to(local_point) < 0.025:
		return

	_draw_board_segment(previous_board_point, local_point)
	previous_board_point = local_point

func _draw_board_segment(a: Vector3, b: Vector3) -> void:
	var segment := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var length := a.distance_to(b)
	mesh.size = Vector3(length, 0.035, 0.02)
	segment.mesh = mesh
	segment.material_override = next_draw_material
	segment.position = (a + b) * 0.5
	segment.rotation.z = atan2(b.y - a.y, b.x - a.x)
	board.add_child(segment)

func _pick_item(target: Node) -> void:
	if inventory.size() >= MAX_INVENTORY_SLOTS:
		_set_status("Inventory penuh: %d/%d slot. Buang salah satu item terlebih dahulu." % [inventory.size(), MAX_INVENTORY_SLOTS])
		return

	var item_type := String(target.get_meta("item_type", ""))
	if not ITEM_DISPLAY.has(item_type):
		_set_status("Item test tidak dikenali.")
		return

	inventory.append(item_type)
	target.queue_free()
	selected_index = inventory.size() - 1
	_update_inventory_ui()
	_set_status("%s diambil dan dipilih." % ITEM_DISPLAY[item_type])

func _drop_selected() -> void:
	var selected_item := _get_selected_item()
	if selected_item == "":
		_set_status("Tidak ada item yang dipilih untuk dibuang.")
		return

	_spawn_dropped_item(selected_item)
	inventory.remove_at(selected_index)
	_select_valid_slot_after_inventory_change()
	_update_inventory_ui()
	_set_status("%s dibuang." % ITEM_DISPLAY[selected_item])

func _spawn_dropped_item(item_type: String) -> void:
	var body := StaticBody3D.new()
	body.name = "Dropped_" + ITEM_SHORT[item_type]
	body.set_meta("interaction_type", "item")
	body.set_meta("item_type", item_type)

	var mesh_instance := MeshInstance3D.new()
	var collision := CollisionShape3D.new()

	match item_type:
		"paper":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.8, 0.05, 1.1)
			mesh_instance.mesh = mesh
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.8, 0.05, 1.1)
			collision.shape = shape
			mesh_instance.material_override = _make_material(Color(0.95, 0.92, 0.78))
		"chalk":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.18, 0.18, 0.65)
			mesh_instance.mesh = mesh
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.18, 0.18, 0.65)
			collision.shape = shape
			mesh_instance.material_override = _make_material(Color(0.88, 0.88, 0.84))
		"medkit":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.7, 0.4, 0.45)
			mesh_instance.mesh = mesh
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.7, 0.4, 0.45)
			collision.shape = shape
			mesh_instance.material_override = _make_material(Color(0.72, 0.20, 0.20))

	body.add_child(mesh_instance)
	body.add_child(collision)
	add_child(body)

	var drop_position := player_body.global_position + (-player_body.global_transform.basis.z * 1.5)
	drop_position.y = 0.45
	body.global_position = drop_position

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _toggle_door() -> void:
	door_open = not door_open
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(door, "rotation_degrees:y", -90.0 if door_open else 0.0, 0.3)
	door_collision.disabled = door_open
	_set_status("Pintu test %s. Saat tertutup, pintu memblokir interaksi dengan benda di belakangnya." % ("terbuka" if door_open else "tertutup"))

func _finish_heal() -> void:
	healing = false
	progress_label.visible = false
	_remove_one_item("medkit")
	_select_valid_slot_after_inventory_change()
	downed_friend.set_meta("healed", true)
	var friend_label := downed_friend.get_node_or_null("Label3D") as Label3D
	if friend_label:
		friend_label.text = "TEMAN\nSUDAH DISEMBUHKAN"
	_update_inventory_ui()
	_set_status("Teman berhasil disembuhkan. 1 medkit digunakan.")

func _update_prompt() -> void:
	var target := _get_interaction_target()
	if target == null:
		prompt_label.text = ""
		return

	var kind := String(target.get_meta("interaction_type", ""))
	match kind:
		"item":
			var item_type := String(target.get_meta("item_type", ""))
			prompt_label.text = "[KLIK KIRI] Ambil %s" % ITEM_DISPLAY.get(item_type, "item")
		"door":
			prompt_label.text = "[KLIK KIRI] Buka / tutup pintu"
		"blackboard":
			prompt_label.text = "[TAHAN KLIK KIRI] Gambar jawaban"
		"hiding":
			prompt_label.text = "[KLIK KANAN] Bersembunyi / keluar"
		"downed_friend":
			prompt_label.text = "[TAHAN KLIK KANAN] Sembuhkan teman"
		_:
			prompt_label.text = ""

func _update_inventory_ui() -> void:
	for i in range(MAX_INVENTORY_SLOTS):
		var button := slot_buttons[i]
		if i < inventory.size():
			var type := inventory[i]
			button.text = "%d\n%s" % [i + 1, ITEM_SHORT[type]]
			button.disabled = false
			button.modulate = Color(1.0, 1.0, 1.0) if i != selected_index else Color(1.0, 0.88, 0.45)
		else:
			button.text = "%d\n—" % [i + 1]
			button.disabled = true
			button.modulate = Color(0.55, 0.55, 0.55)

	capacity_label.text = "SLOT %d/%d" % [inventory.size(), MAX_INVENTORY_SLOTS]
	var selected_item := _get_selected_item()
	held_label.text = "DIPAKAI: %s" % (ITEM_DISPLAY[selected_item].to_upper() if selected_item != "" else "KOSONG")

func _on_slot_pressed(index: int) -> void:
	_select_slot(index)
	_set_ui_mouse_mode(false)

func _select_slot(index: int) -> void:
	if index < 0 or index >= inventory.size():
		return
	selected_index = index
	_update_inventory_ui()
	_set_status("Dipilih: %s." % ITEM_DISPLAY[inventory[index]])

func _select_valid_slot_after_inventory_change() -> void:
	if inventory.is_empty():
		selected_index = -1
		return
	if selected_index < 0:
		selected_index = 0
	elif selected_index >= inventory.size():
		selected_index = inventory.size() - 1

func _get_selected_item() -> String:
	if selected_index < 0 or selected_index >= inventory.size():
		return ""
	return inventory[selected_index]

func _remove_one_item(item_type: String) -> bool:
	var index := inventory.find(item_type)
	if index == -1:
		return false
	inventory.remove_at(index)
	if index < selected_index:
		selected_index -= 1
	elif index == selected_index and selected_index >= inventory.size():
		selected_index = inventory.size() - 1
	return true

func _set_status(message: String) -> void:
	status_label.text = message

func _set_ui_mouse_mode(show_ui_mouse: bool) -> void:
	mouse_ui_mode = show_ui_mouse
	if mouse_ui_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player_body.set_process_unhandled_input(false)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player_body.set_process_unhandled_input(true)

func _mouse_over_ui(position: Vector2) -> bool:
	var controls := [
		$UI/BottomInventory/Slots,
	]
	for control in controls:
		if control.get_global_rect().has_point(position):
			return true
	return false

func _get_interaction_target() -> Node:
	var hit := _raycast_from_camera()
	if hit.is_empty():
		return null
	# Hanya collider pertama yang kena ray yang boleh diinteraksikan.
	# Ini mencegah mengambil item menembus pintu/dinding.
	return _find_interaction_node(hit.collider)

func _raycast_from_camera() -> Dictionary:
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * INTERACT_DISTANCE)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [player_body.get_rid()]
	return player_body.get_world_3d().direct_space_state.intersect_ray(query)

func _find_interaction_node(node: Node) -> Node:
	var current := node
	while current != null:
		if current.has_meta("interaction_type"):
			return current
		current = current.get_parent()
	return null
