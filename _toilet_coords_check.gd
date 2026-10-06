extends SceneTree

func bbox_to_file(out: FileAccess, n: Node) -> void:
    if not n is VisualInstance3D:
        return
    var m := n as VisualInstance3D
    var a := m.get_aabb()
    var t := m.global_transform
    var mn := Vector3(INF, INF, INF)
    var mx := Vector3(-INF, -INF, -INF)
    for c in [
        a.position,
        a.position + Vector3(a.size.x,0,0),
        a.position + Vector3(0,a.size.y,0),
        a.position + Vector3(0,0,a.size.z),
        a.position + Vector3(a.size.x,a.size.y,0),
        a.position + Vector3(a.size.x,0,a.size.z),
        a.position + Vector3(0,a.size.y,a.size.z),
        a.position + a.size
    ]:
        var q := t * c
        mn.x=min(mn.x,q.x); mn.y=min(mn.y,q.y); mn.z=min(mn.z,q.z)
        mx.x=max(mx.x,q.x); mx.y=max(mx.y,q.y); mx.z=max(mx.z,q.z)
    out.store_line(str(n.get_path())+" pos="+str(n.global_position)+" min="+str(mn)+" max="+str(mx))

func _init() -> void:
    var out := FileAccess.open("res://_toilet_coords_check.txt", FileAccess.WRITE)
    var packed := load("res://main.tscn")
    out.store_line("packed="+str(packed != null))
    if packed == null:
        out.close()
        quit()
        return
    var s := packed.instantiate()
    root.add_child(s)
    var map58 := s.get_node_or_null("Map58")
    var furn := s.get_node_or_null("Furniture")
    out.store_line("Map58_exists="+str(map58 != null))
    out.store_line("Furniture_exists="+str(furn != null))
    if map58:
        out.store_line("Map58_global_pos="+str(map58.global_position))
        var tf := map58.find_child("Toilet_Pria_Floor", true, false)
        if tf:
            bbox_to_file(out, tf)
        else:
            out.store_line("Toilet_Pria_Floor NOT_FOUND")
    if furn:
        var tfurn := furn.get_node_or_null("MaleToilet_Furniture")
        out.store_line("MaleToilet_exists="+str(tfurn != null))
        if tfurn:
            out.store_line("MaleToilet_local="+str(tfurn.position))
            out.store_line("MaleToilet_global="+str(tfurn.global_position))
            out.store_line("MaleToilet_transform="+str(tfurn.global_transform))
    out.close()
    quit()
