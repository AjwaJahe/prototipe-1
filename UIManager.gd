extends CanvasLayer

const MINIMAP_SCRIPT = preload("res://Minimap2D.gd")

## HUD dinamis Map58. Display-only: tidak mengubah aturan gameplay.

var _game: Node
var _player: Node
var _teacher: Node

var objective_label: Label
var phase_label: Label
var timer_label: Label
var score_label: Label
var stamina_bar: ProgressBar
var stamina_label: Label
var inventory_label: Label
var status_label: Label
var proximity_label: Label
var board_panel: PanelContainer
var board_question_label: Label
var board_answer_hint: Label
var results_panel: PanelContainer
var results_label: Label
var minimap_widget: Control
var fps_label: Label
var _pause_overlay: ColorRect
var _pause_panel: PanelContainer
var _settings_panel: PanelContainer
var _pause_menu_open := false
var _notification_serial := 0


func _ready() -> void:
	add_to_group("game_ui_manager")
	_game = get_node_or_null("../GameManager")
	_player = get_node_or_null("../Player/CharacterBody3D")
	if _player == null:
		_player = get_node_or_null("../Player")
	_teacher = get_node_or_null("../Teacher")
	_build_hud()
	_build_pause_menu()

	if _game != null:
		if _game.has_signal("phase_changed"):
			_game.phase_changed.connect(_on_phase_changed)
		if _game.has_signal("objective_changed"):
			_game.objective_changed.connect(_on_objective_changed)
		if _game.has_signal("game_finished"):
			_game.game_finished.connect(_on_game_finished)
		if _game.has_signal("board_answer_result"):
			_game.board_answer_result.connect(_on_board_answer_result)
		if _game.has_signal("teacher_mode_changed"):
			_game.teacher_mode_changed.connect(_on_teacher_mode_changed)

	if _player != null:
		if _player.has_signal("stamina_changed"):
			_player.stamina_changed.connect(_on_stamina_changed)
		var inventory := _player.get_node_or_null("ItemInventory")
		if inventory != null and inventory.has_signal("inventory_changed"):
			inventory.inventory_changed.connect(_on_inventory_changed)

	_refresh_all()


const REFRESH_INTERVAL := 0.1
var _refresh_remaining := 0.0


func _unhandled_key_input(event: InputEvent) -> void:
	# Shortcut keyboard hanya aktif pada mode komputer; mode HP memakai kontrol sentuh.
	if _is_mobile_input_mode():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle_pause_menu()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Windows dapat melepas mouse capture saat pointer keluar/fokus jendela berubah.
	# Kunci kembali hanya ketika gameplay aktif, bukan saat menu/settings terbuka.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Tunda satu frame agar Godot selesai memulihkan fokus jendela.
		call_deferred("_restore_mouse_capture_if_gameplay")


func _unhandled_input(event: InputEvent) -> void:
	# Tangkap ulang mouse hanya jika klik tidak dipakai tombol/control UI.
	# _unhandled_input berjalan setelah GUI mendapat kesempatan memproses klik.
	if _pause_menu_open or (is_instance_valid(_settings_panel) and _settings_panel.visible):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_restore_mouse_capture_if_gameplay()


