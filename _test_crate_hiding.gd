extends SceneTree

func _initialize() -> void:
    call_deferred("_run_test")

func _run_test() -> void:
    var packed := load("res://Warehouse_Furniture.tscn") as PackedScene
    assert(packed != null, "Warehouse_Furniture.tscn gagal dimuat")
    var harness := Node3D.new()
    var furniture := Node3D.new()
    furniture.name = "Furniture"
    harness.add_child(furniture)
    var warehouse := packed.instantiate()
    furniture.add_child(warehouse)
    var gameplay := Node3D.new()
    gameplay.name = "Map58FurnitureGameplay"
    gameplay.set_script(load("res://Map58FurnitureGameplay.gd"))
    harness.add_child(gameplay)
    root.add_child(harness)
    await process_frame
    await process_frame
    var crate := warehouse.get_node_or_null("FurnitureRoot/LargeStorageCrate")
    assert(crate != null, "LargeStorageCrate tidak ditemukan")
    assert(crate.get_node_or_null("LidPivot") != null, "LidPivot tidak ditemukan")
    assert(crate.get_node_or_null("FrontWall") != null, "FrontWall tidak ditemukan")
    assert(crate.get_node_or_null("Map58CrateHiding") != null, "Interaksi sembunyi tidak terpasang")
    var rack_count := 0
    for child in warehouse.get_node("FurnitureRoot").get_children():
        if String(child.name).begins_with("Rack_"):
            rack_count += 1
        elif child.name == "Node3D":
            for rack in child.get_children():
                if String(rack.name).begins_with("Rack_"):
                    rack_count += 1
    assert(rack_count == 24, "Jumlah rak berubah: %s" % rack_count)
    var hide_area := crate.get_node("Map58CrateHiding")
    assert(hide_area.get("_lid_pivot") == crate.get_node("LidPivot"), "Script tidak mengikat pivot")
    var player := CharacterBody3D.new()
    player.name = "TestPlayer"
    player.position = Vector3(10.0, 0.0, 0.0)
    var player_collision := CollisionShape3D.new()
    player_collision.name = "CollisionShape3D"
    player_collision.shape = CapsuleShape3D.new()
    player.add_child(player_collision)
    var camera := Camera3D.new()
    camera.name = "Camera3D"
    camera.position = Vector3(0.0, 1.6, 0.0)
    player.add_child(camera)
    var body_mesh := MeshInstance3D.new()
    body_mesh.name = "TestBodyMesh"
    body_mesh.mesh = BoxMesh.new()
    player.add_child(body_mesh)
    harness.add_child(player)
    await process_frame
    var original_transform := player.global_transform
    var original_camera_position := camera.position
    hide_area.toggle_hide(player)
    await create_timer(0.95).timeout
    assert(bool(player.get_meta("is_hidden", false)), "Pemain tidak masuk status tersembunyi")
    assert(not body_mesh.visible, "Mesh pemain tidak disembunyikan")
    assert(player_collision.disabled, "Collision pemain tidak dinonaktifkan saat bersembunyi")
    assert(is_equal_approx(float(crate.get_node("LidPivot").rotation.x), 0.055), "Tutup tidak menyisakan celah kecil")
    hide_area.toggle_hide(player)
    await create_timer(0.95).timeout
    assert(not bool(player.get_meta("is_hidden", true)), "Pemain tidak keluar dari status tersembunyi")
    assert(body_mesh.visible, "Mesh pemain tidak dipulihkan")
    assert(not player_collision.disabled, "Collision pemain tidak dipulihkan")
    assert(player.global_position.distance_to(original_transform.origin) < 0.01, "Posisi pemain tidak dipulihkan")
    assert(camera.position.distance_to(original_camera_position) < 0.01, "Posisi kamera tidak dipulihkan")
    print("CRATE_TEST_PASS: load, hinge, hide/exit, mesh/collision/camera restoration; racks=", rack_count)
    quit(0)
