extends Node3D

@export var open_distance: float = 4.6
@export var animation_duration: float = 0.35
@export var use_map_wall: bool = false
@export var required_item_type: String = ""

@onready var door_slide: AnimatableBody3D = $DoorPivot

var _is_open := false
var _closed_x := 0.0
var _open_x := 0.0
var _tween: Tween
var _opening_for_teacher := false


func _ready() -> void:
	add_to_group("doors")
	if door_slide == null:
		push_error("PintuKelas: DoorPivot tidak ditemukan.")
		return

	var wall_above := get_node_or_null("WallAboveDoor") as MeshInstance3D
	if wall_above != null:
		wall_above.visible = not use_map_wall

	set_meta("locked", not required_item_type.is_empty())
	set_meta("required_item_type", required_item_type)
	_closed_x = door_slide.position.x


func interact(player: Node = null) -> void:
	if door_slide == null:
		return

	if not required_item_type.is_empty():
		# Guru boleh membuka pintu untuk patroli; murid tetap perlu kunci.
		if not _is_teacher_actor(player):
			if player == null:
				return

			var inventory := player.get_node_or_null("ItemInventory")
			if inventory == null or not inventory.has_item(required_item_type):
				_set_locked_status(player)
				return
			if not _is_open:
				var key_audio := get_tree().get_first_node_in_group("game_audio")
				if key_audio != null and key_audio.has_method("play_sfx"):
					key_audio.play_sfx("key_unlock", global_position)

	if _tween != null:
		_tween.kill()

	# Semua pintu selalu bergeser ke arah X positif, termasuk saat dibuka guru.
	var opening_offset := absf(open_distance)

	var target_x := _closed_x + (
		opening_offset
		if not _is_open
		else 0.0
	)
	if not _is_open:
		_open_x = target_x
		_opening_for_teacher = _is_teacher_actor(player)

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(
		door_slide,
		"position:x",
		target_x,
		animation_duration
	)

	var audio := get_tree().get_first_node_in_group("game_audio")
	var door_sound := "door_open" if not _is_open else "door_close"
	if audio != null:
		if audio.has_method("play_sfx_for_duration"):
			audio.play_sfx_for_duration(door_sound, animation_duration, global_position)
		elif audio.has_method("play_sfx"):
			audio.play_sfx(door_sound, global_position)

	_is_open = not _is_open


func is_open() -> bool:
	return _is_open


func is_fully_open() -> bool:
	# Status logis berubah saat interaksi dimulai, tetapi daun pintu masih
	# bergerak selama tween. Guru baru boleh melewati pintu setelah animasi
	# selesai dan collider sudah mencapai posisi terbuka.
	if not _is_open or door_slide == null:
		return false
	if _tween != null and _tween.is_running():
		return false
	return absf(door_slide.position.x - _open_x) <= 0.08


func is_transitioning() -> bool:
	return _tween != null and _tween.is_running()


func is_locked() -> bool:
	return not required_item_type.is_empty()


func can_teacher_open() -> bool:
	return true


func _is_teacher_actor(player: Node) -> bool:
	return player != null and player.is_in_group("teacher")


func _set_locked_status(player: Node) -> void:
	var message := "Pintu terkunci. Diperlukan: " + _item_name(required_item_type)
	var mobile_controls := player.get_node_or_null("MobileControls")
	if mobile_controls != null and mobile_controls.has_method("is_mobile") and bool(mobile_controls.call("is_mobile")):
		if mobile_controls.has_method("show_notification"):
			mobile_controls.call("show_notification", message)
		return
	var ui := get_tree().root.find_child("UIManager", true, false)
	if ui != null and ui.has_method("show_notification"):
		ui.call("show_notification", message)


func _item_name(item_type: String) -> String:
	match item_type:
		"class_key":
			return "Kunci Kelas"
		"red_key":
			return "Kunci Merah"
		"blue_key":
			return "Kunci Biru"
		"yellow_key":
			return "Kunci Kuning"
		_:
			return item_type


func set_locked(locked: bool) -> void:
	if locked:
		if required_item_type.is_empty():
			required_item_type = "class_key"
	else:
		required_item_type = ""

	set_meta("locked", locked)
	set_meta("required_item_type", required_item_type)