func _restore_mouse_capture_if_gameplay() -> void:
	if _pause_menu_open or (is_instance_valid(_settings_panel) and _settings_panel.visible):
		return
	# Gunakan referensi GameManager yang sudah diverifikasi saat _ready, bukan path baru.
	if is_instance_valid(_game):
		for ui_property in ["_intro_paper_canvas", "_penalty_exam_canvas"]:
			var modal_ui = _game.get(ui_property)
			if is_instance_valid(modal_ui) and modal_ui is CanvasLayer and modal_ui.visible:
				return
	var focused_control := get_viewport().gui_get_focus_owner()
	if focused_control is LineEdit or focused_control is TextEdit:
		return
	var player_node := get_tree().get_first_node_in_group("players")
	# Whiteboard mode uses mouse/touch as a drawing pointer; never recapture it here.
	if player_node != null and bool(player_node.get_meta("whiteboard_mode", false)):
		return
	var mobile_controls := player_node.get_node_or_null("MobileControls") if player_node != null else null
	var touch_ui_enabled := OS.has_feature("web_android") or OS.has_feature("web_ios")
	if mobile_controls != null and mobile_controls.has_method("is_mobile"):
		# Jangan kunci mouse saat HUD sentuh desktop sedang dipreview/dipakai.
		touch_ui_enabled = bool(mobile_controls.call("is_mobile")) or bool(mobile_controls.get("show_touch_hud_on_desktop"))
	else:
		touch_ui_enabled = touch_ui_enabled or DisplayServer.is_touchscreen_available()
	if not touch_ui_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func show_notification(message: String, duration: float = 2.8) -> void:
	# Notifikasi khusus untuk aksi yang gagal/terkunci; tidak mengaktifkan kembali spam status lama.
	if not is_instance_valid(status_label):
		return
	_notification_serial += 1
	var serial := _notification_serial
	status_label.text = message
	status_label.modulate = Color(0.94, 0.96, 1.0, 1.0)
	status_label.visible = true
	var tween := create_tween()
	tween.tween_interval(maxf(0.5, duration))
	tween.tween_callback(func() -> void:
		if is_instance_valid(status_label) and serial == _notification_serial:
			status_label.visible = false
			status_label.text = ""
	)


func _build_pause_menu() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Menu jeda harus berada di atas MobileControlsLayer (layer 30),
	# supaya HUD sentuh tidak menutupi tombol menu/pengaturan saat jeda.
	var pause_canvas := CanvasLayer.new()
	pause_canvas.name = "PauseMenuCanvas"
	pause_canvas.layer = 40
	pause_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_canvas)
	var root := Control.new()
	root.name = "InGameMenuRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_canvas.add_child(root)
	var menu_button := Button.new()
	menu_button.name = "InGameMenuButton"
	menu_button.text = "☰"
	menu_button.custom_minimum_size = Vector2(84, 50)
	menu_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	menu_button.offset_left = -42
	menu_button.offset_top = 8
	menu_button.offset_right = 42
	menu_button.offset_bottom = 58
	menu_button.focus_mode = Control.FOCUS_ALL
	menu_button.add_theme_font_size_override("font_size", 17)
	_style_hud_button(menu_button)
	menu_button.pressed.connect(_toggle_pause_menu)
	root.add_child(menu_button)
	_pause_overlay = ColorRect.new()
	_pause_overlay.name = "PauseMenuOverlay"
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.color = Color(0.015, 0.02, 0.03, 0.82)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.visible = false
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_pause_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)
	_pause_panel = PanelContainer.new()
	_pause_panel.custom_minimum_size = Vector2(300, 0)
	center.add_child(_pause_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_pause_panel.add_child(box)
	var title := Label.new()
	title.text = "MENU PERMAINAN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	_add_menu_action(box, "SETTING", _open_settings, 56)
	_add_menu_action(box, "LANJUTKAN", _resume_game, 56)
	_add_menu_action(box, "KELUAR", _return_to_main_menu, 56)


func _add_menu_action(parent: VBoxContainer, caption: String, action: Callable, height: float) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(260, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 17)
	_style_hud_button(button)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _style_hud_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.13, 0.16, 0.96)
	normal.border_color = Color(0.42, 0.53, 0.60, 1.0)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.94, 0.96, 0.96, 1.0)
	hover.border_color = Color(1.0, 1.0, 1.0, 1.0)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(8)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.78, 0.84, 0.86, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.92, 0.95, 0.97, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.04, 0.06, 0.07, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.04, 0.06, 0.07, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.04, 0.06, 0.07, 1.0))


func _is_mobile_input_mode() -> bool:
	var player_node := get_tree().get_first_node_in_group("players")
	var controls := player_node.get_node_or_null("MobileControls") if player_node != null else null
	return controls != null and controls.has_method("is_mobile") and bool(controls.call("is_mobile"))


func _select_desktop_mode() -> void:
	_set_player_input_mode(1)


func _select_mobile_mode() -> void:
	_set_player_input_mode(2)


