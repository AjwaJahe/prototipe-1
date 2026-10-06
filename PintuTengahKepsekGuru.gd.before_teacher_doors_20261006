extends Node3D

@export var open_distance: float = 2.0
@export var animation_duration: float = 0.35

@onready var left_pivot: AnimatableBody3D = $LeftDoorPivot
@onready var right_pivot: AnimatableBody3D = $RightDoorPivot

var _is_open := false
var _tween: Tween
var _left_closed_x: float
var _right_closed_x: float


func _ready() -> void:
    if left_pivot == null or right_pivot == null:
        push_error("PintuTengahKepsekGuru: pivot pintu tidak ditemukan.")
        return

    _left_closed_x = left_pivot.position.x
    _right_closed_x = right_pivot.position.x


func interact(_player: Node = null) -> void:
    if left_pivot == null or right_pivot == null:
        return

    if _tween != null:
        _tween.kill()

    # Pintu tengah adalah pintu geser dua daun.
    # Daun kiri bergerak ke barat (-X).
    # Daun kanan bergerak ke timur (+X).
    var opening := not _is_open
    var left_target_x := _left_closed_x - open_distance if opening else _left_closed_x
    var right_target_x := _right_closed_x + open_distance if opening else _right_closed_x

    _tween = create_tween()
    _tween.set_trans(Tween.TRANS_SINE)
    _tween.set_ease(Tween.EASE_OUT)
    _tween.set_parallel(true)

    _tween.tween_property(
        left_pivot,
        "position:x",
        left_target_x,
        animation_duration
    )

    _tween.tween_property(
        right_pivot,
        "position:x",
        right_target_x,
        animation_duration
    )

    _tween.set_parallel(false)

    var audio := get_tree().get_first_node_in_group("game_audio")
    if audio != null and audio.has_method("play_sfx"):
        audio.play_sfx("door_open" if opening else "door_close")

    _is_open = opening


func is_open() -> bool:
    return _is_open
