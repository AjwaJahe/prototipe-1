extends Node3D
## Lemari persembunyian kelas. Dipasang hanya pada node Cupboard di scene furnitur kelas.
## Klik kanan masuk/keluar; pintu bergerak dan player disimpan di dalam lemari.

const DOOR_OPEN_ANGLE := 1.05
const DOOR_PEEK_ANGLE := 0.10
const DOOR_ANIM_TIME := 0.38

var _player: CharacterBody3D
var _saved_transform: Transform3D
var _saved_camera_position := Vector3.ZERO
var _saved_camera_rotation := Vector3.ZERO
var _saved_physics_process := true
var _busy := false
var _hidden := false
var _left_pivot: Node3D
var _right_pivot: Node3D
var _door_material: StandardMaterial3D
var _highlight_material: StandardMaterial3D
var _highlight_meshes: Array[MeshInstance3D] = []


func configure() -> void:
	if get_meta("class_cupboard_configured", false):
		return
	set_meta("class_cupboard_configured", true)
	set_meta("interaction_type", "hiding")
	add_to_group("map58_classroom_cupboard")

	# Hide the old open-shelf model; build a closed, hollow wooden cabinet instead.
	for child_name in ["Body", "Shelf_01", "Shelf_02", "Shelf_03"]:
		var old_mesh := get_node_or_null(child_name) as MeshInstance3D
		if old_mesh != null:
			old_mesh.visible = false

	var collision := get_node_or_null("FurnitureCollision/CollisionShape3D") as CollisionShape3D
	if collision != null and collision.shape is BoxShape3D:
		var box := collision.shape as BoxShape3D
		box.size = Vector3(1.40, 3.00, 2.20)
		collision.position = Vector3(0.0, 1.50, 0.0)

	_door_material = _make_material(Color(0.24, 0.105, 0.035), 0.84)
	_highlight_material = _make_material(Color(0.72, 0.46, 0.18), 0.45)
	_build_shell()
	_build_doors()
	_build_interaction_glow()


func _build_shell() -> void:
	_add_box("BackPanel", Vector3(0.12, 2.92, 2.10), Vector3(-0.64, 1.46, 0.0), _door_material)
	_add_box("SidePanelLeft", Vector3(1.30, 2.92, 0.12), Vector3(0.0, 1.46, -0.99), _door_material)
	_add_box("SidePanelRight", Vector3(1.30, 2.92, 0.12), Vector3(0.0, 1.46, 0.99), _door_material)
	_add_box("TopPanel", Vector3(1.32, 0.12, 2.10), Vector3(0.0, 2.86, 0.0), _door_material)
	_add_box("BottomPanel", Vector3(1.32, 0.12, 2.10), Vector3(0.0, 0.06, 0.0), _door_material)
	_add_box("InteriorShelf1", Vector3(1.10, 0.055, 1.88), Vector3(-0.02, 1.00, 0.0), _door_material)
	_add_box("InteriorShelf2", Vector3(1.10, 0.055, 1.88), Vector3(-0.02, 1.95, 0.0), _door_material)


func _build_doors() -> void:
	_left_pivot = Node3D.new()
	_left_pivot.name = "DoorLeftPivot"
	_left_pivot.position = Vector3(0.66, 1.46, -1.04)
	add_child(_left_pivot)
	var left_door := _add_box_to(_left_pivot, "DoorLeft", Vector3(0.09, 2.76, 1.00), Vector3(0.0, 0.0, 0.50), _door_material)
	_add_box_to(_left_pivot, "DoorLeftInset", Vector3(0.022, 2.30, 0.70), Vector3(0.055, 0.0, 0.50), _make_material(Color(0.31, 0.15, 0.055), 0.8))
	_add_box_to(_left_pivot, "DoorLeftHandle", Vector3(0.065, 0.28, 0.055), Vector3(0.075, 0.0, 0.82), _make_material(Color(0.48, 0.43, 0.30), 0.35, 0.55))

	_right_pivot = Node3D.new()
	_right_pivot.name = "DoorRightPivot"
	_right_pivot.position = Vector3(0.66, 1.46, 1.04)
	add_child(_right_pivot)
	_add_box_to(_right_pivot, "DoorRight", Vector3(0.09, 2.76, 1.00), Vector3(0.0, 0.0, -0.50), _door_material)
	_add_box_to(_right_pivot, "DoorRightInset", Vector3(0.022, 2.30, 0.70), Vector3(0.055, 0.0, -0.50), _make_material(Color(0.31, 0.15, 0.055), 0.8))
	_add_box_to(_right_pivot, "DoorRightHandle", Vector3(0.065, 0.28, 0.055), Vector3(0.075, 0.0, -0.82), _make_material(Color(0.48, 0.43, 0.30), 0.35, 0.55))


func _build_interaction_glow() -> void:
	var outline := _add_box("InteractionGlow", Vector3(0.03, 2.98, 2.18), Vector3(0.73, 1.46, 0.0), _highlight_material)
	outline.visible = false
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_highlight_meshes.append(outline)


