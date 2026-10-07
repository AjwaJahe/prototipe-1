extends Node3D

@export var open_distance: float = 3.2
@export var animation_duration: float = 0.35
@export var use_map_wall: bool = false
@export var required_item_type: String = ""

@onready var door_slide: AnimatableBody3D = $DoorPivot

var _is_open := false
var _closed_x := 0.0
var _tween: Tween


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
        # Pintu berkunci benar-benar menolak semua aktor, termasuk guru.
        if _is_teacher_actor(player):
            return
        if player == null:
            return

        var inventory := player.get_node_or_null("ItemInventory")
        if inventory == null or not inventory.has_item(required_item_type):
            _set_locked_status(player)
            return

    if _tween != null:
        _tween.kill()

    var target_x := _closed_x + (
        open_distance
        if not _is_open
        else 0.0
    )

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
    if audio != null and audio.has_method("play_sfx"):
        audio.play_sfx("door_open" if not _is_open else "door_close")

    _is_open = not _is_open


func is_open() -> bool:
    return _is_open

func is_locked() -> bool:
    return not required_item_type.is_empty()


func _is_teacher_actor(player: Node) -> bool:
    return player != null and player.is_in_group("teacher")


func _set_locked_status(player: Node) -> void:
    var inventory := player.get_node_or_null("ItemInventory")
    if inventory != null and inventory.has_method("_set_status"):
        inventory.call(
            "_set_status",
            "Pintu terkunci. Diperlukan: " + _item_name(required_item_type)
        )


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
