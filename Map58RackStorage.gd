extends Area3D

## Storage rak gudang Map58.
## Rak lama tetap utuh. Script ini hanya menambahkan area interaksi,
## slot penyimpanan, dan panel pintu runtime.

var _rack_root: Node3D
var _storage_slot: Node3D
var _door: Node3D
var _stored_item: Node3D
var _door_open := true
var _door_busy := false
var _built := false

const CLOSED_DOOR_POSITION := Vector3(0.0, 2.1, -0.58)
const OPEN_DOOR_POSITION := Vector3(3.0, 2.1, -0.58)


func _ready() -> void:
    collision_layer = 1
    collision_mask = 0
    monitoring = true
    monitorable = true
    add_to_group("map58_rack_storage")
    set_meta("interaction_type", "storage")

    _rack_root = get_parent() as Node3D
    if _rack_root != null:
        call_deferred("_build")


func configure(rack_root: Node3D) -> void:
    _rack_root = rack_root
    if is_inside_tree():
        call_deferred("_build")


func _build() -> void:
    if _built or _rack_root == null:
        return

    _built = true

    var interaction_shape := CollisionShape3D.new()
    interaction_shape.name = "StorageInteractionShape"

    var box := BoxShape3D.new()
    box.size = Vector3(2.7, 3.8, 0.55)
    interaction_shape.shape = box
    interaction_shape.position = Vector3(0.0, 2.05, -0.82)
    add_child(interaction_shape)

    _storage_slot = Node3D.new()
    _storage_slot.name = "StorageSlot"
    _storage_slot.position = Vector3(0.0, 0.72, -0.30)
    _rack_root.add_child(_storage_slot)

    _door = Node3D.new()
    _door.name = "RackDoorRuntime"
    _door.position = OPEN_DOOR_POSITION
    _door.visible = false
    _rack_root.add_child(_door)

    var door_mesh := MeshInstance3D.new()
    door_mesh.name = "Panel"

    var panel := BoxMesh.new()
    panel.size = Vector3(2.7, 3.9, 0.08)
    door_mesh.mesh = panel
    door_mesh.material_override = _make_door_material()
    _door.add_child(door_mesh)

    var handle := MeshInstance3D.new()
    handle.name = "Handle"

    var handle_mesh := BoxMesh.new()
    handle_mesh.size = Vector3(0.18, 0.18, 0.10)
    handle.mesh = handle_mesh
    handle.position = Vector3(-0.92, 2.05, -0.07)
    handle.material_override = _make_handle_material()
    _door.add_child(handle)


func interact(player: Node = null) -> void:
    if _door_busy:
        return

    if not _door_open:
        _set_door_open(true, player)
        return

    if _stored_item != null and is_instance_valid(_stored_item):
        _retrieve_item(player)
        return

    _set_door_open(false, player)


func toggle_hide(player: Node = null) -> void:
    _store_selected_item(player)


func _set_door_open(open_value: bool, player: Node = null) -> void:
    if _door == null or _door_busy:
        return

    _door_busy = true
    _door_open = open_value
    _door.visible = true

    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

    if open_value:
        _door.position = CLOSED_DOOR_POSITION
        tween.tween_property(
            _door,
            "position",
            OPEN_DOOR_POSITION,
            0.28
        )
    else:
        _door.position = OPEN_DOOR_POSITION
        tween.tween_property(
            _door,
            "position",
            CLOSED_DOOR_POSITION,
            0.28
        )

    tween.finished.connect(_on_door_tween_finished.bind(open_value))

    _play_door_sfx("door_open" if open_value else "door_close")

    if player != null:
        _set_status(
            player,
            "Rak dibuka." if open_value else "Rak ditutup."
        )


func _on_door_tween_finished(open_value: bool) -> void:
    _door_busy = false
    if _door != null:
        _door.visible = not open_value


func _store_selected_item(player: Node) -> void:
    if player == null:
        return

    if not _door_open:
        _set_status(player, "Buka rak terlebih dahulu.")
        return

    if _stored_item != null and is_instance_valid(_stored_item):
        _set_status(player, "Rak ini sudah menyimpan satu item.")
        return

    var inventory := player.get_node_or_null("ItemInventory")
    if inventory == null:
        _set_status(player, "Inventory tidak ditemukan.")
        return

    var items_variant: Variant = inventory.get("items")
    if not items_variant is Array:
        _set_status(player, "Data inventory tidak valid.")
        return

    var items: Array = items_variant
    var selected_slot := int(inventory.get("selected_slot"))

    if selected_slot < 0 or selected_slot >= items.size():
        _set_status(player, "Pilih item di inventory terlebih dahulu.")
        return

    var item := items[selected_slot] as Node3D
    if item == null or not is_instance_valid(item):
        _set_status(player, "Item yang dipilih tidak valid.")
        return

    if inventory.has_method("_clear_held_display"):
        inventory.call("_clear_held_display")

    items.remove_at(selected_slot)
    inventory.set("items", items)
    inventory.call("_select_valid_slot")
    inventory.call("_update_held_item")
    inventory.call("_update_ui")

    item.set_meta("in_inventory", false)
    item.set_meta("stored_in_rack", true)
    item.visible = true

    if inventory.has_method("_set_collision_disabled"):
        inventory.call("_set_collision_disabled", item, true)

    item.reparent(_storage_slot, false)
    item.position = Vector3.ZERO
    item.rotation = Vector3.ZERO

    _stored_item = item

    _set_status(
        player,
        "Item disimpan di rak. Klik kiri untuk mengambilnya kembali."
    )


func _retrieve_item(player: Node) -> void:
    if player == null or _stored_item == null:
        return

    var inventory := player.get_node_or_null("ItemInventory")
    if inventory == null:
        return

    var items_variant: Variant = inventory.get("items")
    if not items_variant is Array:
        return

    var items: Array = items_variant
    if items.size() >= 2:
        _set_status(player, "Inventory penuh. Kosongkan satu slot terlebih dahulu.")
        return

    var item := _stored_item
    if not is_instance_valid(item):
        _stored_item = null
        return

    var world_items := _find_world_items_root()
    if world_items == null:
        _set_status(player, "Tempat item dunia tidak ditemukan.")
        return

    item.reparent(world_items, false)
    item.global_position = global_position + Vector3(0.0, 0.5, 0.0)
    item.set_meta("stored_in_rack", false)

    _stored_item = null

    inventory.call("try_pickup", item)
    _set_status(player, "Item diambil dari rak.")


func _find_world_items_root() -> Node3D:
    var current: Node = _rack_root

    while current != null:
        var world_items := current.get_node_or_null("Map58_ItemsTest") as Node3D
        if world_items != null:
            return world_items
        current = current.get_parent()

    var current_scene := get_tree().current_scene
    if current_scene != null:
        return current_scene.get_node_or_null("Furniture/Map58_ItemsTest") as Node3D

    return null


func _play_door_sfx(sound_name: String) -> void:
    var audio := get_tree().get_first_node_in_group("game_audio")
    if audio != null and audio.has_method("play_sfx"):
        audio.play_sfx(sound_name, -5.0)


func _set_status(player: Node, message: String) -> void:
    var inventory := player.get_node_or_null("ItemInventory")
    if inventory != null and inventory.has_method("_set_status"):
        inventory.call("_set_status", message)


func _make_door_material() -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.28, 0.16, 0.07, 0.92)
    material.roughness = 0.82
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return material


func _make_handle_material() -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.18, 0.18, 0.16, 1.0)
    material.metallic = 0.55
    material.roughness = 0.28
    return material
