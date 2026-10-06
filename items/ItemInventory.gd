extends Node
## Inventory pemain untuk pickup Map58.
## Kapasitas tetap 2 slot, mengikuti WhiteboardTest.
## Item dunia tetap editable sebagai scene sendiri; tampilan tangan memakai
## instance visual terpisah di FirstPersonViewModel.

const MAX_SLOTS: int = 2
const INTERACTION_DISTANCE: float = 3.0
const DROP_FORWARD_DISTANCE: float = 1.5
const DROP_RAY_START_HEIGHT: float = 2.5
const DROP_RAY_LENGTH: float = 6.0

var items: Array[Node3D] = []
var selected_slot: int = -1

var _player: CharacterBody3D
var _camera: Camera3D
var _held_anchor: Node3D
var _held_display: Node3D
var _hover_target: Node3D = null

var _slot_labels: Array[Label] = []
var _slot_panels: Array[PanelContainer] = []
var _status_label: Label
var _prompt_label: Label


func _ready() -> void:
    _player = get_parent() as CharacterBody3D

    if _player != null:
        _camera = _player.get_node_or_null("Camera3D") as Camera3D
        _held_anchor = _player.get_node_or_null(
            "Camera3D/FirstPersonViewModel/HeldItem"
        ) as Node3D

    _build_ui()
    _update_ui()


func _process(_delta: float) -> void:
    _update_hover_target()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_1:
                _select_slot(0)
            KEY_2:
                _select_slot(1)
            KEY_P:
                _drop_selected()


func try_pickup(target: Node3D) -> bool:
    if target == null:
        return false

    if items.size() >= MAX_SLOTS:
        _set_status("Inventory penuh. Gunakan 1/2 lalu P untuk membuang item.")
        return false

    if items.has(target):
        return false

    if _hover_target == target:
        _set_hover_target(null)

    items.append(target)
    target.visible = false
    target.set_meta("in_inventory", true)
    _set_collision_disabled(target, true)

    if target.has_method("on_picked_up"):
        target.on_picked_up()

    if selected_slot < 0:
        selected_slot = 0

    _update_held_item()
    _update_ui()
    _set_status("Mengambil " + _display_name(target) + ".")

    if String(target.get_meta("item_type", "")) == "paper":
        var game := get_node_or_null("../../GameManager")
        if game != null and game.has_method("open_intro_paper"):
            game.open_intro_paper()

    return true


func has_item(item_type: String) -> bool:
    for item in items:
        if is_instance_valid(item) and String(
            item.get_meta("item_type", "")
        ) == item_type:
            return true
    return false


func consume_item_type(item_type: String) -> bool:
    var index := _find_item_index(item_type)
    if index < 0:
        return false

    items[index].set_meta("in_inventory", false)
    items.remove_at(index)

    if selected_slot > index:
        selected_slot -= 1
    elif selected_slot >= items.size():
        selected_slot = items.size() - 1

    _update_held_item()
    _update_ui()
    return true


func _drop_selected() -> void:
    if _player == null:
        return

    if selected_slot < 0 or selected_slot >= items.size():
        _set_status("Tidak ada item yang dipilih.")
        return

    var target: Node3D = items[selected_slot]
    if not is_instance_valid(target):
        items.remove_at(selected_slot)
        _select_valid_slot()
        _update_held_item()
        _update_ui()
        return

    _clear_held_display()

    items.remove_at(selected_slot)
    target.set_meta("in_inventory", false)

    var drop_position := _get_drop_position(target)
    target.global_position = drop_position
    target.visible = true
    _set_collision_disabled(target, false)

    _select_valid_slot()
    _update_held_item()
    _update_ui()
    _set_status("Membuang " + _display_name(target) + ".")


func _get_drop_position(target: Node3D) -> Vector3:
    var forward := -_player.global_transform.basis.z
    var candidate := _player.global_position + forward * DROP_FORWARD_DISTANCE

    var from := candidate + Vector3.UP * DROP_RAY_START_HEIGHT
    var to := from + Vector3.DOWN * DROP_RAY_LENGTH

    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = 1
    query.collide_with_bodies = true
    query.collide_with_areas = false
    query.exclude = [
        _player.get_rid(),
        target.get_rid()
    ]

    var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return candidate + Vector3.UP * 0.05

    var hit_position: Vector3 = hit.get("position", candidate)
    var lowest_local_y := _get_lowest_mesh_y_in_root(target)
    var extra_offset := 0.0

    if target.has_method("get_drop_surface_offset"):
        extra_offset = float(target.get_drop_surface_offset())

    return Vector3(
        hit_position.x,
        hit_position.y - lowest_local_y + extra_offset,
        hit_position.z
    )


