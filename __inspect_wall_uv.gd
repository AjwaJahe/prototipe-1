extends SceneTree

func _init() -> void:
	var out := FileAccess.open("res://__inspect_wall_uv_out.txt", FileAccess.WRITE)
	if out == null:
		quit()
		return
	var scene := load("res://map58/Map58_DoorWalls.tscn") as PackedScene
	out.store_line("SCENE="+str(scene != null))
	if scene == null:
		out.close()
		quit()
		return
	var root := scene.instantiate()
	var count := 0
	for n in root.get_children():
		if n is MeshInstance3D and n.mesh is ArrayMesh:
			var am := n.mesh as ArrayMesh
			if am.get_surface_count() > 0:
				var arr := am.surface_get_arrays(0)
				var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				out.store_line("NAME="+n.name+" VERT="+str(verts.size())+" UV="+str(uvs.size()))
				if uvs.size() > 0:
					var mn := uvs[0]
					var mx := uvs[0]
					for uv in uvs:
						mn.x=min(mn.x,uv.x); mn.y=min(mn.y,uv.y)
						mx.x=max(mx.x,uv.x); mx.y=max(mx.y,uv.y)
					out.store_line("RANGE="+str(mn)+".."+str(mx))
				count += 1
				if count >= 12:
					break
	root.free()
	out.store_line("COUNT="+str(count))
	out.close()
	quit()