func _set_player_input_mode(mode: int) -> void:
	var player_node := get_tree().get_first_node_in_group("players")
	var controls := player_node.get_node_or_null("MobileControls") if player_node != null else null
	if controls != null and controls.has_method("set_input_mode"):
		controls.call("set_input_mode", mode)
	_resume_game()


func open_menu_from_mobile() -> void:
	_open_pause_menu()


func _toggle_pause_menu() -> void:
	if _pause_menu_open:
		_resume_game()
	else:
		_open_pause_menu()


func _open_pause_menu() -> void:
	if _game != null and String(_game.get("phase")) == "FINISHED":
		return
	_pause_menu_open = true
	_pause_overlay.visible = true
	_pause_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume_game() -> void:
	_pause_menu_open = false
	if is_instance_valid(_pause_overlay):
		_pause_overlay.visible = false
	if is_instance_valid(_settings_panel):
		_settings_panel.visible = false
	var player_node := get_tree().get_first_node_in_group("players")
	var mobile_controls := player_node.get_node_or_null("MobileControls") if player_node != null else null
	var touch_ui_enabled := OS.has_feature("web_android") or OS.has_feature("web_ios")
	if mobile_controls != null and mobile_controls.has_method("is_mobile"):
		# Mode router adalah sumber kebenaran; layar sentuh laptop tidak boleh
		# memaksa cursor terlihat setelah pengguna memilih mode Komputer.
		touch_ui_enabled = bool(mobile_controls.call("is_mobile")) or bool(mobile_controls.get("show_touch_hud_on_desktop"))
	else:
		touch_ui_enabled = touch_ui_enabled or DisplayServer.is_touchscreen_available()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if touch_ui_enabled else Input.MOUSE_MODE_CAPTURED


func _open_settings() -> void:
	if not is_instance_valid(_pause_overlay):
		return
	_pause_panel.visible = false
	if not is_instance_valid(_settings_panel):
		_build_settings_panel()
	_settings_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_settings_panel() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.name = "InGameSettingsPanel"
	_settings_panel.custom_minimum_size = Vector2(340, 0)
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.position = Vector2(-170, -120)
	_pause_overlay.add_child(_settings_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_settings_panel.add_child(box)
	var title := Label.new()
	title.text = "SETTING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	var volume_label := Label.new()
	volume_label.text = "Volume"
	box.add_child(volume_label)
	var volume_slider := HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	volume_slider.value_changed.connect(_set_master_volume)
	box.add_child(volume_slider)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Layar penuh"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	fullscreen.toggled.connect(_set_fullscreen)
	box.add_child(fullscreen)
	_add_menu_action(box, "ATUR TOMBOL HUD SENTUH", _open_hud_layout_editor, 48)
	_add_menu_action(box, "KEMBALI", _close_settings, 52)


func _open_hud_layout_editor() -> void:
	var mobile_controls := _player.get_node_or_null("MobileControls") if _player != null else null
	if mobile_controls != null and mobile_controls.has_method("open_hud_layout_editor"):
		mobile_controls.call("open_hud_layout_editor")
	else:
		push_warning("MobileControls tidak ditemukan; editor tata letak HUD tidak dapat dibuka.")


func _set_master_volume(value: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(value, 0.001)))
		AudioServer.set_bus_mute(bus, value <= 0.001)


func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)


func _close_settings() -> void:
	if is_instance_valid(_settings_panel):
		_settings_panel.visible = false
	_pause_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _restart_game() -> void:
	if bool(get_tree().get_meta("kelas_malam_multiplayer_active", false)):
		var session := get_node_or_null("/root/MultiplayerSession")
		if session != null and session.has_method("request_restart_game"):
			session.request_restart_game()
			return
	get_tree().reload_current_scene()


func _return_to_main_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if bool(get_tree().get_meta("kelas_malam_multiplayer_active", false)):
		var session := get_node_or_null("/root/MultiplayerSession")
		if session != null and session.has_method("request_return_to_menu"):
			session.request_return_to_menu()
			return
	get_tree().set_meta("kelas_malam_multiplayer_active", false)
	get_tree().change_scene_to_file("res://MainMenu.tscn")


