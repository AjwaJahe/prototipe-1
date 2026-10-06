extends SceneTree
var lines=PackedStringArray()
func _init():
    var ps=load("res://map58/Map58.tscn") as PackedScene
    var root=ps.instantiate()
    walk(root)
    var f=FileAccess.open("res://_floor_bounds_out.txt",FileAccess.WRITE)
    f.store_string("\n".join(lines))
    f.close()
    quit()
func walk(n):
    if n is MeshInstance3D:
        var name=n.name
        if name.ends_with("_Floor"):
            var m=n as MeshInstance3D
            var a=m.get_aabb()
            var gt=m.global_transform
            var corners=[a.position,a.position+Vector3(a.size.x,0,0),a.position+Vector3(0,0,a.size.z),a.position+Vector3(a.size.x,0,a.size.z)]
            var minv=Vector3(INF,INF,INF)
            var maxv=Vector3(-INF,-INF,-INF)
            for c in corners:
                var w=gt*c
                minv=minv.min(w); maxv=maxv.max(w)
            lines.append(name+"|"+str(minv)+"|"+str(maxv))
    for c in n.get_children():
        walk(c)
