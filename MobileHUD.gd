extends Control
## Kontrol sentuh berbasis scene. Logika pemain tetap berada di MobileControls/Player.
signal movement_changed(direction: Vector2)
signal jump_requested
signal run_changed(enabled: bool)
signal crouch_changed(enabled: bool)

@export_enum("Otomatis", "Komputer", "HP") var test_mode: int = 0
@export var joystick_radius := 58.0
var movement_vector := Vector2.ZERO
var run_enabled := false
var crouch_enabled := false
var _touch_id := -1
var _touch_detected := false
var _input_router: Node
var _center := Vector2.ZERO
var _knob: Control
var _knob_tween: Tween

@onready var _stick: Control = $MovementJoystick
@onready var _jump: Button = $JumpButton
@onready var _run: Button = $RunButton
@onready var _crouch: Button = $CrouchButton

func _ready() -> void:
	_input_router = get_tree().root.find_child("InputRouter", true, false)
	_knob = $MovementJoystick/Knob
	_center = _stick.size * 0.5
	# Semua kontrol gameplay berada di satu HUD dan memakai jalur GUI yang konsisten.
	# Joystick hanya menangani sentuhan yang dimulai di area joystick; ia tidak boleh
	# menahan input sentuhan lain yang jatuh pada tombol aksi.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick.mouse_filter = Control.MOUSE_FILTER_STOP
	_jump.mouse_filter = Control.MOUSE_FILTER_STOP
	# Samakan jalur input lari/jongkok dengan tombol Lompat dan tombol HUD lain.
	# Hit-test dan sinyal pressed ditangani Button Godot, bukan koordinat manual.
	_run.mouse_filter = Control.MOUSE_FILTER_STOP
	_crouch.mouse_filter = Control.MOUSE_FILTER_STOP
	for action_button in [_jump, _run, _crouch]:
		action_button.focus_mode = Control.FOCUS_NONE
		action_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_stick.gui_input.connect(_on_stick_input)
	_jump.pressed.connect(func(): jump_requested.emit())
	# Gunakan pressed + baca keadaan toggle terkini supaya status ON/OFF
	# selalu dikirim kembali ke MobileControls setiap kali tombol disentuh.
	_run.pressed.connect(_on_run_pressed)
	_crouch.pressed.connect(_on_crouch_pressed)
	_stick.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.075, 0.72), Color(0.65, 0.78, 0.86, 0.8), 82))
	_knob.add_theme_stylebox_override("panel", _panel_style(Color(0.48, 0.65, 0.75, 0.9), Color(0.9, 0.95, 1.0, 0.95), 40))
	_apply_mode()
	_stick.resized.connect(_recenter)

func _panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style

func is_mobile() -> bool:
	# InputRouter adalah satu-satunya sumber keputusan mode untuk semua kontrol.
	if is_instance_valid(_input_router) and _input_router.has_method("is_mobile_mode"):
		return bool(_input_router.call("is_mobile_mode"))
	if test_mode == 1:
		return false
	if test_mode == 2:
		return true
	return OS.has_feature("mobile") or _touch_detected

func register_touch_input() -> void:
	_touch_detected = true
	_apply_mode()

func set_preview_mode(active: bool) -> void:
	_touch_detected = active
	_apply_mode()

func _apply_mode() -> void:
	var phone := is_mobile()
	for node in [_stick, _jump, _run, _crouch]:
		node.visible = phone

func _recenter() -> void:
	_center = _stick.size * 0.5
	_reset_knob()

func _on_run_pressed() -> void:
	run_enabled = _run.button_pressed
	run_changed.emit(run_enabled)

func _on_crouch_pressed() -> void:
	crouch_enabled = _crouch.button_pressed
	crouch_changed.emit(crouch_enabled)