func _get_lowest_mesh_y_in_root(target: Node3D) -> float:
    var inverse_root := target.global_transform.affine_inverse()
    var lowest := INF
    var found := false

    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(target, meshes)

    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue

        var local_to_root := inverse_root * mesh_instance.global_transform
        var aabb := mesh_instance.get_aabb()

        for x_side in [0, 1]:
            for y_side in [0, 1]:
                for z_side in [0, 1]:
                    var corner := aabb.position + Vector3(
                        aabb.size.x if x_side == 1 else 0.0,
                        aabb.size.y if y_side == 1 else 0.0,
                        aabb.size.z if z_side == 1 else 0.0
                    )
                    var root_space_point := local_to_root * corner
                    lowest = min(lowest, root_space_point.y)
                    found = true

    if not found:
        return 0.0

    return lowest


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
    for child in node.get_children():
        if child is MeshInstance3D:
            result.append(child as MeshInstance3D)
        _collect_meshes(child, result)


func _update_hover_target() -> void:
    if _camera == null or not is_instance_valid(_camera):
        return

    var center := _camera.get_viewport().get_visible_rect().size * 0.5
    var from := _camera.project_ray_origin(center)
    var to := from + _camera.project_ray_normal(center) * INTERACTION_DISTANCE

    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = 1
    query.collide_with_bodies = true
    query.collide_with_areas = false
    query.exclude = [_player.get_rid()]

    var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
    var next_target: Node3D = null

    if not hit.is_empty():
        var collider := hit.get("collider") as Node
        next_target = _find_item_ancestor(collider)

    if next_target != _hover_target:
        _set_hover_target(next_target)

    if _prompt_label == null:
        return

    if _hover_target != null and is_instance_valid(_hover_target):
        var item_name := _display_name(_hover_target)
        if items.size() >= MAX_SLOTS:
            _prompt_label.text = (
                "KLIK KIRI — " + item_name + " | INVENTORY PENUH"
            )
        else:
            _prompt_label.text = "KLIK KIRI — Ambil " + item_name
    else:
        _prompt_label.text = ""


func _find_item_ancestor(node: Node) -> Node3D:
    var current := node

    while current != null:
        if current.has_method("interact") and current.has_method("set_highlighted"):
            return current as Node3D
        current = current.get_parent()

    return null


func _set_hover_target(target: Node3D) -> void:
    if _hover_target != null and is_instance_valid(_hover_target):
        if _hover_target.has_method("set_highlighted"):
            _hover_target.set_highlighted(false)

    _hover_target = target

    if _hover_target != null and is_instance_valid(_hover_target):
        if _hover_target.has_method("set_highlighted"):
            _hover_target.set_highlighted(true)


func _select_slot(index: int) -> void:
    if index < 0 or index >= items.size():
        _set_status("Slot " + str(index + 1) + " kosong.")
        return

    selected_slot = index
    _update_held_item()
    _update_ui()
    _set_status("Dipilih: " + _display_name(items[index]))


func _select_valid_slot() -> void:
    if items.is_empty():
        selected_slot = -1
    elif selected_slot >= items.size():
        selected_slot = items.size() - 1


func _find_item_index(item_type: String) -> int:
    for i in range(items.size()):
        var item := items[i]
        if is_instance_valid(item) and String(
            item.get_meta("item_type", "")
        ) == item_type:
            return i
    return -1


func _display_name(target: Node3D) -> String:
    return String(target.get_meta("display_name", target.name))


func _set_collision_disabled(target: Node3D, disabled: bool) -> void:
    if target is CollisionObject3D:
        var collision_object := target as CollisionObject3D
        collision_object.collision_layer = 0 if disabled else 1
        collision_object.collision_mask = 0 if disabled else 1
        collision_object.input_ray_pickable = not disabled

    for child in target.get_children():
        if child is CollisionShape3D:
            (child as CollisionShape3D).disabled = disabled
        _set_collision_disabled(child as Node3D, disabled)


