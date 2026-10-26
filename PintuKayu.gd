extends Node3D

@export var open_angle_degrees: float = 90.0
@export var animation_duration: float = 0.35
@export var required_item_type: String = ""

@onready var door_pivot: AnimatableBody3D = $DoorPivot

var _is_open := false
var _tween: Tween


func _ready() -> void:
    add_to_group("doors")
    set_meta("locked", not required_item_type.is_empty())
    set_meta("required_item_type", required_item_type)


func interact(player: Node = null) -> void:
    if door_pivot == null:
        return

    if not required_item_type.is_empty() and not _is_teacher_actor(player):
        if player == null:
            return

        var inventory := player.get_node_or_null("ItemInventory")
        if inventory == null or not inventory.has_item(required_item_type):
            _set_locked_status(player)
            return

    if _tween != null:
        _tween.kill()

    var target_y := 0.0 if _is_open else deg_to_rad(open_angle_degrees)

    _tween = create_tween()
    _tween.set_trans(Tween.TRANS_SINE)
    _tween.set_ease(Tween.EASE_OUT)
    _tween.tween_property(
        door_pivot,
        "rotation:y",
        target_y,
        animation_duration
    )

    var audio := get_tree().get_first_node_in_group("game_audio")
    var sound_name := "door_open" if not _is_open else "door_close"
    if audio != null:
        if audio.has_method("play_sfx_for_duration"):
            audio.play_sfx_for_duration(sound_name, animation_duration, global_position)
        elif audio.has_method("play_sfx"):
            audio.play_sfx(sound_name, global_position)

    _is_open = not _is_open


func is_open() -> bool:
    return _is_open


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
