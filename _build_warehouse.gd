extends SceneTree

const OUT_PATH := "res://Warehouse_Furniture.tscn"

func mat(color: Color, roughness := 0.90) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    return m

func box_mesh(size: Vector3, material_ref: Material) -> BoxMesh:
    var b := BoxMesh.new()
    b.size = size
    b.material = material_ref
    return b

func add_group(parent: Node3D, name: String, pos: Vector3, rot_y := 0.0) -> Node3D:
    var n := Node3D.new()
    n.name = name
    n.position = pos
    n.rotation.y = rot_y
    parent.add_child(n)
    return n

func add_mesh(parent: Node3D, name: String, mesh: Mesh, pos: Vector3, rot_y := 0.0) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    n.name = name
    n.mesh = mesh
    n.position = pos
    n.rotation.y = rot_y
    parent.add_child(n)
    return n

func add_collision(parent: Node3D, name: String, size: Vector3, pos: Vector3) -> void:
    var body := StaticBody3D.new()
    body.name = name
    parent.add_child(body)
    var shape := CollisionShape3D.new()
    shape.name = "CollisionShape3D"
    var bs := BoxShape3D.new()
    bs.size = size
    shape.shape = bs
    shape.position = pos
    body.add_child(shape)

func make_rack(parent: Node3D, name: String, pos: Vector3, rot_y: float, frame_mat: Material, shelf_mat: Material, box_mats: Array[Material]) -> void:
    var r := add_group(parent, name, pos, rot_y)
    var post_mesh := box_mesh(Vector3(0.14, 3.90, 0.14), frame_mat)
    var shelf_mesh := box_mesh(Vector3(2.65, 0.12, 1.05), shelf_mat)
    for x in [-1.24, 1.24]:
        add_mesh(r, "Post_%s" % str(x), post_mesh, Vector3(x, 1.95, 0))
    for y in [0.40, 1.25, 2.10, 2.95, 3.72]:
        add_mesh(r, "Shelf_%s" % str(y), shelf_mesh, Vector3(0, y, 0))
        if y < 3.6:
            for i in range(4):
                var bx := -0.82 + i * 0.55
                var by := y + 0.42
                var bz := -0.05
                var box_mat := box_mats[(int(y * 10.0) + i) % box_mats.size()]
                add_mesh(r, "Box_%s_%02d" % [str(y), i + 1], box_mesh(Vector3(0.46, 0.48, 0.72), box_mat), Vector3(bx, by, bz))
    add_collision(r, "Collision", Vector3(2.70, 3.95, 1.10), Vector3(0, 1.95, 0))

func make_big_crate(parent: Node3D, wood: Material, dark: Material, label_mat: Material) -> void:
    var c := add_group(parent, "LargeStorageCrate", Vector3(5.25, 0, -10.85))
    add_mesh(c, "Body", box_mesh(Vector3(2.90, 1.90, 1.55), wood), Vector3(0, 0.95, 0))
    add_mesh(c, "Band_Left", box_mesh(Vector3(0.14, 2.00, 1.62), dark), Vector3(-1.10, 0.95, 0))
    add_mesh(c, "Band_Right", box_mesh(Vector3(0.14, 2.00, 1.62), dark), Vector3(1.10, 0.95, 0))
    add_mesh(c, "Band_Top", box_mesh(Vector3(2.90, 0.14, 1.62), dark), Vector3(0, 1.78, 0))
    add_mesh(c, "Label", box_mesh(Vector3(0.95, 0.55, 0.05), label_mat), Vector3(0, 1.20, -0.79))
    add_collision(c, "Collision", Vector3(3.00, 2.00, 1.65), Vector3(0, 1.00, 0))

func set_owner_recursive(n: Node, owner_node: Node) -> void:
    for child in n.get_children():
        child.owner = owner_node
        set_owner_recursive(child, owner_node)

func _init() -> void:
    var scene_root := Node3D.new()
    scene_root.name = "Warehouse_Furniture"

    var furniture_root := Node3D.new()
    furniture_root.name = "FurnitureRoot"
    scene_root.add_child(furniture_root)

    var frame := mat(Color(0.22, 0.13, 0.06, 1), 0.94)
    var shelf := mat(Color(0.36, 0.21, 0.09, 1), 0.88)
    var box1 := mat(Color(0.58, 0.42, 0.25, 1), 1.0)
    var box2 := mat(Color(0.48, 0.33, 0.18, 1), 1.0)
    var box3 := mat(Color(0.64, 0.48, 0.28, 1), 1.0)
    var box4 := mat(Color(0.40, 0.29, 0.17, 1), 1.0)
    var box5 := mat(Color(0.70, 0.54, 0.32, 1), 1.0)
    var crate_wood := mat(Color(0.47, 0.28, 0.11, 1), 0.90)
    var crate_dark := mat(Color(0.20, 0.11, 0.045, 1), 0.95)
    var label := mat(Color(0.88, 0.78, 0.55, 1), 1.0)

    var box_mats: Array[Material] = [box1, box2, box3, box4, box5]

    # Rak utama berada di sepanjang dinding kanan dan dinding belakang.
    # Bukaan kiri-atas tetap kosong agar jalur pintu gudang tidak tertutup.
    make_rack(furniture_root, "Rack_Right_01", Vector3(7.35, 0, -7.80), PI * 0.5, frame, shelf, box_mats)
    make_rack(furniture_root, "Rack_Right_02", Vector3(7.35, 0, -2.50), PI * 0.5, frame, shelf, box_mats)
    make_rack(furniture_root, "Rack_Right_03", Vector3(7.35, 0, 2.80), PI * 0.5, frame, shelf, box_mats)

    make_rack(furniture_root, "Rack_Back_01", Vector3(-4.80, 0, 10.85), 0.0, frame, shelf, box_mats)
    make_rack(furniture_root, "Rack_Back_02", Vector3(0.20, 0, 10.85), 0.0, frame, shelf, box_mats)

    # Satu rak tambahan di bagian kiri bawah, tetap jauh dari bukaan kiri-atas.
    make_rack(furniture_root, "Rack_Left_Lower", Vector3(-7.35, 0, 4.25), -PI * 0.5, frame, shelf, box_mats)

    # Peti besar dipusatkan pada segmen dinding utara yang tersedia,
    # bukan pada bagian dinding yang memiliki bukaan.
    make_big_crate(furniture_root, crate_wood, crate_dark, label)

    set_owner_recursive(scene_root, scene_root)
    scene_root.owner = scene_root

    var packed := PackedScene.new()
    var err := packed.pack(scene_root)
    if err != OK:
        push_error("Warehouse_Furniture pack failed: " + str(err))
        scene_root.free()
        quit()
        return

    var save_err := ResourceSaver.save(packed, OUT_PATH)
    print("Warehouse_Furniture save result: ", save_err)
    scene_root.free()
    quit()
