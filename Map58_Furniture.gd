extends Node3D

var mat_wood: StandardMaterial3D
var mat_dark_wood: StandardMaterial3D
var mat_board: StandardMaterial3D
var mat_metal: StandardMaterial3D
var mat_white: StandardMaterial3D
var mat_mattress: StandardMaterial3D
var mat_cabinet: StandardMaterial3D
var mat_canteen: StandardMaterial3D

var desk_mesh: BoxMesh
var seat_mesh: BoxMesh
var thin_box: BoxMesh
var leg_mesh: BoxMesh
var board_mesh: BoxMesh
var cabinet_mesh: BoxMesh

func _ready() -> void:
    _create_materials()
    _create_meshes()
    _build_classrooms()
    _build_teacher_room()
    _build_principal_room()
    _build_uks()
    _build_hall_benches()
    _build_canteen()
    print("Map58 furniture placed | classrooms + teacher room + principal room + UKS + hallway + canteen")

func _create_materials() -> void:
    mat_wood = StandardMaterial3D.new()
    mat_wood.albedo_color = Color(0.34, 0.20, 0.10, 1)
    mat_wood.roughness = 0.9

    mat_dark_wood = StandardMaterial3D.new()
    mat_dark_wood.albedo_color = Color(0.16, 0.09, 0.04, 1)
    mat_dark_wood.roughness = 0.95

    mat_board = StandardMaterial3D.new()
    mat_board.albedo_color = Color(0.03, 0.08, 0.06, 1)
    mat_board.roughness = 0.95

    mat_metal = StandardMaterial3D.new()
    mat_metal.albedo_color = Color(0.25, 0.27, 0.30, 1)
    mat_metal.metallic = 0.55
    mat_metal.roughness = 0.65

    mat_white = StandardMaterial3D.new()
    mat_white.albedo_color = Color(0.84, 0.84, 0.80, 1)
    mat_white.roughness = 0.9

    mat_mattress = StandardMaterial3D.new()
    mat_mattress.albedo_color = Color(0.65, 0.70, 0.75, 1)
    mat_mattress.roughness = 1.0

    mat_cabinet = StandardMaterial3D.new()
    mat_cabinet.albedo_color = Color(0.45, 0.28, 0.12, 1)
    mat_cabinet.roughness = 0.92

    mat_canteen = StandardMaterial3D.new()
    mat_canteen.albedo_color = Color(0.75, 0.20, 0.08, 1)
    mat_canteen.roughness = 0.85

func _create_meshes() -> void:
    desk_mesh = BoxMesh.new()
    desk_mesh.size = Vector3(2.2, 0.16, 0.95)
    desk_mesh.material = mat_wood

    seat_mesh = BoxMesh.new()
    seat_mesh.size = Vector3(1.0, 0.14, 0.9)
    seat_mesh.material = mat_wood

    thin_box = BoxMesh.new()
    thin_box.size = Vector3(0.15, 0.15, 0.15)
    thin_box.material = mat_metal

    leg_mesh = BoxMesh.new()
    leg_mesh.size = Vector3(0.12, 0.78, 0.12)
    leg_mesh.material = mat_metal

    board_mesh = BoxMesh.new()
    board_mesh.size = Vector3(6.4, 3.0, 0.12)
    board_mesh.material = mat_board

    cabinet_mesh = BoxMesh.new()
    cabinet_mesh.size = Vector3(1.5, 3.1, 0.7)
    cabinet_mesh.material = mat_cabinet

func _mesh(mesh: Mesh, position_value: Vector3, parent: Node3D = self, rotation_value := Vector3.ZERO) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.position = position_value
    node.rotation = rotation_value
    parent.add_child(node)
    return node

func _create_desk(parent: Node3D, at: Vector3, facing := 0.0) -> void:
    var group := Node3D.new()
    group.position = at
    group.rotation.y = facing
    parent.add_child(group)

    _mesh(desk_mesh, Vector3(0, 0.92, 0), group)

    var leg_offsets := [
        Vector3(-0.9, 0.46, -0.32),
        Vector3(0.9, 0.46, -0.32),
        Vector3(-0.9, 0.46, 0.32),
        Vector3(0.9, 0.46, 0.32)
    ]
    for p in leg_offsets:
        _mesh(leg_mesh, p, group)

    var chair := Node3D.new()
    chair.position = Vector3(0, 0, 1.0)
    group.add_child(chair)
    _mesh(seat_mesh, Vector3(0, 0.55, 0), chair)

    var back := BoxMesh.new()
    back.size = Vector3(1.0, 0.75, 0.12)
    back.material = mat_wood
    _mesh(back, Vector3(0, 0.88, 0.38), chair)

    for x in [-0.4, 0.4]:
        _mesh(leg_mesh, Vector3(x, 0.28, -0.32), chair)
        _mesh(leg_mesh, Vector3(x, 0.28, 0.32), chair)