func _process(delta: float) -> void:
	if is_instance_valid(fps_label):
		fps_label.text = "FPS %d" % Engine.get_frames_per_second()
	_refresh_remaining -= delta
	if _refresh_remaining > 0.0:
		return
	_refresh_remaining = REFRESH_INTERVAL
	_refresh_all()


func _build_hud() -> void:
	# Bangun ulang HUD dari satu root dengan zona yang tidak saling menimpa.
	var root := Control.new()
	root.name = "GameplayHUD"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Kiri atas: peta saja.
	var map_panel := PanelContainer.new()
	map_panel.name = "MinimapPanel"
	map_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	map_panel.offset_left = 18
	map_panel.offset_top = 18
	map_panel.offset_right = 223
	map_panel.offset_bottom = 218
	root.add_child(map_panel)
	var map_box := VBoxContainer.new()
	map_box.add_theme_constant_override("separation", 3)
	map_panel.add_child(map_box)
	var map_title := _make_label(map_box, Vector2.ZERO, 13)
	map_title.text = "Mini Map"
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimap_widget = Control.new()
	minimap_widget.name = "Minimap"
	minimap_widget.set_script(MINIMAP_SCRIPT)
	minimap_widget.custom_minimum_size = Vector2(195, 170)
	minimap_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_box.add_child(minimap_widget)
	minimap_widget.set("player_node", _player)
	minimap_widget.set("teacher_node", _teacher)
	minimap_widget.set("navigation_region", get_node_or_null("../Map58/NavigationRegion3D"))

	# Tengah atas: tujuan dan waktu, terpisah dari peta dan statistik.
	var mission_panel := PanelContainer.new()
	mission_panel.name = "MissionStatusPanel"
	mission_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	mission_panel.anchor_left = 0.5
	mission_panel.anchor_right = 0.5
	mission_panel.offset_left = -205
	mission_panel.offset_top = 18
	mission_panel.offset_right = 205
	mission_panel.offset_bottom = 108
	mission_panel.visible = false # Informasi fase/waktu tidak diminta sebagai HUD permanen.
	root.add_child(mission_panel)
	var mission_box := VBoxContainer.new()
	mission_box.add_theme_constant_override("separation", 2)
	mission_panel.add_child(mission_box)
	objective_label = _make_label(mission_box, Vector2.ZERO, 18)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label = _make_label(mission_box, Vector2.ZERO, 13)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label = _make_label(mission_box, Vector2.ZERO, 20)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Kanan atas: FPS, skor, dan stamina dalam satu kolom.
	var stats_panel := PanelContainer.new()
	stats_panel.name = "PlayerStatsPanel"
	stats_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stats_panel.offset_left = -205
	stats_panel.offset_top = 18
	stats_panel.offset_right = -20
	stats_panel.offset_bottom = 132
	# Statistik lokal ditampilkan pada sesi offline. Saat multiplayer aktif, panel jaringan
	# milik MultiplayerGame menampilkan FPS dan ping agar tidak ada HUD yang bertumpuk.
	stats_panel.visible = not bool(get_tree().get_meta("kelas_malam_multiplayer_active", false))
	root.add_child(stats_panel)
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 4)
	stats_panel.add_child(stats_box)
	fps_label = _make_label(stats_box, Vector2.ZERO, 13)
	fps_label.name = "FPSLabel"
	fps_label.text = "FPS --"
	var ping_label := _make_label(stats_box, Vector2.ZERO, 13)
	ping_label.name = "PingLabel"
	ping_label.text = "PING: OFFLINE"
	score_label = _make_label(stats_box, Vector2.ZERO, 16)
	stamina_label = _make_label(stats_box, Vector2.ZERO, 13)
	stamina_bar = ProgressBar.new()
	stamina_bar.name = "StaminaBar"
	stamina_bar.custom_minimum_size = Vector2(150, 14)
	stamina_bar.show_percentage = false
	stats_box.add_child(stamina_bar)
	stamina_label.visible = false
	stamina_bar.visible = false

	# Tombol menu di bawah statistik agar tidak bertumpuk dengan FPS.
	var menu_button := get_node_or_null("PauseMenuCanvas/InGameMenuRoot/InGameMenuButton") as Button
	if menu_button != null:
		menu_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
		menu_button.offset_left = -42
		menu_button.offset_top = 8
		menu_button.offset_right = 42
		menu_button.offset_bottom = 58

	# Bawah kiri: inventori; tengah bawah: pesan interaksi/peringatan.
	inventory_label = _make_label(root, Vector2.ZERO, 15)
	inventory_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	inventory_label.offset_left = 20
	inventory_label.offset_top = -278
	inventory_label.offset_right = 320
	inventory_label.offset_bottom = -208
	inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	proximity_label = _make_label(root, Vector2.ZERO, 15)
	proximity_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	proximity_label.offset_left = -220
	proximity_label.offset_top = -92
	proximity_label.offset_right = 220
	proximity_label.offset_bottom = -58
	proximity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	proximity_label.visible = false # Tidak ada peringatan jarak guru.

	status_label = _make_label(root, Vector2.ZERO, 22)
	status_label.set_anchors_preset(Control.PRESET_CENTER)
	status_label.offset_left = -360
	status_label.offset_top = 70
	status_label.offset_right = 360
	status_label.offset_bottom = 126
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Panel soal tetap nonaktif agar tidak menutupi pandangan ke papan 3D.
	board_panel = PanelContainer.new()
	board_panel.name = "BoardQuestionOverlay"
	board_panel.set_anchors_preset(Control.PRESET_CENTER)
	board_panel.offset_left = -360
	board_panel.offset_top = -230
	board_panel.offset_right = 360
	board_panel.offset_bottom = 130
	board_panel.visible = false
	add_child(board_panel)
	var board_box := VBoxContainer.new()
	board_panel.add_child(board_box)
	board_question_label = _make_label(board_box, Vector2.ZERO, 22)
	board_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board_question_label.custom_minimum_size = Vector2(680, 190)
	board_question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board_answer_hint = _make_label(board_box, Vector2.ZERO, 15)
	board_answer_hint.text = "Masukkan jawaban melalui kontrol papan."

	results_panel = PanelContainer.new()
	results_panel.name = "ResultsPanel"
	results_panel.set_anchors_preset(Control.PRESET_CENTER)
	results_panel.offset_left = -320
	results_panel.offset_top = -220
	results_panel.offset_right = 320
	results_panel.offset_bottom = 220
	results_panel.visible = false
	add_child(results_panel)
	var results_box := VBoxContainer.new()
	results_box.add_theme_constant_override("separation", 10)
	results_panel.add_child(results_box)
	results_label = _make_label(results_box, Vector2.ZERO, 24)
	results_label.custom_minimum_size = Vector2(520, 245)
	results_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var play_again_button := Button.new()
	play_again_button.name = "PlayAgainButton"
	play_again_button.text = "MAIN LAGI"
	play_again_button.custom_minimum_size.y = 48
	play_again_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_again_button.pressed.connect(_restart_game)
	results_box.add_child(play_again_button)
	var results_menu_button := Button.new()
	results_menu_button.name = "ResultsMainMenuButton"
	results_menu_button.text = "KEMBALI KE MENU UTAMA"
	results_menu_button.custom_minimum_size.y = 48
	results_menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_menu_button.pressed.connect(_return_to_main_menu)
	results_box.add_child(results_menu_button)
