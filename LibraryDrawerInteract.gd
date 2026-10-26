extends Area3D
## Interactive wooden drawer that slides with its collision area.
const SLIDE_DISTANCE := 0.34
const ANIMATION_TIME := 0.26
var _is_open := false
var _busy := false
var _closed_position := Vector3.ZERO
var _drawer_width := 0.94
var _visual: Node3D
var _highlight_material: ShaderMaterial
var _highlighted := false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	_closed_position = position
	_drawer_width = float(get_meta("drawer_width", 0.94))
	set_meta("interaction_type", "furniture")
	set_meta("display_name", "Laci")
	_build_visual()

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "DrawerVisual"
	add_child(_visual)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.27, 0.12, 0.045)
	wood.roughness = 0.86
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.055, 0.035, 0.025)
	dark.roughness = 0.95
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.55, 0.38, 0.12)
	brass.metallic = 0.72
	brass.roughness = 0.34

	_add_box("DrawerBottom", Vector3(0.0, -0.085, -0.06), Vector3(_drawer_width * 0.90, 0.035, 0.28), dark)
	_add_box("DrawerLeft", Vector3(-_drawer_width * 0.45, 0.0, -0.06), Vector3(0.035, 0.18, 0.28), wood)
	_add_box("DrawerRight", Vector3(_drawer_width * 0.45, 0.0, -0.06), Vector3(0.035, 0.18, 0.28), wood)
	_add_box("DrawerBack", Vector3(0.0, 0.0, -0.19), Vector3(_drawer_width * 0.86, 0.18, 0.035), wood)
	_add_box("DrawerFront", Vector3(0.0, 0.0, 0.105), Vector3(_drawer_width, 0.23, 0.055), wood)
	_add_box("Handle", Vector3(0.0, 0.0, 0.145), Vector3(0.18, 0.035, 0.035), brass)

func _add_box(node_name: String, local_position: Vector3, box_size: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	_visual.add_child(mesh_instance)

func set_highlighted(enabled: bool) -> void:
	if _highlighted == enabled or not is_instance_valid(_visual):
		return
	_highlighted = enabled
	if _highlight_material == null:
		_highlight_material = _make_highlight_material()
	_apply_drawer_overlay(_visual, enabled)

func _apply_drawer_overlay(node: Node, enabled: bool) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if enabled:
			if not mesh_instance.has_meta("_drawer_previous_overlay"):
				mesh_instance.set_meta("_drawer_previous_overlay", mesh_instance.material_overlay)
			mesh_instance.material_overlay = _highlight_material
		elif mesh_instance.has_meta("_drawer_previous_overlay"):
			mesh_instance.material_overlay = mesh_instance.get_meta("_drawer_previous_overlay") as Material
			mesh_instance.remove_meta("_drawer_previous_overlay")
	for child in node.get_children():
		_apply_drawer_overlay(child, enabled)

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

func interact(player: Node = null) -> void:
	if _busy or not is_instance_valid(_visual):
		return
	_busy = true
	_is_open = not _is_open
	var audio := get_tree().get_first_node_in_group("game_audio")
	if audio != null:
		if audio.has_method("play_sfx_for_duration"):
			audio.play_sfx_for_duration("drawer_open_close", ANIMATION_TIME, global_position)
		elif audio.has_method("play_sfx"):
			audio.play_sfx("drawer_open_close", global_position)
	var target_z := _closed_position.z + (SLIDE_DISTANCE if _is_open else 0.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:z", target_z, ANIMATION_TIME)
	tween.finished.connect(func() -> void:
		_busy = false
	)
	if player != null:
		var inventory := player.get_node_or_null("ItemInventory")
		if inventory != null and inventory.has_method("_set_status"):
			inventory.call("_set_status", "Laci dibuka." if _is_open else "Laci ditutup.")
