extends Area3D

## Interaksi bersembunyi di peti gudang. Tutup berengsel dan menyisakan celah pandang kecil.

const LID_CLOSED_ROTATION := Vector3(0.055, 0.0, 0.0)
const LID_OPEN_ROTATION := Vector3(1.62, 0.0, 0.0)
const LID_ANIMATION_TIME := 0.42

var _crate: Node3D
var _lid_pivot: Node3D
var _busy := false
var _hidden_player: CharacterBody3D
var _saved_transform: Transform3D
var _saved_camera_position := Vector3.ZERO
var _saved_camera_rotation := Vector3.ZERO
var _saved_physics_process := true
var _saved_collision_disabled := false
var _saved_visibility: Dictionary = {}


func _ready() -> void:
    collision_layer = 1
    collision_mask = 0
    monitoring = true
    monitorable = true
    add_to_group("map58_hiding_spot")
    set_meta("interaction_type", "hiding")
    _crate = get_parent() as Node3D
    if _crate != null:
        _lid_pivot = _crate.get_node_or_null("LidPivot") as Node3D
        if _lid_pivot != null:
            _lid_pivot.rotation = LID_CLOSED_ROTATION


func toggle_hide(player: Node = null) -> void:
    if _busy or player == null or not player is CharacterBody3D:
        return
    var character := player as CharacterBody3D
    if _hidden_player == character:
        _exit_crate(character)
        return
    if bool(character.get_meta("is_hidden", false)) or _hidden_player != null:
        return
    _enter_crate(character)


func network_set_hiding_visual(_hidden: bool) -> void:
    # Visual-only sequence for a remote player's interaction; never moves this peer's player.
    if _busy or _lid_pivot == null:
        return
    _busy = true
    await _animate_lid(true)
    await _animate_lid(false)
    _busy = false


func _enter_crate(player: CharacterBody3D) -> void:
    if _crate == null or _lid_pivot == null:
        _set_status(player, "Peti belum siap digunakan.")
        return

    _busy = true
    _hidden_player = player
    _saved_transform = player.global_transform
    _saved_physics_process = player.is_physics_processing()
    var camera := player.get_node_or_null("Camera3D") as Camera3D
    var player_collision := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if camera != null:
        _saved_camera_position = camera.position
        _saved_camera_rotation = camera.rotation
    if player_collision != null:
        _saved_collision_disabled = player_collision.disabled
        player_collision.set_deferred("disabled", true)

    _saved_visibility.clear()
    _save_visibility_recursive(player)
    player.velocity = Vector3.ZERO
    player.set_meta("is_hidden", true)
    player.set_meta("hide_spot", self)
    player.set_physics_process(false)

    await _animate_lid(true)
    player.global_transform = _crate.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.12, 0.0))
    if camera != null:
        # Kamera menghadap panel depan; celah di bawah tutup memberi garis pandang ke luar.
        camera.position = Vector3(0.0, 1.48, -0.10)
        camera.rotation = Vector3(-0.32, 0.0, 0.0)
    _set_player_meshes_visible(player, false)
    await _animate_lid(false)
    _set_status(player, "Kamu bersembunyi di dalam peti. Klik kanan untuk keluar.")
    _busy = false


func _exit_crate(player: CharacterBody3D) -> void:
    _busy = true
    await _animate_lid(true)
    _set_player_meshes_visible(player, true)
    player.set_physics_process(false)
    player.global_transform = _saved_transform
    var camera := player.get_node_or_null("Camera3D") as Camera3D
    if camera != null:
        camera.position = _saved_camera_position
        camera.rotation = _saved_camera_rotation
    var player_collision := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if player_collision != null:
        player_collision.set_deferred("disabled", _saved_collision_disabled)
    player.velocity = Vector3.ZERO
    player.set_meta("is_hidden", false)
    player.set_meta("hide_spot", null)
    player.set_physics_process(_saved_physics_process)
    _hidden_player = null
    _set_status(player, "Kamu keluar dari peti.")
    await _animate_lid(false)
    _busy = false


func _animate_lid(open_value: bool) -> void:
    if _lid_pivot == null:
        return
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(
        _lid_pivot,
        "rotation",
        LID_OPEN_ROTATION if open_value else LID_CLOSED_ROTATION,
        LID_ANIMATION_TIME
    )
    await tween.finished


func _save_visibility_recursive(node: Node) -> void:
    for child in node.get_children():
        if child is VisualInstance3D:
            _saved_visibility[child.get_instance_id()] = [child, child.visible]
        _save_visibility_recursive(child)


func _set_player_meshes_visible(player: Node, visible_value: bool) -> void:
    for entry in _saved_visibility.values():
        var node: Node = entry[0]
        if is_instance_valid(node):
            node.visible = bool(entry[1]) if visible_value else false


func _set_status(player: CharacterBody3D, message: String) -> void:
    var inventory := player.get_node_or_null("ItemInventory")
    if inventory != null and inventory.has_method("_set_status"):
        inventory.call("_set_status", message)