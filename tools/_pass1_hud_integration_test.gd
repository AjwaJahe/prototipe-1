extends SceneTree

var failures: Array[String] = []
var jump_signal_count := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed := load("res://player.tscn") as PackedScene
	if packed == null:
		_fail("player.tscn gagal dimuat")
		_finish()
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var player := instance.get_node_or_null("CharacterBody3D")
	var controls := player.get_node_or_null("MobileControls") if player != null else null
	if controls != null and controls.has_method("set_input_mode"):
		controls.call("set_input_mode", 2) # Tes ini secara eksplisit menguji mode HP.
		await process_frame
	var hud := root.find_child("MobileHUDScene", true, false)
	if player == null or controls == null or hud == null:
		_fail("Player/MobileControls/MobileHUDScene tidak terbentuk pada runtime")
		_finish()
		return
	var viewport_rect := root.get_visible_rect()
	print("VIEWPORT ", viewport_rect)
	print("HUD rect=", hud.get_global_rect(), " filter=", hud.mouse_filter, " visible=", hud.is_visible_in_tree())
	if hud.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("Root MobileHUD harus IGNORE agar latar layar penuh tidak menjadi target input")
	for key in ["JumpButton", "RunButton", "CrouchButton"]:
		var button := hud.get_node_or_null(key) as Button
		if button == null:
			_fail(key + " tidak ditemukan")
			continue
		var rect := button.get_global_rect()
		print("BUTTON ", key, " rect=", rect, " filter=", button.mouse_filter, " visible=", button.is_visible_in_tree(), " toggle=", button.toggle_mode)
		if button.mouse_filter != Control.MOUSE_FILTER_STOP:
			_fail(key + " tidak menggunakan MOUSE_FILTER_STOP")
		if not button.is_visible_in_tree():
			_fail(key + " tidak terlihat pada mode HP")
		if rect.size.x < 34.0 or rect.size.y < 34.0:
			_fail(key + " ukuran hitbox terlalu kecil: " + str(rect.size))
		if not viewport_rect.encloses(rect):
			_fail(key + " tidak seluruhnya berada dalam viewport: " + str(rect))
	var jump_button := hud.get_node("JumpButton") as Button
	hud.jump_requested.connect(_on_jump_requested)
	await _click(jump_button)
	if jump_signal_count < 1:
		_fail("klik GUI JumpButton tidak memicu signal jump_requested")
	var run_button := hud.get_node("RunButton") as Button
	await _click(run_button)
	if not bool(controls.get("run_enabled")) or not run_button.button_pressed:
		_fail("klik GUI RunButton tidak mengaktifkan toggle gameplay")
	var crouch_button := hud.get_node("CrouchButton") as Button
	await _click(crouch_button)
	if not bool(controls.get("crouch_enabled")) or not crouch_button.button_pressed:
		_fail("klik GUI CrouchButton tidak mengaktifkan toggle gameplay")
	_finish()

func _click(button: Button) -> void:
	var event_down := InputEventMouseButton.new()
	event_down.button_index = MOUSE_BUTTON_LEFT
	event_down.position = button.get_global_rect().get_center()
	event_down.pressed = true
	root.push_input(event_down, false)
	await process_frame
	var event_up := InputEventMouseButton.new()
	event_up.button_index = MOUSE_BUTTON_LEFT
	event_up.position = button.get_global_rect().get_center()
	event_up.pressed = false
	root.push_input(event_up, false)
	await process_frame

func _on_jump_requested() -> void:
	jump_signal_count += 1

func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: ", message)

func _finish() -> void:
	if failures.is_empty():
		print("PASS: integrated HUD geometry, filters, visibility, GUI click routing, and gameplay signals")
		quit(0)
	else:
		printerr("FAILURES: ", failures.size())
		quit(1)