func _create_blackboard(parent: Node3D, at: Vector3, facing := 0.0) -> void:
    var group := Node3D.new()
    group.position = at
    group.rotation.y = facing
    parent.add_child(group)
    _mesh(board_mesh, Vector3(0, 1.7, 0), group)

    var frame := BoxMesh.new()
    frame.size = Vector3(6.8, 0.16, 0.18)
    frame.material = mat_dark_wood
    _mesh(frame, Vector3(0, 3.25, 0.05), group)
    _mesh(frame, Vector3(0, 0.15, 0.05), group)

    var side := BoxMesh.new()
    side.size = Vector3(0.16, 3.1, 0.18)
    side.material = mat_dark_wood
    _mesh(side, Vector3(-3.32, 1.7, 0.05), group)
    _mesh(side, Vector3(3.32, 1.7, 0.05), group)

    var tray := BoxMesh.new()
    tray.size = Vector3(6.2, 0.10, 0.30)
    tray.material = mat_dark_wood
    _mesh(tray, Vector3(0, 0.08, -0.10), group)

func _create_cabinet(parent: Node3D, at: Vector3, facing := 0.0) -> void:
    var group := Node3D.new()
    group.position = at
    group.rotation.y = facing
    parent.add_child(group)

    var cabinet_body := BoxMesh.new()
    cabinet_body.size = Vector3(2.0, 3.2, 0.95)
    cabinet_body.material = mat_cabinet
    _mesh(cabinet_body, Vector3(0, 1.60, 0), group)

    var top := BoxMesh.new()
    top.size = Vector3(2.15, 0.14, 1.05)
    top.material = mat_dark_wood
    _mesh(top, Vector3(0, 3.22, 0), group)

    var handle := BoxMesh.new()
    handle.size = Vector3(0.12, 0.12, 0.06)
    handle.material = mat_metal
    _mesh(handle, Vector3(0, 1.60, -0.51), group)

func _build_classrooms() -> void:
    var rooms := [
        Vector3(-3.646515, 0.0, -26.45901),
        Vector3(13.79099, 0.0, -26.45901),
        Vector3(31.22849, 0.0, -26.45901),
        Vector3(48.66599, 0.0, -26.45901),
        Vector3(-3.646515, 0.0, -45.841),
        Vector3(13.79099, 0.0, -45.841),
        Vector3(31.22849, 0.0, -45.841),
        Vector3(48.66599, 0.0, -45.841),
        Vector3(-3.646515, 0.0, -65.21802),
        Vector3(13.79099, 0.0, -65.21802),
        Vector3(31.22849, 0.0, -65.21802),
        Vector3(48.66599, 0.0, -65.21802)
    ]

    for center in rooms:
        var room := Node3D.new()
        room.position = center
        room.name = "ClassroomFurniture"
        add_child(room)

        _create_blackboard(room, Vector3(0, 0, -6.95))
        _create_cabinet(room, Vector3(6.6, 0, 5.9))

        var x_offsets := [-3.8, 0.0, 3.8]
        var z_offsets := [-1.0, 3.2]
        for z_value in z_offsets:
            for x_value in x_offsets:
                _create_desk(room, Vector3(x_value, 0, z_value))

func _build_teacher_room() -> void:
    var center := Vector3(-28.43625, 0.0, -41.5864)
    var room := Node3D.new()
    room.name = "TeacherRoomFurniture"
    room.position = center
    add_child(room)

    for x_value in [-4.0, 4.0]:
        for z_value in [-6.0, 0.0, 6.0]:
            _create_desk(room, Vector3(x_value, 0, z_value))

    _create_cabinet(room, Vector3(5.0, 0, 9.0))