func _make_label(parent: Node, position: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _refresh_all() -> void:
	if _game == null:
		return

	var phase := String(_game.get("phase"))
	phase_label.visible = false
	score_label.visible = false

	var solved := int(_game.get("solved_papers"))
	objective_label.visible = false

	var timer := 0.0
	if phase == "INTRO_EXAM":
		timer = _as_float(_game.get("intro_remaining"))
	elif phase == "TRANSITION":
		timer = _as_float(_game.get("transition_remaining"))
	elif phase == "HUNT":
		timer = maxf(
			_as_float(_game.get("hunt_remaining")),
			maxf(_as_float(_game.get("calm_remaining")), _as_float(_game.get("berserk_remaining")))
		)
	elif phase == "BOARD_SOLVING":
		timer = _as_float(_game.get("board_remaining"))
	timer_label.visible = false

	if _player != null:
		var stamina := _as_float(_player.get("run_stamina"))
		var max_stamina := maxf(_as_float(_player.get("max_run_stamina")), 0.001)
		stamina_bar.visible = false
		stamina_bar.max_value = max_stamina
		stamina_label.visible = false

		var inventory := _player.get_node_or_null("ItemInventory")
		if inventory != null:
			var items: Array = inventory.get_inventory() if inventory.has_method("get_inventory") else []
			inventory_label.text = "INVENTORI [%d/2]:
%s" % [
				items.size(),
				", ".join(items)
			]

	if _teacher != null and _player is Node3D and _teacher is Node3D:
		var distance := (_player as Node3D).global_position.distance_to(
			(_teacher as Node3D).global_position
		)
		if distance < 10.0:
			proximity_label.text = "âš  GURU DEKAT â€” %0.1f m" % distance
		elif distance < 15.0:
			proximity_label.text = "GURU TERDETEKSI â€” %0.1f m" % distance
		else:
			proximity_label.visible = false



	# Soal ditampilkan langsung pada papan 3D, bukan panel layar.
	# Panel layar lama menutupi POV dan menghalangi kontrol kamera.
	board_panel.visible = false
	board_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if board_panel.visible:
		var question: Dictionary = _game.get("current_question")
		board_question_label.text = "SOAL KE %d/10
