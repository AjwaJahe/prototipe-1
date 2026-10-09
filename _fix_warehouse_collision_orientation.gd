extends SceneTree

const SCENE_PATH := "res://Warehouse_Furniture.tscn"

func _initialize() -> void:
    var abs_path := ProjectSettings.globalize_path(SCENE_PATH)
    var f := FileAccess.open(abs_path, FileAccess.READ)
    if f == null:
        printerr("GAGAL membuka Warehouse_Furniture.tscn")
        quit(1)
        return

    var lines := f.get_as_text().split("\n")
    f.close()

    var rotated_groups: Dictionary = {}
    var current_name := ""
    var current_parent := ""
    var current_group := ""
    var current_is_post_l := false
    var pending_collision_group := ""
    var pending_collision := false
    var changed := 0

    for i in range(lines.size()):
        var line: String = lines[i]

        if line.begins_with("[node "):
            current_name = ""
            current_parent = ""
            current_is_post_l = false

            var m_name := RegEx.new()
            m_name.compile('name="([^"]+)"')
            var nm := m_name.search(line)
            if nm:
                current_name = nm.get_string(1)

            var m_parent := RegEx.new()
            m_parent.compile('parent="([^"]+)"')
            var pm := m_parent.search(line)
            if pm:
                current_parent = pm.get_string(1)

            if current_name.begins_with("Rack_"):
                current_group = current_name

            current_is_post_l = current_name == "PostL" and current_parent.contains("Rack_")

            pending_collision = current_name == "CollisionShape3D"
            pending_collision_group = ""
            if pending_collision and current_parent.ends_with("/FurnitureCollision"):
                pending_collision_group = current_parent.trim_suffix("/FurnitureCollision").get_slice("/", 1)
                if pending_collision_group == "":
                    pending_collision_group = current_parent
            continue

        if line.begins_with("transform = Transform3D("):
            if current_is_post_l and current_parent.contains("Rack_"):
                var raw := line.trim_prefix("transform = Transform3D(").trim_suffix(")")
                var p := raw.split(",")
                if p.size() >= 9:
                    var a = abs(float(p[0].strip_edges()))
                    var c = abs(float(p[2].strip_edges()))
                    if a < 0.01 and c > 0.9:
                        var rg := current_parent.get_slice("/", current_parent.get_slice_count("/") - 1)
                        rotated_groups[rg] = true

            if pending_collision and pending_collision_group != "":
                var g := pending_collision_group
                var should_rotate := false
                if g == "PackingTable":
                    should_rotate = true
                elif rotated_groups.has(g):
                    should_rotate = true

                if should_rotate:
                    lines[i] = "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0, 2.1, 0)"
                    changed += 1
            pending_collision = false

    if changed == 0:
        printerr("Tidak ada collider gudang yang perlu diputar.")
        quit(2)
        return

    var out := FileAccess.open(abs_path, FileAccess.WRITE)
    if out == null:
        printerr("GAGAL menyimpan Warehouse_Furniture.tscn")
        quit(3)
        return
    out.store_string("\n".join(lines))
    out.close()

    print("Warehouse collision orientation fixed. Changed colliders: ", changed)
    print("Detected rotated rack groups: ", rotated_groups.keys())
    quit(0)