func _build_principal_room() -> void:
    var center := Vector3(-28.43625, 0.0, 23.8562)
    var room := Node3D.new()
    room.name = "PrincipalRoomFurniture"
    room.position = center
    add_child(room)

    _create_desk(room, Vector3(0, 0, -1.5), PI)
    _create_cabinet(room, Vector3(4.5, 0, 2.8))

func _build_uks() -> void:
    var center := Vector3(58.1547, 0.0, -3.4886)
    var room := Node3D.new()
    room.name = "UKSFurniture"
    room.position = center
    add_child(room)

    # Dua kasur ditempatkan di pojok kiri dan kanan ruangan.
    _create_bed(room, Vector3(-2.55, 0, 1.35))
    _create_bed(room, Vector3(2.55, 0, 1.35), PI)

    # Lemari ditempatkan di samping pintu masuk, bukan di tengah ruangan.
    _create_cabinet(room, Vector3(3.65, 0, -2.95), 0.0)

func _create_bed(parent: Node3D, at: Vector3, facing := 0.0) -> void:
    var group := Node3D.new()
    group.position = at
    group.rotation.y = facing
    parent.add_child(group)

    var frame := BoxMesh.new()
    frame.size = Vector3(3.1, 0.28, 1.55)
    frame.material = mat_dark_wood
    _mesh(frame, Vector3(0, 0.46, 0), group)

    var mattress := BoxMesh.new()
    mattress.size = Vector3(2.85, 0.30, 1.35)
    mattress.material = mat_mattress
    _mesh(mattress, Vector3(0, 0.77, 0), group)

    var pillow := BoxMesh.new()
    pillow.size = Vector3(0.72, 0.18, 1.05)
    pillow.material = mat_white
    _mesh(pillow, Vector3(-0.92, 0.99, 0), group)

    # Kaki dibuat lebih tinggi supaya ruang bawah kasur terlihat jelas
    # dan nantinya bisa dipakai sebagai area persembunyian.
    var bed_leg_mesh := BoxMesh.new()
    bed_leg_mesh.size = Vector3(0.14, 0.75, 0.14)
    bed_leg_mesh.material = mat_dark_wood
    for x in [-1.35, 1.35]:
        for z in [-0.62, 0.62]:
            _mesh(bed_leg_mesh, Vector3(x, 0.075, z), group)

func _build_hall_benches() -> void:
    var positions := [
        Vector3(5.0, 0.0, -36.2),
        Vector3(22.5, 0.0, -36.2),
        Vector3(40.0, 0.0, -36.2),
        Vector3(5.0, 0.0, -55.55),
        Vector3(22.5, 0.0, -55.55),
        Vector3(40.0, 0.0, -55.55)
    ]

    for p in positions:
        _create_bench(p)

func _create_bench(at: Vector3) -> void:
    var group := Node3D.new()
    group.position = at
    add_child(group)

    var seat := BoxMesh.new()
    seat.size = Vector3(2.8, 0.22, 0.78)
    seat.material = mat_wood
    _mesh(seat, Vector3(0, 0.9, 0), group)

    var back := BoxMesh.new()
    back.size = Vector3(2.8, 0.85, 0.14)
    back.material = mat_wood
    _mesh(back, Vector3(0, 1.30, 0.30), group)

    for x in [-1.1, 1.1]:
        _mesh(leg_mesh, Vector3(x, 0.45, 0), group)

func _build_canteen() -> void:
    # Area santai kecil di ruang terbuka dekat sisi depan sekolah.
    var group := Node3D.new()
    group.name = "CanteenFurniture"
    group.position = Vector3(10.0, 0.0, -7.5)
    add_child(group)

    var stand := BoxMesh.new()
    stand.size = Vector3(4.0, 2.2, 1.4)
    stand.material = mat_canteen
    _mesh(stand, Vector3(0, 1.1, 0), group)

    var counter := BoxMesh.new()
    counter.size = Vector3(4.3, 0.18, 1.55)
    counter.material = mat_wood
    _mesh(counter, Vector3(0, 2.25, 0), group)

    var table := BoxMesh.new()
    table.size = Vector3(2.4, 0.18, 1.2)
    table.material = mat_wood
    _mesh(table, Vector3(0, 1.0, 3.0), group)

    for x in [-0.95, 0.95]:
        for z in [2.58, 3.42]:
            _mesh(leg_mesh, Vector3(x, 0.50, z), group)
