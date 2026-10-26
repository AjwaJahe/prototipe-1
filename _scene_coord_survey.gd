extends SceneTree

const TARGETS := [
	"res://main.tscn",
	"res://map58/Map58.tscn",
	"res://map_58.tscn",
	"res://Map58_Furniture.tscn",
	"res://Kelas_10_A_Furniture.tscn",
	"res://TeacherRoom_Furniture.tscn",
	"res://Administration_Furniture.tscn",
	"res://Library_Furniture.tscn",
	"res://PrincipalOffice_Furniture.tscn",
	"res://Kantin_Furniture.tscn",
	"res://Warehouse_Furniture.tscn",
	"res://UKS_Furniture.tscn",
	"res://MaleToilet_Furniture.tscn",
	"res://FemaleToilet_Furniture.tscn",
	"res://GuestRoom_Furniture.tscn",
	"res://ToiletSketsel_Furniture.tscn",
	"res://BasketballCourt.tscn",
	"res://BasketballBleachers.tscn",
	"res://Teacher.tscn",
	"res://player.tscn",
	"res://PintuSekolah.tscn",
	"res://PintuKelas.tscn"
]

var lines := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for path: String in TARGETS:
		var packed := load(path) as PackedScene
		if packed == null:
			lines.append("LOAD_FAIL|" + path)
			continue
		var scene := packed.instantiate()
		root.add_child(scene)
		await process_frame
		lines.append("\nSCENE|" + path + "|root_global=" + _v3(scene.global_position if scene is Node3D else Vector3.ZERO))
		_walk(scene, path)
		root.remove_child(scene)
		scene.free()
		await process_frame
	var output := "\n".join(lines)
	var file := FileAccess.open("res://_scene_coord_survey.txt", FileAccess.WRITE)
	if file != null:
		file.store_string(output)
		file.close()
	print(output)
	quit()

func _walk(node: Node, scene_path: String) -> void:
	if node is Node3D:
		var n := node as Node3D
		var nm := String(n.name)
		if n is Marker3D or nm.to_lower().contains("door") or nm.to_lower().contains("spawn") or nm.to_lower().contains("waypoint") or nm.to_lower().contains("point") or nm.to_lower().contains("teacher") or nm.to_lower().contains("basketball") or nm.to_lower().contains("corridor") or nm.to_lower().contains("classroom") or nm.to_lower().contains("floor"):
			lines.append("NODE|" + scene_path + "|" + str(n.get_path()) + "|type=" + n.get_class() + "|local=" + _v3(n.position) + "|global=" + _v3(n.global_position))
	for child: Node in node.get_children():
		_walk(child, scene_path)

func _v3(v: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z]
