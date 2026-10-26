extends Node
## Pengaturan posisi dan ukuran HUD sentuh, terpisah dari logika gameplay.

const CONFIG_PATH := "user://hud_layout.cfg"
const MIN_BUTTON_SIZE := Vector2(34.0, 34.0)
const MAX_SCALE := 2.0
const MIN_SCALE := 0.55

var _controls_root: Control
var _editable_controls: Array[Control] = []
var _saved_layout: Dictionary = {}
var _editor_layer: CanvasLayer
var _editor_root: Control
var _selector: OptionButton
var _scale_slider: HSlider
var _scale_value: Label
var _status_label: Label
var _handles: Dictionary = {}
var _selected_name := ""
var _editing := false
var _dragging_name := ""
var _drag_offset := Vector2.ZERO
var _base_sizes: Dictionary = {}
var _default_rects: Dictionary = {}


func configure(controls_root: Control, editable_controls: Array) -> void:
	_controls_root = controls_root
	_editable_controls.clear()
	for item in editable_controls:
		if item is Control:
			_editable_controls.append(item)
	for control in _editable_controls:
		if is_instance_valid(control):
			_base_sizes[String(control.name)] = control.size
	_load_layout()
	call_deferred("_capture_default_rects")
	call_deferred("_apply_saved_layout")

func has_saved_layout() -> bool:
	return not _saved_layout.is_empty()


func is_editing() -> bool:
	return _editing


func apply_layout() -> void:
	if _editing or _saved_layout.is_empty() or _controls_root == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	for control in _editable_controls:
		if not is_instance_valid(control):
			continue
		var key := String(control.name)
		if not _saved_layout.has(key):
			continue
		var data: Dictionary = _saved_layout[key]
		var pos := Vector2(float(data.get("x", 0.0)) * viewport_size.x, float(data.get("y", 0.0)) * viewport_size.y)
		var sz := Vector2(float(data.get("w", 0.08)) * viewport_size.x, float(data.get("h", 0.08)) * viewport_size.y)
		_set_rect(control, pos, sz)


func open_editor() -> void:
	if _controls_root == null:
		return
	_ensure_editor()
	_editing = true
	_dragging_name = ""
	_editor_layer.visible = true
	_refresh_selector()
	_capture_current_layout_if_needed()
	_refresh_handles()
	_update_scale_for_selection()
	_status_label.text = "Seret tombol untuk memindahkan. Pilih tombol lalu atur ukuran."


func close_editor(save_changes: bool = false) -> void:
	if save_changes:
		save_layout()
	_editing = false
	_dragging_name = ""
	if is_instance_valid(_editor_layer):
		_editor_layer.visible = false


func save_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	_saved_layout.clear()
	for control in _editable_controls:
		if not is_instance_valid(control):
			continue
		var rect := control.get_global_rect()
		_saved_layout[String(control.name)] = {
			"x": clampf(rect.position.x / viewport_size.x, 0.0, 1.0),
			"y": clampf(rect.position.y / viewport_size.y, 0.0, 1.0),
			"w": clampf(rect.size.x / viewport_size.x, 0.025, 0.6),
			"h": clampf(rect.size.y / viewport_size.y, 0.025, 0.6)
		}
	var config := ConfigFile.new()
	config.set_value("hud", "controls", _saved_layout)
	var err := config.save(CONFIG_PATH)
	_status_label.text = "Tata letak tersimpan." if err == OK else "Gagal menyimpan tata letak (%s)." % error_string(err)
	_apply_saved_layout()


func reset_layout() -> void:
	_saved_layout.clear()
	var config := ConfigFile.new()
	config.set_value("hud", "controls", {})
	config.save(CONFIG_PATH)
	# Pulihkan geometri HUD awal yang ditangkap dari scene aktif.
	for control in _editable_controls:
		if not is_instance_valid(control) or not _default_rects.has(String(control.name)):
			continue
		var defaults: Dictionary = _default_rects[String(control.name)]
		control.anchor_left = float(defaults.get("anchor_left", 0.0))
		control.anchor_top = float(defaults.get("anchor_top", 0.0))
		control.anchor_right = float(defaults.get("anchor_right", 0.0))
		control.anchor_bottom = float(defaults.get("anchor_bottom", 0.0))
		control.offset_left = float(defaults.get("offset_left", 0.0))
		control.offset_top = float(defaults.get("offset_top", 0.0))
		control.offset_right = float(defaults.get("offset_right", 0.0))
		control.offset_bottom = float(defaults.get("offset_bottom", 0.0))
		control.custom_minimum_size = defaults.get("minimum_size", Vector2.ZERO)
	_refresh_handles()
	_status_label.text = "Tata letak khusus dihapus dan posisi HUD awal dipulihkan."


func _load_layout() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	var data: Variant = config.get_value("hud", "controls", {})
	if data is Dictionary:
		_saved_layout = data.duplicate(true)


