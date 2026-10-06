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

func _init() -> void:
    for path: String in SCENES:
        var ps := load(path) as PackedScene
        if ps == null:
            print("LOAD_FAIL ", path)
            continue

        var root := ps.instantiate()
        if root == null:
            print("INSTANTIATE_FAIL ", path)
            continue

        if path == "res://Kantin_Furniture.tscn":
            _apply_main_kantin_rotation(root)

        var changed := _normalize_structural_axes(root)
        var packed := PackedScene.new()
        var pack_result := packed.pack(root)
        if pack_result != OK:
            print("PACK_FAIL ", path, " code=", pack_result)
            root.free()
            continue

        var save_result := ResourceSaver.save(packed, path)
        print("NORMALIZED ", path, " changed=", changed, " save=", save_result)
        root.free()

    quit()

func _apply_main_kantin_rotation(root: Node) -> void:
    # Map58_Furniture previously rotated the whole canteen instance by 180 degrees
    # around Y. Bake that world rotation into the canteen scene before making the
    # instance transform identity.
    var r := Basis.from_euler(Vector3(0.0, PI, 0.0))
    for child: Node in root.get_children():
        if child is Node3D:
            var n := child as Node3D
            n.transform = Transform3D(r * n.transform.basis, r * n.transform.origin)

func _normalize_structural_axes(node: Node) -> int:
    var changed := 0

    for child: Node in node.get_children():
        if child is Node3D and not (child is MeshInstance3D):
            var n := child as Node3D
            var b := n.transform.basis
            if not _basis_is_identity(b):
                for grandchild: Node in n.get_children():
                    if grandchild is Node3D:
                        var g := grandchild as Node3D
                        g.transform = Transform3D(
                            b * g.transform.basis,
                            b * g.transform.origin
                        )
                n.transform.basis = Basis.IDENTITY
                changed += 1

        changed += _normalize_structural_axes(child)

    return changed

func _basis_is_identity(b: Basis) -> bool:
    return (
        is_equal_approx(b.x.x, 1.0) and
        is_equal_approx(b.x.y, 0.0) and
        is_equal_approx(b.x.z, 0.0) and
        is_equal_approx(b.y.x, 0.0) and
        is_equal_approx(b.y.y, 1.0) and
        is_equal_approx(b.y.z, 0.0) and
        is_equal_approx(b.z.x, 0.0) and
        is_equal_approx(b.z.y, 0.0) and
        is_equal_approx(b.z.z, 1.0)
    )
