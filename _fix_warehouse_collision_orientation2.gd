extends SceneTree

func _initialize() -> void:
    var path := ProjectSettings.globalize_path("res://Warehouse_Furniture.tscn")
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        print("OPEN_FAIL")
        quit()
        return
    var lines := f.get_as_text().split("\n")
    f.close()

    var ids := {
        "454678784": "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0, 2.1, 0)",
        "2130026660": "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0, 2.1, 0)",
        "963309675": "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0, 2.1, 0)",
        "989427333": "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0, 2.1, 0)",
        "1957175813": "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0, 2.1, 0)",
        "464389232": "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0, 2.1, 0)",
        "1095873998": "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0, 2.1, 0)",
        "222221377": "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0, 2.1, 0)",
        "123115243": "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0, 2.1, 0)",
        "664291903": "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0, 2.1, 0)",
        "732426974": "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0, 2.1, 0)",
        "964230858": "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0, 2.1, 0)",
        "1056466777": "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0, 2.1, 0)",
        "2102510429": "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0, 2.1, 0)",
        "1976014470": "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0, 0.53999996, 0)",
        "2058124065": "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0, 0.53999996, 0)"
    }

    var changed := 0
    for i in range(lines.size() - 1):
        var line: String = lines[i]
        if line.contains("unique_id="):
            for uid in ids.keys():
                if line.contains("unique_id=" + uid + "]"):
                    if lines[i + 1].begins_with("transform = Transform3D("):
                        lines[i + 1] = ids[uid]
                        changed += 1

    var out := FileAccess.open(path, FileAccess.WRITE)
    out.store_string("\n".join(lines))
    out.close()
    print("CHANGED=", changed)
    quit()
