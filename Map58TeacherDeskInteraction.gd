extends Node3D
## Interaksi laci meja guru; muka laci menghadap sisi kursi guru.

var _drawer_open := false
var _busy := false
var _highlighted := false
var _drawer_front: MeshInstance3D
var _drawer_pull: MeshInstance3D
var _tray_parts: Array[MeshInstance3D] = []
var _glow_material: ShaderMaterial
var _previous_overlays: Dictionary = {}

# Sisi X negatif adalah sisi panel depan murid; laci berada di sisi sebaliknya.
const DRAWER_CLOSED_FRONT := Vector3(0.535, 0.83, 0.0)
const DRAWER_CLOSED_PULL := Vector3(0.575, 0.83, 0.0)
const DRAWER_OPEN_OFFSET := Vector3(0.225, 0.0, 0.0)


func configure() -> void:
	if get_meta("teacher_drawer_configured", false):
		return
	set_meta("teacher_drawer_configured", true)
	set_meta("interaction_type", "drawer")
	set_meta("display_name", "Laci meja guru")
	_drawer_front = get_node_or_null("DrawerFront") as MeshInstance3D
	_drawer_pull = get_node_or_null("DrawerPull") as MeshInstance3D
	if _drawer_front == null:
		push_warning("Teacher desk: DrawerFront tidak ditemukan.")
	if _drawer_pull == null:
		push_warning("Teacher desk: DrawerPull tidak ditemukan.")
	if _drawer_front != null:
		_drawer_front.position = DRAWER_CLOSED_FRONT
	if _drawer_pull != null:
		_drawer_pull.position = DRAWER_CLOSED_PULL
	_create_drawer_tray()
	_glow_material = _make_glow_material()


func _create_drawer_tray() -> void:
	var wood_material: Material = _drawer_front.material_override if _drawer_front != null else null
	if get_node_or_null("DrawerTrayBottom") == null:
		_add_tray_part("DrawerTrayBottom", Vector3(0.30, 0.745, 0.0), Vector3(0.42, 0.025, 0.44), wood_material)
		_add_tray_part("DrawerTraySideLeft", Vector3(0.30, 0.785, -0.218), Vector3(0.42, 0.08, 0.024), wood_material)
		_add_tray_part("DrawerTraySideRight", Vector3(0.30, 0.785, 0.218), Vector3(0.42, 0.08, 0.024), wood_material)
		_add_tray_part("DrawerTrayBack", Vector3(0.085, 0.785, 0.0), Vector3(0.024, 0.08, 0.44), wood_material)
	else:
		for part_name in ["DrawerTrayBottom", "DrawerTraySideLeft", "DrawerTraySideRight", "DrawerTrayBack"]:
			var existing := get_node_or_null(part_name) as MeshInstance3D
			if existing != null:
				if not existing.has_meta("drawer_closed_position"):
					existing.set_meta("drawer_closed_position", existing.position)
				_tray_parts.append(existing)


func _add_tray_part(part_name: String, part_position: Vector3, part_size: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var box := BoxMesh.new()
	box.size = part_size
	part.mesh = box
	part.position = part_position
	part.set_meta("drawer_closed_position", part_position)
	if material != null:
		part.material_override = material
	add_child(part)
	_tray_parts.append(part)


func interact(_player: Node = null) -> void:
	if _busy or _drawer_front == null:
		return
	_busy = true
	_drawer_open = not _drawer_open
	var audio := get_tree().get_first_node_in_group("game_audio")
	if audio != null:
		if audio.has_method("play_sfx_for_duration"):
			audio.play_sfx_for_duration("drawer_open_close", 0.24, global_position)
		elif audio.has_method("play_sfx"):
			audio.play_sfx("drawer_open_close", global_position)
	var offset := DRAWER_OPEN_OFFSET if _drawer_open else Vector3.ZERO
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_drawer_front, "position", DRAWER_CLOSED_FRONT + offset, 0.24)
	if _drawer_pull != null:
		tween.parallel().tween_property(_drawer_pull, "position", DRAWER_CLOSED_PULL + offset, 0.24)
	for part in _tray_parts:
		if is_instance_valid(part):
			var closed_position: Vector3 = part.get_meta("drawer_closed_position")
			tween.parallel().tween_property(part, "position", closed_position + offset, 0.24)
	tween.finished.connect(func() -> void:
		_busy = false
	)


func set_interaction_highlight(enabled: bool) -> void:
	if _highlighted == enabled:
		return
	_highlighted = enabled
	_set_drawer_outline(_drawer_front, enabled)
	_set_drawer_outline(_drawer_pull, enabled)


func _set_drawer_outline(mesh: MeshInstance3D, enabled: bool) -> void:
	if not is_instance_valid(mesh):
		return
	var id := mesh.get_instance_id()
	if enabled:
		if not _previous_overlays.has(id):
			_previous_overlays[id] = mesh.material_overlay
		mesh.material_overlay = _glow_material
	elif _previous_overlays.has(id):
		mesh.material_overlay = _previous_overlays[id] as Material
		_previous_overlays.erase(id)


func _make_glow_material() -> ShaderMaterial:
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
