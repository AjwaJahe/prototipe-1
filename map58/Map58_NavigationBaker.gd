extends NavigationRegion3D

## Bake NavigationMesh dari model Map58 (Visual) saat game dimulai jika
## navigation mesh belum pernah di-bake di editor.

@export var source_path: NodePath = ^"../Visual"


func _ready() -> void:
	if navigation_mesh == null:
		push_warning("Map58 NavigationBaker: NavigationMesh belum di-assign.")
		return

	var source := get_node_or_null(source_path)
	if source != null:
		source.add_to_group(navigation_mesh.geometry_source_group_name)

	if navigation_mesh.get_polygon_count() == 0:
		call_deferred("_bake_when_ready")


func _bake_when_ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	bake_navigation_mesh(true)
