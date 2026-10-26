extends Node3D

@export var open_angle_degrees: float = 95.0
@export var animation_duration: float = 0.35
@export var locked: bool = true

@onready var left_pivot: AnimatableBody3D = $LeftDoorPivot
@onready var right_pivot: AnimatableBody3D = $RightDoorPivot

var _is_open := false
var _tween: Tween
var _escape_player_sides: Dictionary = {}


func _ready() -> void:
	add_to_group("doors")
	set_meta("locked", locked)
	set_process(true)


func _process(_delta: float) -> void:
	# Kemenangan hanya dipicu ketika player benar-benar menyeberangi bidang
	# pintu utama dari sisi tempat ia berada saat 10 soal selesai.
	var game := get_node_or_null("../../GameManager")
	if game == null or String(game.get("phase")) != "ESCAPE_READY":
		_escape_player_sides.clear()
		return
	if locked or not _is_open:
		return
	if _tween != null and _tween.is_running():
		return

	var players := get_tree().get_nodes_in_group("players")
	for candidate in players:
		var player := candidate as Node3D
		if player == null or not is_instance_valid(player):
			continue
		var local_position := to_local(player.global_position)
		# Pintu lebar 15.5 unit; batasi trigger agar tidak aktif dari sisi frame.
		if absf(local_position.x) > 7.4 or local_position.y < -0.1 or local_position.y > 9.5:
			continue
		var side := signf(local_position.z)
		var player_id := player.get_instance_id()
		if not _escape_player_sides.has(player_id):
			# Rekam sisi asal sejak player berada jelas di salah satu sisi ambang,
			# bukan baru setelah ia menjauh dari bidang pintu.
			if absf(local_position.z) > 0.2:
				_escape_player_sides[player_id] = side
			continue
		var origin_side := float(_escape_player_sides[player_id])
		if absf(local_position.z) >= 0.85 and side != origin_side:
			if game.has_method("complete_escape") and bool(game.call("complete_escape", player)):
				_escape_player_sides.clear()
				return


func interact(player: Node = null) -> void:
	# Gerbang hanya dapat dibuka oleh guru setelah 10 soal benar.
	if player == null:
		return
	if not player.is_in_group("teacher"):
		if locked:
			_show_locked_notice(player)
		return
	if locked or left_pivot == null or right_pivot == null:
		return
	if _tween != null and _tween.is_running():
		return

	var opening := not _is_open
	var left_target := deg_to_rad(-open_angle_degrees) if opening else 0.0
	var right_target := deg_to_rad(open_angle_degrees) if opening else 0.0

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_parallel(true)
	_tween.tween_property(left_pivot, "rotation:y", left_target, animation_duration)
	_tween.tween_property(right_pivot, "rotation:y", right_target, animation_duration)
	_tween.set_parallel(false)
	_tween.tween_callback(func() -> void:
		_is_open = opening
	)

	var audio := get_tree().get_first_node_in_group("game_audio")
	var sound_name := "door_open" if opening else "door_close"
	if audio != null:
		if audio.has_method("play_sfx_for_duration"):
			audio.play_sfx_for_duration(sound_name, animation_duration, global_position)
		elif audio.has_method("play_sfx"):
			audio.play_sfx(sound_name, global_position)


func _show_locked_notice(player: Node) -> void:
	var message := "Pintu utama masih terkunci. Selesaikan 10 soal terlebih dahulu."
	var mobile_controls := player.get_node_or_null("MobileControls")
	if mobile_controls != null and mobile_controls.has_method("is_mobile") and bool(mobile_controls.call("is_mobile")):
		if mobile_controls.has_method("show_notification"):
			mobile_controls.call("show_notification", message)
		return
	var ui := get_tree().root.find_child("UIManager", true, false)
	if ui != null and ui.has_method("show_notification"):
		ui.call("show_notification", message)


func is_open() -> bool:
	return _is_open


func is_transitioning() -> bool:
	return _tween != null and _tween.is_running()


func is_fully_open() -> bool:
	return _is_open and not is_transitioning()


func is_locked() -> bool:
	return locked


func set_locked(value: bool) -> void:
	locked = value
	set_meta("locked", locked)
