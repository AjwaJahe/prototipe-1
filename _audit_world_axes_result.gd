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

var out := PackedStringArray()

func _init() -> void:
    for path: String in SCENES:
        var ps := load(path) as PackedScene
        if ps == null:
            out.append("LOAD_FAIL|"+path)
            continue
        var root := ps.instantiate()
        var bad := 0
        var total := 0
        _audit(root, path, bad, total)
        out.append("RESULT|"+path+"|structural="+str(total)+"|non_identity="+str(bad))
        root.free()
    var f := FileAccess.open("res://_audit_world_axes_result.txt", FileAccess.WRITE)
    f.store_string("\n".join(out))
    f.close()
    quit()

func _audit(node: Node, path: String, bad:int, total:int) -> void:
    if node is Node3D and not (node is MeshInstance3D):
        var n := node as Node3D
        total += 1
        if not _basis_is_identity(n.transform.basis):
            bad += 1
            out.append("NONWORLD_AXIS|"+path+"|"+str(n.get_path()))
    for child: Node in node.get_children():
        _audit(child, path, bad, total)

func _basis_is_identity(b: Basis) -> bool:
    return (
        is_equal_approx(b.x.x,1.0) and is_equal_approx(b.x.y,0.0) and is_equal_approx(b.x.z,0.0) and
        is_equal_approx(b.y.x,0.0) and is_equal_approx(b.y.y,1.0) and is_equal_approx(b.y.z,0.0) and
        is_equal_approx(b.z.x,0.0) and is_equal_approx(b.z.y,0.0) and is_equal_approx(b.z.z,1.0)
    )
