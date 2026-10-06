extends Node3D

## Gameplay layer untuk furnitur interaktif Map58.
## Tidak memindahkan atau mengubah mesh/furnitur yang sudah ada.

const HIDE_SCRIPT := preload("res://Map58HidingSpot.gd")
const RACK_SCRIPT := preload("res://Map58RackStorage.gd")


func _ready() -> void:
    call_deferred("_setup")


func _setup() -> void:
    var furniture := get_node_or_null("../Furniture")
    if furniture == null:
        push_warning("Map58FurnitureGameplay: node Furniture tidak ditemukan.")
        return

    _scan_furniture(furniture)


func _scan_furniture(node: Node) -> void:
    if node is Node3D:
        var node_3d := node as Node3D
        var node_name := String(node_3d.name)

        if node_name.begins_with("Rack_"):
            _attach_rack_storage(node_3d)
        elif _is_tall_hide_candidate(node_3d):
            _attach_hiding_spots(node_3d)

    for child in node.get_children():
        _scan_furniture(child)


func _is_tall_hide_candidate(node: Node3D) -> bool:
    var valid_names := [
        "Cupboard",
        "Cabinet",
        "Wardrobe",
        "Locker",
        "Closet",
        "Lemari"
    ]

    if not valid_names.has(String(node.name)):
        return false

    var collision_root := node.get_node_or_null("FurnitureCollision")
    if collision_root == null:
        collision_root = node.get_node_or_null("Collision")

    if collision_root == null:
        return false

    var shape := _find_collision_shape(collision_root)
    if shape == null:
        return false

    if not shape.shape is BoxShape3D:
        return false

    var box := shape.shape as BoxShape3D
    return box.size.y >= 2.0


func _find_collision_shape(node: Node) -> CollisionShape3D:
    for child in node.get_children():
        if child is CollisionShape3D:
            return child as CollisionShape3D

        var nested := _find_collision_shape(child)
        if nested != null:
            return nested

    return null


func _attach_hiding_spots(cabinet: Node3D) -> void:
    if cabinet.get_node_or_null("Map58HideSpotFront") != null:
        return

    var offsets := [
        Vector3(0.72, 1.15, 0.0),
        Vector3(-0.72, 1.15, 0.0)
    ]

    for i in range(offsets.size()):
        var area := Area3D.new()
        area.name = "Map58HideSpotFront" + str(i + 1)
        area.position = offsets[i]
        area.set_script(HIDE_SCRIPT)

        var collision := CollisionShape3D.new()
        collision.name = "CollisionShape3D"

        var sphere := SphereShape3D.new()
        sphere.radius = 0.70
        collision.shape = sphere

        area.add_child(collision)
        cabinet.add_child(area)

        area.set_meta(
            "display_name",
            "Tempat Persembunyian " + String(cabinet.name)
        )


func _attach_rack_storage(rack: Node3D) -> void:
    if rack.get_node_or_null("Map58RackStorage") != null:
        return

    var area := Area3D.new()
    area.name = "Map58RackStorage"
    area.set_script(RACK_SCRIPT)
    rack.add_child(area)
    area.call_deferred("configure", rack)
