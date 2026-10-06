extends SceneTree

const SCENES := [
    "res://Administration_Furniture.tscn",
    "res://BangkuLorong_Furniture.tscn",
    "res://FemaleToilet_Furniture.tscn",
    "res://GuestRoom_Furniture.tscn",
    "res://Kantin_Furniture.tscn",
    "res://Kelas_10_A_Furniture.tscn",
    "res://Library_Furniture.tscn",
    "res://MaleToilet_Furniture.tscn",
    "res://PrincipalOffice_Furniture.tscn",
    "res://TeacherRoom_Furniture.tscn",
    "res://ToiletSketsel_Furniture.tscn",
    "res://UKS_Furniture.tscn",
    "res://Warehouse_Furniture.tscn"
]

const SKIP_GROUP_NAMES := [
    "Computer_01", "Computer_02", "Computer_03",
    "Monitor", "Keyboard", "Mouse",
    "Pillow", "Book", "Binder",
    "Soap", "Tissue", "Trash", "Drain",
    "Handle", "Printer", "PaperTray",
    "Leg", "BackSupport", "SeatSupport", "Frame",
    "Label"
]

func _init() -> void:
    for path: String in SCENES:
        _process_scene(path)
    quit()

func _process_scene(path: String) -> void:
    var packed := load(path) as PackedScene
    if packed == null:
        print("LOAD_FAIL ", path)
        return

    var scene_root := packed.instantiate()
    if scene_root == null:
        print("INSTANTIATE_FAIL ", path)
        return

    get_root().add_child(scene_root)

    var furniture_root := scene_root.get_node_or_null("FurnitureRoot")
    if furniture_root == null:
        print("NO_FURNITURE_ROOT ", path)
        scene_root.queue_free()
        return

    var added := 0

    # Kelas: beri collider per meja siswa, bukan satu kotak besar untuk seluruh StudentDesks.
    var student_desks := furniture_root.get_node_or_null("StudentDesks")
    if student_desks != null:
        for child: Node in student_desks.get_children():
            if child is Node3D and _has_mesh(child):
                if _needs_collision(child):
                    if _add_box_collision(child):
                        added += 1

    # Semua kelompok furniture fisik langsung di bawah FurnitureRoot.
    for child: Node in furniture_root.get_children():
        if child == student_desks:
            continue
        if not (child is Node3D):
            continue
        var group := child as Node3D
        if not _has_mesh(group):
            continue
        if not _needs_collision(group):
            continue
        if _add_box_collision(group):
            added += 1

    var output := PackedScene.new()
    var pack_result := output.pack(scene_root)
    if pack_result != OK:
        print("PACK_FAIL ", path, " code=", pack_result)
        scene_root.queue_free()
        return

    var save_result := ResourceSaver.save(output, path)
    print("COLLISION_BAKED ", path, " added=", added, " save=", save_result)
    scene_root.queue_free()

func _needs_collision(group: Node3D) -> bool:
    for child: Node in group.get_children():
        if child is StaticBody3D or child is CollisionShape3D:
            return false
    if _has_collision_descendant(group):
        return false
    return true

func _has_collision_descendant(node: Node) -> bool:
    for child: Node in node.get_children():
        if child is StaticBody3D or child is CollisionShape3D:
            return true
        if _has_collision_descendant(child):
            return true
    return false

func _has_mesh(node: Node) -> bool:
    if node is MeshInstance3D:
        return true
    for child: Node in node.get_children():
        if _has_mesh(child):
            return true
    return false

func _add_box_collision(group: Node3D) -> bool:
    if _is_skip_group(group.name):
        return false

    var bounds := _group_bounds(group)
    if bounds.size.x <= 0.05 or bounds.size.y <= 0.05 or bounds.size.z <= 0.05:
        return false

    var body := StaticBody3D.new()
    body.name = "FurnitureCollision"
    body.collision_layer = 1
    body.collision_mask = 1
    group.add_child(body)

    var shape_node := CollisionShape3D.new()
    shape_node.name = "CollisionShape3D"
    var shape := BoxShape3D.new()
    shape.size = bounds.size
    shape_node.shape = shape
    shape_node.position = bounds.position + bounds.size * 0.5
    body.add_child(shape_node)

    body.owner = _scene_owner(group)
    shape_node.owner = _scene_owner(group)
    return true

func _group_bounds(group: Node3D) -> AABB:
    var result := AABB()
    var initialized := false
    var group_inverse := group.global_transform.affine_inverse()

    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(group, meshes)

    for mesh_instance: MeshInstance3D in meshes:
        if not mesh_instance.visible:
            continue
        if _is_skip_mesh(mesh_instance.name):
            continue
        if mesh_instance.mesh == null:
            continue

        var aabb := mesh_instance.get_aabb()
        var points := [
            aabb.position,
            aabb.position + Vector3(aabb.size.x, 0, 0),
            aabb.position + Vector3(0, aabb.size.y, 0),
            aabb.position + Vector3(0, 0, aabb.size.z),
            aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
            aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
            aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
            aabb.position + aabb.size
        ]

        for p: Vector3 in points:
            var world_point := mesh_instance.global_transform * p
            var local_point := group_inverse * world_point
            if not initialized:
                result = AABB(local_point, Vector3.ZERO)
                initialized = true
            else:
                result = result.expand(local_point)

    return result

func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        result.append(node as MeshInstance3D)
        return
    for child: Node in node.get_children():
        _collect_meshes(child, result)

func _is_skip_group(name: String) -> bool:
    for token: String in SKIP_GROUP_NAMES:
        if name.begins_with(token) or name.find(token) >= 0:
            return true
    return false

func _is_skip_mesh(name: String) -> bool:
    for token: String in SKIP_GROUP_NAMES:
        if name.find(token) >= 0:
            return true
    return false

func _scene_owner(group: Node) -> Node:
    var current := group
    while current.owner != null:
        current = current.owner
    return current