func set_interaction_highlight(enabled: bool) -> void:
	for mesh in _highlight_meshes:
		if is_instance_valid(mesh):
			mesh.visible = enabled and not _hidden


func toggle_hide(player: Node = null) -> void:
	if _busy or not player is CharacterBody3D:
		return
	var character := player as CharacterBody3D
	if _hidden:
		_exit_cabinet(character)
	else:
		_enter_cabinet(character)


func network_set_hiding_visual(hidden: bool) -> void:
	# Animate cabinet doors for another peer without moving or hiding a local player.
	if _busy or _left_pivot == null or _right_pivot == null:
		return
	_busy = true
	_animate_doors(DOOR_OPEN_ANGLE, -DOOR_OPEN_ANGLE, DOOR_ANIM_TIME)
	await get_tree().create_timer(DOOR_ANIM_TIME).timeout
	if not is_instance_valid(self):
		return
	if hidden:
		_animate_doors(DOOR_PEEK_ANGLE, -DOOR_PEEK_ANGLE, 0.22)
	else:
		_animate_doors(0.0, 0.0, 0.22)
	await get_tree().create_timer(0.22).timeout
	if is_instance_valid(self):
		_busy = false


func _enter_cabinet(player: CharacterBody3D) -> void:
	_busy = true
	var audio := get_tree().get_first_node_in_group("game_audio")
	if audio != null:
		if audio.has_method("play_sfx_for_duration"):
			audio.play_sfx_for_duration("cabinet_slide", DOOR_ANIM_TIME, global_position)
		elif audio.has_method("play_sfx"):
			audio.play_sfx("cabinet_slide", global_position)
	_player = player
	_saved_transform = player.global_transform
	_saved_physics_process = player.is_physics_processing()
	var camera := player.get_node_or_null("Camera3D") as Camera3D
	if camera != null:
		_saved_camera_position = camera.position
		_saved_camera_rotation = camera.rotation

	# Open the doors, move the player inside, then leave a narrow viewing gap.
	_animate_doors(DOOR_OPEN_ANGLE, -DOOR_OPEN_ANGLE, DOOR_ANIM_TIME)
	player.velocity = Vector3.ZERO
	player.global_position = to_global(Vector3(-0.04, 0.0, 0.0))
	player.global_rotation = global_rotation + Vector3(0.0, -PI / 2.0, 0.0)
	player.set_meta("is_hidden", true)
	player.set_meta("hide_spot", self)
	player.set_physics_process(false)
	_hidden = true
	set_interaction_highlight(false)
	if camera != null:
		camera.position = Vector3(_saved_camera_position.x, _saved_camera_position.y, _saved_camera_position.z)
		camera.rotation = Vector3(-0.025, 0.0, 0.0)
	_set_status(player, "Kamu bersembunyi di lemari. Klik kanan untuk keluar.")
	var timer := get_tree().create_timer(DOOR_ANIM_TIME)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and _hidden:
			_animate_doors(DOOR_PEEK_ANGLE, -DOOR_PEEK_ANGLE, 0.22)
		_busy = false
	)


func _exit_cabinet(player: CharacterBody3D) -> void:
	_busy = true
	var audio := get_tree().get_first_node_in_group("game_audio")
	if audio != null:
		if audio.has_method("play_sfx_for_duration"):
			audio.play_sfx_for_duration("cabinet_slide", DOOR_ANIM_TIME, global_position)
		elif audio.has_method("play_sfx"):
			audio.play_sfx("cabinet_slide", global_position)
	_animate_doors(DOOR_OPEN_ANGLE, -DOOR_OPEN_ANGLE, DOOR_ANIM_TIME)
	player.set_physics_process(false)
	player.global_transform = _saved_transform
	player.velocity = Vector3.ZERO
	var camera := player.get_node_or_null("Camera3D") as Camera3D
	if camera != null:
		camera.position = _saved_camera_position
		camera.rotation = _saved_camera_rotation
	player.set_meta("is_hidden", false)
	player.set_meta("hide_spot", null)
	_hidden = false
	var was_physics := _saved_physics_process
	var timer := get_tree().create_timer(DOOR_ANIM_TIME)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			_animate_doors(0.0, 0.0, 0.22)
			if is_instance_valid(player):
				player.set_physics_process(was_physics)
				_set_status(player, "Kamu keluar dari lemari.")
		_busy = false
	)


func _animate_doors(left_angle: float, right_angle: float, duration: float) -> void:
	if _left_pivot == null or _right_pivot == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_left_pivot, "rotation:y", left_angle, duration)
	tween.parallel().tween_property(_right_pivot, "rotation:y", right_angle, duration)


func _set_status(player: Node, message: String) -> void:
	var inventory := player.get_node_or_null("ItemInventory")
	if inventory != null and inventory.has_method("_set_status"):
		inventory.call("_set_status", message)


func _make_material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _add_box(node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	return _add_box_to(self, node_name, size, position, material)


func _add_box_to(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

