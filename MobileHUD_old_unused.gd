@tool
extends Control
## HUD sentuh baru dengan pilihan uji komputer/HP dari Inspector.
signal movement_changed(direction: Vector2)
signal jump_pressed
signal run_toggled(enabled: bool)
signal crouch_toggled(enabled: bool)

@export_enum("Otomatis", "Komputer", "HP") var test_mode: int = 0:
	set(value):
		test_mode = value
		_apply_test_mode()
@export_tool_button("Uji mode Komputer", "Desktop") var test_computer_action = _test_computer
@export_tool_button("Uji mode HP", "Smartphone") var test_phone_action = _test_phone
@export var joystick_radius := 58.0
var movement_vector := Vector2.ZERO
var run_enabled := false
var crouch_enabled := false
var _jump_requested := false
var _touch_index := -1
var _center := Vector2.ZERO
var _knob: Control

func _test_computer() -> void:
	test_mode = 1
	_apply_test_mode()

func _test_phone() -> void:
	test_mode = 2
	_apply_test_mode()

func _apply_test_mode() -> void:
	if not is_inside_tree():
		return
	var movement := get_node_or_null("Movement")
	var actions := get_node_or_null("Actions")
	if movement == null or actions == null:
		return
	var phone_mode := test_mode == 2 or (test_mode == 0 and OS.has_feature("mobile"))
	movement.visible = phone_mode
	actions.visible = phone_mode

func _ready() -> void:
	_knob = get_node("Movement/Knob")
	_center = get_node("Movement").size * 0.5
	_apply_test_mode()

func _on_jump_pressed() -> void:
	_jump_requested = true
	jump_pressed.emit()

func _on_run_toggled(value: bool) -> void:
	run_enabled = value
	run_toggled.emit(value)

func _on_crouch_toggled(value: bool) -> void:
	crouch_enabled = value
	crouch_toggled.emit(value)

func consume_jump_request() -> bool:
	var was_requested := _jump_requested
	_jump_requested = false
	return was_requested

func is_mobile() -> bool:
	return test_mode == 2 or (test_mode == 0 and OS.has_feature("mobile"))

func _on_joystick_input(event: InputEvent) -> void:
	var stick := get_node("Movement")
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_index = event.index
			_update_stick(event.position)
		elif event.index == _touch_index:
			_touch_index = -1
			movement_vector = Vector2.ZERO
			movement_changed.emit(Vector2.ZERO)
			_center_knob()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_stick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_index = 0
			_update_stick(event.position)
		else:
			_touch_index = -1
			movement_vector = Vector2.ZERO
			movement_changed.emit(Vector2.ZERO)
			_center_knob()
	elif event is InputEventMouseMotion and _touch_index == 0:
		_update_stick(event.position)

func _update_stick(local_position: Vector2) -> void:
	var delta := local_position - _center
	var direction := delta.limit_length(joystick_radius) / joystick_radius
	_knob.position = _center + direction * joystick_radius - _knob.size * 0.5
	movement_vector = direction
	movement_changed.emit(direction)

func _center_knob() -> void:
	if _knob != null:
		_knob.position = _center - _knob.size * 0.5
