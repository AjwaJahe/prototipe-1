extends Node3D

const CLOSED_ANGLE := 0.0
# Cabinet front faces -Z: the left door must swing toward -Z, not into +Z.
const LEFT_OPEN_ANGLE := 1.12
const RIGHT_OPEN_ANGLE := -1.12
const ANIMATION_DURATION := 0.42

var _is_open := false
var _busy := false

@onready var _left_pivot: Node3D = get_node_or_null("CabinetModel/DoorLeftPivot")
@onready var _right_pivot: Node3D = get_node_or_null("CabinetModel/DoorRightPivot")


func configure() -> void:
	set_meta("interaction_type", "cabinet")
	add_to_group("map58_interactive_cabinet")


func interact(player: Node = null) -> void:
	if _busy or _left_pivot == null or _right_pivot == null:
		push_warning("UKSCabinet: pivot pintu tidak ditemukan; interaksi dibatalkan.")
		return
	_busy = true
	_is_open = not _is_open
	var audio := get_tree().get_first_node_in_group("game_audio")
	if audio != null:
		if audio.has_method("play_sfx_for_duration"):
			audio.play_sfx_for_duration("cabinet_slide", ANIMATION_DURATION, global_position)
		elif audio.has_method("play_sfx"):
			audio.play_sfx("cabinet_slide", global_position)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var target_left := LEFT_OPEN_ANGLE if _is_open else CLOSED_ANGLE
	var target_right := RIGHT_OPEN_ANGLE if _is_open else CLOSED_ANGLE
	tween.parallel().tween_property(_left_pivot, "rotation:y", target_left, ANIMATION_DURATION)
	tween.parallel().tween_property(_right_pivot, "rotation:y", target_right, ANIMATION_DURATION)
	tween.finished.connect(func() -> void: _busy = false)
	_set_status(player, "Lemari UKS dibuka." if _is_open else "Lemari UKS ditutup.")


func _set_status(player: Node, message: String) -> void:
	if player == null:
		return
	var inventory := player.get_node_or_null("ItemInventory")
	if inventory != null and inventory.has_method("_set_status"):
		inventory.call("_set_status", message)