func _on_stick_input(event: InputEvent) -> void:
	if not is_mobile():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1:
			_touch_id = event.index
			_update_stick(event.position)
		elif not event.pressed and event.index == _touch_id:
			_touch_id = -1
			movement_vector = Vector2.ZERO
			movement_changed.emit(movement_vector)
			_reset_knob(true)
	elif event is InputEventScreenDrag and event.index == _touch_id:
		_update_stick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _touch_id == -1:
				_touch_id = 0
				_update_stick(event.position)
		elif _touch_id == 0:
			_touch_id = -1
			movement_vector = Vector2.ZERO
			movement_changed.emit(movement_vector)
			_reset_knob(true)
	elif event is InputEventMouseMotion and _touch_id == 0:
		_update_stick(event.position)
	# Tandai hanya event yang ditujukan ke joystick sebagai selesai. Ini mencegah
	# event joystick merembet ke kontrol lain, tanpa mengunci sentuhan jari berbeda.
	_stick.accept_event()

func _update_stick(local_pos: Vector2) -> void:
	if _knob_tween != null and _knob_tween.is_valid():
		_knob_tween.kill()
	var offset := (local_pos - _center).limit_length(joystick_radius)
	movement_vector = offset / joystick_radius
	_knob.position = _center + offset - _knob.size * 0.5
	movement_changed.emit(movement_vector)

func _reset_knob(animate: bool = false) -> void:
	if _knob == null:
		return
	if _knob_tween != null and _knob_tween.is_valid():
		_knob_tween.kill()
	var target := _center - _knob.size * 0.5
	if animate and is_inside_tree():
		# Knob meluncur kembali ke tengah, bukan loncat.
		_knob_tween = create_tween()
		_knob_tween.tween_property(_knob, "position", target, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_knob.position = target

# --- Tombol Lompat/Lari/Jongkok: sentuhan langsung per-jari ---
# Godot hanya mengubah SATU jari (yang pertama menyentuh) menjadi event mouse untuk Button.
# Saat jempol kiri menahan joystick, jari kedua di tombol tidak pernah dianggap menekan,
# sehingga tombol terasa mati/susah ditekan. Maka sentuhan dibaca langsung di sini.
func _input(event: InputEvent) -> void:
	if not is_mobile() or _is_input_blocked():
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		# Mouse buatan dari sentuhan di atas tombol dibuang supaya tidak menekan dua kali.
		if event.device == InputEvent.DEVICE_ID_EMULATION and _action_button_at(event.position) != null:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch and event.pressed:
		var button := _action_button_at(event.position)
		if button != null:
			_trigger_action_button(button)
			get_viewport().set_input_as_handled()


func _is_input_blocked() -> bool:
	var layout := get_tree().root.find_child("HUDLayoutManager", true, false)
	if layout != null and layout.has_method("is_editing") and bool(layout.call("is_editing")):
		return true
	var pause_overlay := get_tree().root.find_child("PauseMenuOverlay", true, false) as Control
	return pause_overlay != null and pause_overlay.visible


func _action_button_at(screen_position: Vector2) -> Button:
	# Area sentuh dilebarkan sedikit agar jempol tidak harus tepat di tengah tombol.
	for action_button in [_jump, _run, _crouch]:
		var candidate: Button = action_button
		if candidate != null and candidate.is_visible_in_tree() and not candidate.disabled:
			if candidate.get_global_rect().grow(8.0).has_point(screen_position):
				return candidate
	return null


func _trigger_action_button(button: Button) -> void:
	if button == _jump:
		jump_requested.emit()
	elif button == _run:
		_run.set_pressed_no_signal(not _run.button_pressed)
		_on_run_pressed()
	elif button == _crouch:
		_crouch.set_pressed_no_signal(not _crouch.button_pressed)
		_on_crouch_pressed()
	_punch_button(button)


func _punch_button(button: Control) -> void:
	# Umpan balik tekan: tombol mengecil sedikit lalu memantul kembali.
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2(0.9, 0.9)
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