%s

WAKTU: %s" % [
			solved + 1,
			String(question.get("question", "")),
			_format_time(timer)
		]

	if phase == "FINISHED":
		results_panel.visible = true


func _on_board_answer_result(correct: bool, message: String) -> void:
	status_label.text = message
	status_label.modulate = Color(0.4, 1.0, 0.4) if correct else Color(1.0, 0.35, 0.35)
	status_label.visible = true
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func(): status_label.text = "")


func _on_teacher_mode_changed(mode: String, _target: Node) -> void:
	var mode_names := {
		"teacher": "GURU BERPATROLI",
		"ghost": "GURU MENJADI HANTU",
		"berserk": "GURU MASUK MODE BERSEK",
		"responding": "GURU SEDANG MERESPONS",
	}
	status_label.text = String(mode_names.get(mode, "MODE GURU: " + mode.to_upper()))
	status_label.modulate = Color(1.0, 0.72, 0.32) if mode == "berserk" else Color(0.94, 0.96, 1.0)
	status_label.visible = true
	var tween := create_tween()
	tween.tween_interval(3.5)
	tween.tween_callback(func():
		if is_instance_valid(status_label):
			status_label.visible = false
	)


func _on_phase_changed(_phase: String) -> void:
	_refresh_all()


func _on_objective_changed(_solved: int, _target: int) -> void:
	_refresh_all()


func _on_stamina_changed(_current: float, _maximum: float) -> void:
	_refresh_all()


func _on_inventory_changed(_items: Array) -> void:
	_refresh_all()


func _on_game_finished() -> void:
	if _game == null:
		return
	var result := String(_game.get("game_result"))
	var title := "KALAH!" if result == "LOSE" else "SELESAI!"
	results_label.text = "%s

NILAI AKHIR: %s
SKOR TOTAL: %d
SOAL TERJAWAB: %d/10" % [
		title,
		String(_game.get_final_grade()),
		int(_game.get("score")),
		int(_game.get("solved_papers"))
	]
	results_panel.visible = true


func _as_float(value: Variant, fallback: float = 0.0) -> float:
	if value == null:
		return fallback
	if value is float:
		return value
	if value is int:
		return value * 1.0
	if value is String:
		return value.to_float()
	return fallback


func _format_time(seconds_value: float) -> String:
	var total := maxi(0, int(ceil(seconds_value)))
	return "%02d:%02d" % [total / 60, total % 60]


func _pretty_phase(value: String) -> String:
	return value.replace("_", " ").capitalize()
