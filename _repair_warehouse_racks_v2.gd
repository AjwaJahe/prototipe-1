extends SceneTree

func set_owner_recursive(n: Node, owner_node: Node) -> void:
    for c in n.get_children():
        c.owner = owner_node
        set_owner_recursive(c, owner_node)

func _init() -> void:
    var packed := load("res://Warehouse_Furniture.tscn")
    if packed == null:
        push_error("Warehouse scene gagal dimuat.")
        quit()
        return

    var scene_root: Node = packed.instantiate()
    root.add_child(scene_root)

    var furniture_root: Node = scene_root.get_node_or_null("FurnitureRoot")
    if furniture_root == null:
        push_error("FurnitureRoot tidak ditemukan.")
        quit()
        return

    # Ownership harus dipasang SEBELUM duplicating agar seluruh subtree ikut.
    set_owner_recursive(scene_root, scene_root)

    var base: Node = furniture_root.get_node_or_null("Rack_Right_01")
    if base == null:
        push_error("Rack_Right_01 tidak ditemukan.")
        quit()
        return

    # Buang hanya rak tambahan yang kosong akibat clone sebelumnya.
    for n in [
        "Rack_East_01", "Rack_East_02", "Rack_East_03", "Rack_East_04", "Rack_East_05",
        "Rack_West_01", "Rack_West_02", "Rack_West_03", "Rack_West_04"
    ]:
        var old: Node = furniture_root.get_node_or_null(n)
        if old != null:
            old.queue_free()

    await process_frame

    var east_positions := [
        Vector3(8.2, 0, -8.0),
        Vector3(8.2, 0, -3.0),
        Vector3(8.2, 0, 2.0),
        Vector3(8.2, 0, 7.0),
        Vector3(8.2, 0, 10.6)
    ]

    var west_positions := [
        Vector3(-8.2, 0, -7.0),
        Vector3(-8.2, 0, -2.0),
        Vector3(-8.2, 0, 3.0),
        Vector3(-8.2, 0, 8.0)
    ]

    for i in range(east_positions.size()):
        var r: Node = base.duplicate()
        r.name = "Rack_East_%02d" % (i + 1)
        r.position = east_positions[i]
        r.rotation = Vector3(0, PI * 0.5, 0)
        furniture_root.add_child(r)

    for i in range(west_positions.size()):
        var r: Node = base.duplicate()
        r.name = "Rack_West_%02d" % (i + 1)
        r.position = west_positions[i]
        r.rotation = Vector3(0, PI * 0.5, 0)
        furniture_root.add_child(r)

    set_owner_recursive(scene_root, scene_root)

    var output := PackedScene.new()
    var err := output.pack(scene_root)
    if err != OK:
        push_error("Gagal pack Warehouse_Furniture: " + str(err))
        scene_root.free()
        quit()
        return

    var save_err := ResourceSaver.save(output, "res://Warehouse_Furniture.tscn")
    print("SAVE=", save_err)
    scene_root.free()
    quit()
