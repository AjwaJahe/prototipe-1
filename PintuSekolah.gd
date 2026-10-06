extends Node3D

@export var open_angle_degrees: float = 95.0
@export var animation_duration: float = 0.35
@export var locked: bool = true

@onready var left_pivot: AnimatableBody3D = $LeftDoorPivot
@onready var right_pivot: AnimatableBody3D = $RightDoorPivot

var _is_open := false
var _tween: Tween


func _ready() -> void:
    set_meta("locked", locked)


func interact(player: Node = null) -> void:
    if locked:
        if player != null:
            var inventory := player.get_node_or_null("ItemInventory")
            if inventory != null and inventory.has_method("_set_status"):
                inventory.call("_set_status", "Gerbang sekolah masih terkunci.")
        return

    if left_pivot == null or right_pivot == null:
        return

    if _tween != null:
        _tween.kill()

    var left_target := 0.0 if _is_open else deg_to_rad(-open_angle_degrees)
    var right_target := 0.0 if _is_open else deg_to_rad(open_angle_degrees)

    _tween = create_tween()
    _tween.set_trans(Tween.TRANS_SINE)
    _tween.set_ease(Tween.EASE_OUT)
    _tween.set_parallel(true)
    _tween.tween_property(
        left_pivot,
        "rotation:y",
        left_target,
        animation_duration
    )
    _tween.tween_property(
        right_pivot,
        "rotation:y",
        right_target,
        animation_duration
    )
    _tween.set_parallel(false)

    var audio := get_tree().get_first_node_in_group("game_audio")
    if audio != null and audio.has_method("play_sfx"):
        audio.play_sfx("door_open" if not _is_open else "door_close")

    _is_open = not _is_open

    if _is_open:
        var game := get_node_or_null("../../GameManager")
        if game != null and game.has_method("complete_escape"):
            game.complete_escape(player)


func is_open() -> bool:
    return _is_open


func set_locked(value: bool) -> void:
    locked = value
    set_meta("locked", locked)
