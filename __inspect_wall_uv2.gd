extends SceneTree

func _init() -> void:
	print("START")
	var scene = load("res://map58/Map58_DoorWalls.tscn")
	print("SCENE=", scene)
	if scene == null:
		quit()
		return
	var root = scene.instantiate()
	print("ROOT=", root.name)
	var count = 0
	for n in root.get_children():
		if n is MeshInstance3D and n.mesh is ArrayMesh:
			var am = n.mesh as ArrayMesh
			if am.get_surface_count() > 0:
				var arr = am.surface_get_arrays(0)
				var uvs = arr[Mesh.ARRAY_TEX_UV]
				print("NODE=", n.name, " UVS=", uvs.size())
				if uvs.size() > 0:
					var mn = uvs[0]
					var mx = uvs[0]
					for uv in uvs:
						mn.x=min(mn.x,uv.x); mn.y=min(mn.y,uv.y)
						mx.x=max(mx.x,uv.x); mx.y=max(mx.y,uv.y)
					print(" RANGE=",mn,"..",mx)
				count += 1
				if count >= 8:
					break
	print("DONE")
	quit()
