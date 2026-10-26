extends Node3D

## Highlight hanya memengaruhi mesh di dalam instance furnitur ini.
var _highlight_material: ShaderMaterial
var _highlighted := false

func _ready() -> void:
	set_meta("interaction_type", "furniture")
	set_meta("display_name", name.replace("_", " "))
	_highlight_material = _make_highlight_material()

func interact(_player: Node = null) -> void:
	# Furnitur perpustakaan saat ini hanya memberi petunjuk interaksi.
	pass

func set_highlighted(_enabled: bool) -> void:
	# Sorotan umum furnitur dinonaktifkan sepenuhnya.
	# Efek sorot hanya ditangani oleh LibraryDrawerInteract pada laci.
	return

func _apply_to_meshes(node: Node, enabled: bool) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if enabled:
			if not mesh_instance.has_meta("_library_previous_overlay"):
				mesh_instance.set_meta("_library_previous_overlay", mesh_instance.material_overlay)
			mesh_instance.material_overlay = _highlight_material
		elif mesh_instance.has_meta("_library_previous_overlay"):
			mesh_instance.material_overlay = mesh_instance.get_meta("_library_previous_overlay") as Material
			mesh_instance.remove_meta("_library_previous_overlay")
	for child in node.get_children():
		_apply_to_meshes(child, enabled)

func _make_highlight_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;
uniform vec4 outline_color : source_color = vec4(1.0, 0.82, 0.25, 1.0);
uniform float outline_size = 0.025;
void vertex() { VERTEX += NORMAL * outline_size; }
void fragment() {
	ALBEDO = outline_color.rgb;
	EMISSION = outline_color.rgb * 0.85;
	ROUGHNESS = 1.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material
