extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://main.tscn") as PackedScene
    assert(packed != null, "main.tscn gagal dimuat")
    var game := packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var furniture := game.get_node_or_null("Furniture")
    assert(furniture != null, "Furniture tidak ditemukan")
    for door_name in ["PintuKelas_12_D_South", "PintuKelas_12_D_North"]:
        var door := furniture.get_node_or_null(door_name)
        assert(door != null, "%s tidak ditemukan" % door_name)
        assert(door.has_method("is_locked"), "%s tidak memiliki is_locked()" % door_name)
        assert(door.call("is_locked"), "%s seharusnya terkunci" % door_name)
        assert(String(door.get("required_item_type")) == "class_key", "%s tidak memerlukan class_key" % door_name)
        var player := CharacterBody3D.new()
        player.name = "TestPlayer"
        furniture.add_child(player)
        door.call("interact", player)
        assert(not bool(door.call("is_open")), "%s terbuka tanpa kunci" % door_name)
        player.queue_free()
    print("LOCKED_DOORS_PASS: dua pintu kelas terkunci; interaksi tanpa kunci tidak membukanya.")
    quit(0)