func _update_held_item() -> void:
    _clear_held_display()

    if _held_anchor == null:
        return

    if selected_slot < 0 or selected_slot >= items.size():
        return

    var item := items[selected_slot]
    if not is_instance_valid(item):
        return

    var scene_path := item.get_scene_file_path()
    if scene_path.is_empty():
        return

    var packed := load(scene_path) as PackedScene
    if packed == null:
        push_warning("ItemInventory: scene item tidak bisa di-load: " + scene_path)
        return

    var display := packed.instantiate() as Node3D
    if display == null:
        return

    display.name = "Held_" + String(item.get_meta("item_type", "item"))
    _held_anchor.add_child(display)
    _disable_held_physics(display)

    var item_type := String(item.get_meta("item_type", "item"))
    display.position = Vector3(0.04, -0.06, -0.36)
    display.rotation = Vector3.ZERO
    display.scale = Vector3.ONE * 1.7

    match item_type:
        "paper":
            display.position = Vector3(0.04, -0.04, -0.34)
            display.rotation_degrees = Vector3(-18.0, 10.0, -8.0)
            display.scale = Vector3.ONE * 1.55
            var game := get_node_or_null("../../GameManager")
            if game != null and game.has_method("get_intro_paper_text"):
                var paper_text := String(game.get_intro_paper_text())
                if not paper_text.is_empty():
                    var label := Label3D.new()
                    label.name = "HeldQuestionText"
                    label.position = Vector3(0.0, 0.012, 0.0)
                    label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
                    label.font_size = 20
                    label.pixel_size = 0.0015
                    label.width = 260.0
                    label.modulate = Color(0.08, 0.08, 0.07, 1.0)
                    label.text = paper_text
                    display.add_child(label)
        "chalk":
            display.position = Vector3(0.02, -0.06, -0.28)
            display.rotation_degrees = Vector3(0.0, 0.0, 68.0)
            display.scale = Vector3.ONE * 1.25
        "class_key", "red_key", "blue_key", "yellow_key":
            display.position = Vector3(0.06, -0.08, -0.32)
            display.rotation_degrees = Vector3(12.0, -18.0, -22.0)
            display.scale = Vector3.ONE * 1.35
        "medkit":
            display.position = Vector3(0.06, -0.12, -0.40)
            display.rotation_degrees = Vector3(-12.0, 18.0, -10.0)
            display.scale = Vector3.ONE * 1.35

    _held_display = display


func _disable_held_physics(node: Node3D) -> void:
    if node is CollisionObject3D:
        var object := node as CollisionObject3D
        object.collision_layer = 0
        object.collision_mask = 0
        object.input_ray_pickable = false

    if node is CollisionShape3D:
        (node as CollisionShape3D).disabled = true

    if node is PhysicsBody3D:
        (node as PhysicsBody3D).set_physics_process(false)

    for child in node.get_children():
        if child is Node3D:
            _disable_held_physics(child as Node3D)


func _clear_held_display() -> void:
    if _held_display != null and is_instance_valid(_held_display):
        _held_display.queue_free()
    _held_display = null


func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "ItemInventoryUI"
    canvas.layer = 20
    add_child(canvas)

    var root := Control.new()
    root.name = "Root"
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(root)

    var prompt := Label.new()
    prompt.name = "Prompt"
    prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
    prompt.offset_left = -260.0
    prompt.offset_top = 72.0
    prompt.offset_right = 260.0
    prompt.offset_bottom = 104.0
    prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    prompt.add_theme_font_size_override("font_size", 18)
    prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(prompt)
    _prompt_label = prompt

    var inventory_box := HBoxContainer.new()
    inventory_box.name = "InventoryBox"
    inventory_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    inventory_box.offset_left = -82.0
    inventory_box.offset_top = -105.0
    inventory_box.offset_right = 82.0
    inventory_box.offset_bottom = -20.0
    inventory_box.add_theme_constant_override("separation", 8)
    root.add_child(inventory_box)

    for index in range(MAX_SLOTS):
        var panel := PanelContainer.new()
        panel.custom_minimum_size = Vector2(76.0, 78.0)
        panel.name = "Slot" + str(index + 1)
        inventory_box.add_child(panel)

        var label := Label.new()
        label.name = "Item"
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 14)
        label.text = str(index + 1) + "\n—"
        panel.add_child(label)

        _slot_panels.append(panel)
        _slot_labels.append(label)

    var drop_button := Button.new()
    drop_button.name = "DropButton"
    drop_button.text = "BUANG [P]"
    drop_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    drop_button.offset_left = -175.0
    drop_button.offset_top = 24.0
    drop_button.offset_right = -24.0
    drop_button.offset_bottom = 66.0
    drop_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    drop_button.pressed.connect(_drop_selected)
    root.add_child(drop_button)

    _status_label = Label.new()
    _status_label.name = "Status"
    _status_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    _status_label.offset_left = 24.0
    _status_label.offset_top = -70.0
    _status_label.offset_right = 520.0
    _status_label.offset_bottom = -30.0
    _status_label.add_theme_font_size_override("font_size", 16)
    _status_label.text = ""
    _status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(_status_label)


func _update_ui() -> void:
    for i in range(MAX_SLOTS):
        if i < items.size() and is_instance_valid(items[i]):
            _slot_labels[i].text = (
                str(i + 1) + "\n" + _display_name(items[i])
            )
        else:
            _slot_labels[i].text = str(i + 1) + "\n—"

        if i == selected_slot:
            _slot_labels[i].modulate = Color(1.0, 1.0, 0.65, 1.0)
        else:
            _slot_labels[i].modulate = Color.WHITE


func _set_status(message: String) -> void:
    if _status_label != null:
        _status_label.text = message
