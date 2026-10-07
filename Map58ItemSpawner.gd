extends Node

## Spawner pickup Map58.
## Item runtime ditempatkan di atas permukaan furniture, bukan di lantai.
## Map58, floorplan, dan posisi furnitur tidak disentuh.

const TEST_POINTS_PATH := NodePath("../Furniture/Map58_ItemsTest")
const FURNITURE_PATH := NodePath("../Furniture")
const MARKER_ROOT_PATH := NodePath("../Map58_ItemSpawnPoints")

@export var randomize_respawn: bool = true
@export var minimum_spawn_separation: float = 0.75
@export var initial_surface_offset: float = 0.04
@export var ground_despawn_seconds: float = 60.0
@export var paper_quantity: int = 10
@export var chalk_quantity: int = 10
@export var key_quantity_min: int = 1
@export var key_quantity_max: int = 2
@export var medkit_quantity_min: int = 3
@export var medkit_quantity_max: int = 5

var _game: Node
var _rng := RandomNumberGenerator.new()
var _spawn_points: Array[Vector3] = []


func _ready() -> void:
    _rng.randomize()
    call_deferred("_initialize")


func _process(_delta: float) -> void:
    _despawn_expired_ground_items()


func _initialize() -> void:
    _game = get_node_or_null("../GameManager")
    _collect_spawn_points()
    spawn_initial_items()

    if _game != null and _game.has_signal("paper_respawn_requested"):
        _game.paper_respawn_requested.connect(_on_paper_respawn_requested)

    print(
        "Map58ItemSpawner: titik spawn furniture=",
        _spawn_points.size(),
        " | paper=",
        _count_type("paper"),
        " | chalk=",
        _count_type("chalk"),
        " | medkit=",
        _count_type("medkit")
    )


func _collect_spawn_points() -> void:
    _spawn_points.clear()

    var furniture := get_node_or_null(FURNITURE_PATH)
    if furniture != null:
        _collect_furniture_surfaces(furniture)

    if not _spawn_points.is_empty():
        return

    # Fallback hanya untuk project/scene yang tidak mempunyai permukaan furniture.
    var marker_root := get_node_or_null(MARKER_ROOT_PATH)
    if marker_root != null:
        for child in marker_root.get_children():
            if child is Marker3D:
                _spawn_points.append((child as Marker3D).global_position)

    if not _spawn_points.is_empty():
        return

    var test_root := get_node_or_null(TEST_POINTS_PATH)
    if test_root == null:
        return

    for child in test_root.get_children():
        if child is Node3D:
            _spawn_points.append((child as Node3D).global_position)