func _capture_default_rects() -> void:
	if not _default_rects.is_empty():
		return
	for control in _editable_controls:
		if is_instance_valid(control):
			_default_rects[String(control.name)] = {
				"anchor_left": control.anchor_left, "anchor_top": control.anchor_top,
				"anchor_right": control.anchor_right, "anchor_bottom": control.anchor_bottom,
				"offset_left": control.offset_left, "offset_top": control.offset_top,
				"offset_right": control.offset_right, "offset_bottom": control.offset_bottom,
				"minimum_size": control.custom_minimum_size
			}

func _apply_saved_layout() -> void:
	apply_layout()


func _capture_current_layout_if_needed() -> void:
	# Posisi bawaan diambil dari HUD aktif; tidak mengganti default atau desain tombol.
	for control in _editable_controls:
		if not is_instance_valid(control):
			continue
		if control.size.x <= 1.0 or control.size.y <= 1.0:
			continue
		_base_sizes[String(control.name)] = control.size


func _ensure_editor() -> void:
	if is_instance_valid(_editor_layer):
		return
	_editor_layer = CanvasLayer.new()
	_editor_layer.name = "HUDLayoutEditorLayer"
	_editor_layer.layer = 50
	_editor_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_editor_layer)
	_editor_root = Control.new()
	_editor_root.name = "HUDLayoutEditorRoot"
	_editor_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_editor_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_editor_layer.add_child(_editor_root)

	var backdrop := ColorRect.new()
	backdrop.name = "EditorBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.025, 0.04, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_editor_root.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.name = "HUDLayoutTools"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(14.0, 14.0)
	panel.custom_minimum_size = Vector2(310.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_editor_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = "ATUR TOMBOL HUD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Seret tombol di layar. Ukuran diatur untuk tombol terpilih."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	_selector = OptionButton.new()
	_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selector.item_selected.connect(_on_control_selected)
	box.add_child(_selector)
	_scale_value = Label.new()
	_scale_value.text = "Ukuran: 100%"
	box.add_child(_scale_value)
	_scale_slider = HSlider.new()
	_scale_slider.min_value = MIN_SCALE
	_scale_slider.max_value = MAX_SCALE
	_scale_slider.step = 0.05
	_scale_slider.value = 1.0
	_scale_slider.value_changed.connect(_on_scale_changed)
	box.add_child(_scale_slider)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "Seret tombol untuk memindahkan."
	box.add_child(_status_label)
	var save_button := Button.new()
	save_button.text = "SIMPAN TATA LETAK"
	save_button.custom_minimum_size.y = 42
	save_button.pressed.connect(func(): save_layout())
	box.add_child(save_button)
	var reset_button := Button.new()
	reset_button.text = "RESET POSISI"
	reset_button.custom_minimum_size.y = 38
	reset_button.pressed.connect(reset_layout)
	box.add_child(reset_button)
	var close_button := Button.new()
	close_button.text = "SELESAI"
	close_button.custom_minimum_size.y = 38
	close_button.pressed.connect(func(): close_editor(false))
	box.add_child(close_button)


func _refresh_selector() -> void:
	if _selector == null:
		return
	_selector.clear()
	var selected_index := 0
	for i in range(_editable_controls.size()):
		var control := _editable_controls[i]
		if not is_instance_valid(control):
			continue
		_selector.add_item(_display_name(String(control.name)))
		_selector.set_item_metadata(_selector.item_count - 1, String(control.name))
		if String(control.name) == _selected_name:
			selected_index = _selector.item_count - 1
	if _selector.item_count > 0:
		_selector.select(selected_index)
		_selected_name = String(_selector.get_item_metadata(selected_index))


func _display_name(key: String) -> String:
	var names := {
		"MovementJoystick": "Joystick",
		"LOMPATButton": "Lompat",
		"LARIButton": "Lari",
		"JONGKOKButton": "Jongkok",
		"SuaraButton": "Suara",
		"MikrofonButton": "Mikrofon",
		"ChatButton": "Chat",
		"DropItemButton": "Jatuhkan item",
		"ContextInteractButton": "Interaksi",
		"ContextHideButton": "Sembunyi / Keluar",
		"ContextHealButton": "Sembuhkan",
		"InventorySlot1": "Slot inventori 1",
		"InventorySlot2": "Slot inventori 2"
	}
	return String(names.get(key, key))


func _on_control_selected(index: int) -> void:
	if _selector == null or index < 0 or index >= _selector.item_count:
		return
	_selected_name = String(_selector.get_item_metadata(index))
	_update_scale_for_selection()


func _update_scale_for_selection() -> void:
	var control := _find_control(_selected_name)
	if control == null or _scale_slider == null:
		return
	var base_size: Vector2 = _base_sizes.get(_selected_name, control.size)
	var scale_x := control.size.x / maxf(base_size.x, 1.0)
	var scale_y := control.size.y / maxf(base_size.y, 1.0)
	_scale_slider.set_value_no_signal(clampf((scale_x + scale_y) * 0.5, MIN_SCALE, MAX_SCALE))
	_scale_value.text = "Ukuran: %d%%" % int(round(_scale_slider.value * 100.0))


func _on_scale_changed(value: float) -> void:
	var control := _find_control(_selected_name)
	if control == null:
		return
	var base_size: Vector2 = _base_sizes.get(_selected_name, control.size)
	var new_size := Vector2(maxf(MIN_BUTTON_SIZE.x, base_size.x * value), maxf(MIN_BUTTON_SIZE.y, base_size.y * value))
	_set_rect(control, control.get_global_rect().position, new_size)
	_scale_value.text = "Ukuran: %d%%" % int(round(value * 100.0))
	_refresh_handles()


func _find_control(key: String) -> Control:
	for control in _editable_controls:
		if is_instance_valid(control) and String(control.name) == key:
			return control
	return null


func _set_rect(control: Control, pos: Vector2, sz: Vector2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
	control.position = Vector2(clampf(pos.x, 0.0, maxf(0.0, get_viewport().get_visible_rect().size.x - sz.x)), clampf(pos.y, 0.0, maxf(0.0, get_viewport().get_visible_rect().size.y - sz.y)))
	control.size = Vector2(maxf(MIN_BUTTON_SIZE.x, sz.x), maxf(MIN_BUTTON_SIZE.y, sz.y))
	if control is Container:
		control.custom_minimum_size = control.size


func _refresh_handles() -> void:
	if not is_instance_valid(_editor_root):
		return
	for child in _editor_root.get_children():
		if String(child.name).begins_with("HUDHandle_"):
			child.queue_free()
	_handles.clear()
	for control in _editable_controls:
		if not is_instance_valid(control):
			continue
		var handle := Panel.new()
		handle.name = "HUDHandle_" + String(control.name)
		handle.position = control.get_global_rect().position
		handle.size = control.get_global_rect().size
		handle.mouse_filter = Control.MOUSE_FILTER_STOP
		handle.focus_mode = Control.FOCUS_NONE
		handle.z_index = 20
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.65, 0.9, 0.12)
		style.border_color = Color(0.45, 0.82, 1.0, 0.95) if String(control.name) == _selected_name else Color(0.85, 0.9, 0.95, 0.65)
		style.set_border_width_all(2)
		style.set_corner_radius_all(5)
		handle.add_theme_stylebox_override("panel", style)
		handle.gui_input.connect(_on_handle_input.bind(String(control.name)))
		_editor_root.add_child(handle)
		_handles[String(control.name)] = handle
	var tools_panel := _editor_root.get_node_or_null("HUDLayoutTools")
	if tools_panel != null:
		_editor_root.move_child(tools_panel, _editor_root.get_child_count() - 1)


func _on_handle_input(event: InputEvent, key: String) -> void:
	if not _editing:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_drag(key, get_viewport().get_mouse_position())
	elif event is InputEventScreenTouch and event.pressed:
		var handle: Control = _handles.get(key)
		var pointer_position: Vector2 = event.position + (handle.position if is_instance_valid(handle) else Vector2.ZERO)
		_begin_drag(key, pointer_position)


func _begin_drag(key: String, pointer_position: Vector2) -> void:
	_dragging_name = key
	_selected_name = key
	var control := _find_control(key)
	if control != null:
		_drag_offset = pointer_position - control.get_global_rect().position
	if _selector != null:
		for i in range(_selector.item_count):
			if String(_selector.get_item_metadata(i)) == key:
				_selector.select(i)
				break
	_update_scale_for_selection()


func _drag_control(key: String, pointer_position: Vector2) -> void:
	var control := _find_control(key)
	if control == null:
		return
	_set_rect(control, pointer_position - _drag_offset, control.size)
	var handle: Control = _handles.get(key)
	if is_instance_valid(handle):
		handle.position = control.get_global_rect().position

func _end_drag() -> void:
	_dragging_name = ""


func _input(event: InputEvent) -> void:
	if not _editing or _dragging_name.is_empty():
		return
	if event is InputEventMouseMotion:
		_drag_control(_dragging_name, get_viewport().get_mouse_position())
	elif event is InputEventScreenDrag:
		_drag_control(_dragging_name, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag()
	elif event is InputEventScreenTouch and not event.pressed:
		_end_drag()


func _process(_delta: float) -> void:
	if _editing and _dragging_name == "":
		# Perbarui posisi handle untuk kontrol yang berubah karena konteks permainan.
		for key in _handles.keys():
			var control := _find_control(String(key))
			var handle: Control = _handles[key]
			if control != null and is_instance_valid(handle):
				handle.position = control.get_global_rect().position
				handle.size = control.get_global_rect().size