func _collect_furniture_surfaces(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if _is_surface_candidate(mesh_instance):
            _add_surface_points(mesh_instance)

    for child in node.get_children():
        _collect_furniture_surfaces(child)


func _is_surface_candidate(mesh_instance: MeshInstance3D) -> bool:
    if mesh_instance.mesh == null:
        return false

    var name_lower := String(mesh_instance.name).to_lower()
    var surface_name := (
        name_lower.contains("top")
        or name_lower.contains("counter")
        or name_lower.contains("shelf")
        or name_lower.contains("worktop")
        or name_lower.contains("desktop")
    )

    if not surface_name:
        return false

    var excluded_words := [
        "door",
        "pintu",
        "frame",
        "whiteboard",
        "board",
        "lamp",
        "fixture",
        "sign",
        "roof",
        "awning",
        "leg",
        "back"
    ]

    var current: Node = mesh_instance
    for _i in range(5):
        if current == null:
            break

        var current_name := String(current.name).to_lower()
        for word in excluded_words:
            if current_name.contains(word):
                return false

        current = current.get_parent()

    var aabb := mesh_instance.get_aabb()
    if aabb.size.y > 0.30:
        return false
    if aabb.size.x < 0.40 or aabb.size.z < 0.30:
        return false

    return true


func _add_surface_points(mesh_instance: MeshInstance3D) -> void:
    var aabb := mesh_instance.get_aabb()
    var half_x := aabb.size.x * 0.5
    var half_z := aabb.size.z * 0.5
    var center := aabb.position + Vector3(
        half_x,
        aabb.size.y,
        half_z
    )

    var local_points: Array[Vector3] = []

    var area := aabb.size.x * aabb.size.z
    if area >= 2.0:
        var offset_x := minf(half_x * 0.50, 0.75)
        var offset_z := minf(half_z * 0.50, 0.35)

        local_points.append(center + Vector3(-offset_x, initial_surface_offset, -offset_z))
        local_points.append(center + Vector3(offset_x, initial_surface_offset, -offset_z))
        local_points.append(center + Vector3(-offset_x, initial_surface_offset, offset_z))
        local_points.append(center + Vector3(offset_x, initial_surface_offset, offset_z))
    elif area >= 0.80:
        var offset_x := minf(half_x * 0.35, 0.45)
        var offset_z := minf(half_z * 0.35, 0.25)

        local_points.append(center + Vector3(-offset_x, initial_surface_offset, 0.0))
        local_points.append(center + Vector3(offset_x, initial_surface_offset, 0.0))
    else:
        local_points.append(center + Vector3(0.0, initial_surface_offset, 0.0))

    for point in local_points:
        _spawn_points.append(mesh_instance.global_transform * point)


func spawn_initial_items() -> void:
    _collect_spawn_points()
    var test_root := get_node_or_null(TEST_POINTS_PATH)
    if test_root == null or _spawn_points.is_empty():
        return

    var items: Array[Node3D] = []
    for child in test_root.get_children():
        if not child is Node3D:
            continue

        var item := child as Node3D
        if String(item.get_meta("item_type", "")) == "":
            continue
        if bool(item.get_meta("in_inventory", false)):
            continue

        items.append(item)

    var available: Array = _spawn_points.duplicate()
    var occupied: Array[Vector3] = []

    for item in items:
        if available.is_empty():
            break

        var chosen_index := _find_spread_point_index(available, occupied)
        if chosen_index < 0:
            chosen_index = _rng.randi_range(0, available.size() - 1)

        var surface_point: Vector3 = available[chosen_index]
        available.remove_at(chosen_index)

        _place_item_at_surface(item, surface_point)
        occupied.append(surface_point)


func _find_spread_point_index(points: Array, occupied: Array[Vector3]) -> int:
    var best_index := -1
    var best_distance := -INF

    var attempts := points.size()
    for i in range(attempts):
        var point: Vector3 = points[i]
        var nearest := INF

        if occupied.is_empty():
            nearest = INF
        else:
            for used in occupied:
                nearest = minf(nearest, point.distance_to(used))

        if occupied.is_empty() or nearest >= minimum_spawn_separation:
            return i

        if nearest > best_distance:
            best_distance = nearest
            best_index = i

    return best_index


func request_item_respawn(item_type: String) -> void:
    call_deferred("_respawn_one", item_type)


func _on_paper_respawn_requested() -> void:
    request_item_respawn("paper")
    request_item_respawn("chalk")


func _respawn_one(item_type: String) -> void:
    var item := _find_hidden_world_item(item_type)
    if item == null:
        return

    _place_item(item)

    if item_type == "paper" and _game != null:
        _game.call_deferred("register_spawned_paper")


func _find_hidden_world_item(item_type: String) -> Node3D:
    var test_root := get_node_or_null(TEST_POINTS_PATH)
    if test_root == null:
        return null

    for child in test_root.get_children():
        if not child is Node3D:
            continue

        var item := child as Node3D
        if String(item.get_meta("item_type", "")) != item_type:
            continue
        if bool(item.get_meta("in_inventory", false)):
            continue
        if not item.visible:
            return item

    return null


func _place_item(item: Node3D) -> void:
    if _spawn_points.is_empty():
        return

    var index := _choose_spawn_index(item)
    _place_item_at_surface(item, _spawn_points[index])


func _place_item_at_surface(item: Node3D, surface_point: Vector3) -> void:
    var lowest_local_y := _get_lowest_mesh_y_in_root(item)

    item.global_position = Vector3(
        surface_point.x,
        surface_point.y - lowest_local_y,
        surface_point.z
    )
    item.visible = true
    item.set_meta("in_inventory", false)
    item.set_meta("stored_in_rack", false)

    _set_item_collision_enabled(item, true)

    item.set_meta("spawned_at", Time.get_ticks_msec() / 1000.0)

    if item.has_method("set_highlighted"):
        item.set_highlighted(false)



func spawn_item_at_location(item_type: String, location: Vector3) -> bool:
    var item := _find_hidden_world_item(item_type)
    if item == null:
        return false
    _place_item_at_surface(item, location)
    return true


func on_item_picked_up(item: Node3D) -> void:
    if item != null:
        item.set_meta("spawned_at", 0.0)


func get_spawn_location_for(item_type: String) -> Vector3:
    if _spawn_points.is_empty():
        return Vector3.ZERO
    var candidates: Array[Vector3] = []
    for point in _spawn_points:
        if _is_spawn_position_clear(point, null):
            candidates.append(point)
    if candidates.is_empty():
        return _spawn_points[_rng.randi_range(0, _spawn_points.size() - 1)]
    return candidates[_rng.randi_range(0, candidates.size() - 1)]


func clear_all_items() -> void:
    var test_root := get_node_or_null(TEST_POINTS_PATH)
    if test_root == null:
        return
    for child in test_root.get_children():
        if child is Node3D and String((child as Node3D).get_meta("item_type", "")) != "":
            var item := child as Node3D
            item.visible = false
            item.set_meta("in_inventory", false)
            _set_item_collision_enabled(item, false)


func _despawn_expired_ground_items() -> void:
    if ground_despawn_seconds <= 0.0:
        return
    var test_root := get_node_or_null(TEST_POINTS_PATH)
    if test_root == null:
        return
    var now := Time.get_ticks_msec() / 1000.0
    for child in test_root.get_children():
        if not child is Node3D:
            continue
        var item := child as Node3D
        if not item.visible or bool(item.get_meta("in_inventory", false)):
            continue
        var spawned_at: float = item.get_meta("spawned_at", 0.0)
        if spawned_at > 0.0 and now - spawned_at >= ground_despawn_seconds:
            item.visible = false
            _set_item_collision_enabled(item, false)
            if String(item.get_meta("item_type", "")) == "paper" and _game != null:
                _game.call_deferred("unregister_spawned_paper")


func _get_lowest_mesh_y_in_root(item: Node3D) -> float:
    var inverse_root := item.global_transform.affine_inverse()
    var lowest := INF
    var found := false

    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(item, meshes)

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
                    var root_point := local_to_root * corner
                    lowest = minf(lowest, root_point.y)
                    found = true

    return lowest if found else 0.0


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
    for child in node.get_children():
        if child is MeshInstance3D:
            result.append(child as MeshInstance3D)
        _collect_meshes(child, result)


func _set_item_collision_enabled(node: Node, enabled: bool) -> void:
    if node is CollisionObject3D:
        var body := node as CollisionObject3D
        body.collision_layer = 1 if enabled else 0
        body.collision_mask = 1 if enabled else 0
        body.input_ray_pickable = enabled

    if node is CollisionShape3D:
        (node as CollisionShape3D).disabled = not enabled

    for child in node.get_children():
        if child is Node:
            _set_item_collision_enabled(child, enabled)


func _choose_spawn_index(item: Node3D) -> int:
    if not randomize_respawn or _spawn_points.size() == 1:
        return 0

    var candidates: Array[int] = []

    for i in range(_spawn_points.size()):
        if _is_spawn_position_clear(_spawn_points[i], item):
            candidates.append(i)

    if candidates.is_empty():
        return _rng.randi_range(0, _spawn_points.size() - 1)

    return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _is_spawn_position_clear(position_value: Vector3, item_to_ignore: Node3D) -> bool:
    var test_root := get_node_or_null(TEST_POINTS_PATH)
    if test_root == null:
        return true

    for child in test_root.get_children():
        if not child is Node3D:
            continue

        var other := child as Node3D
        if other == item_to_ignore:
            continue
        if not other.visible:
            continue
        if bool(other.get_meta("in_inventory", false)):
            continue

        if position_value.distance_to(other.global_position) < minimum_spawn_separation:
            return false

    return true


func _count_type(item_type: String) -> int:
    var total := 0
    var test_root := get_node_or_null(TEST_POINTS_PATH)
    if test_root == null:
        return 0

    for child in test_root.get_children():
        if child is Node3D and String(
            (child as Node3D).get_meta("item_type", "")
        ) == item_type:
            total += 1

    return total
