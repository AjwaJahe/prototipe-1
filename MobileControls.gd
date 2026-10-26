extends Node
## Kontrol sentuh untuk Android. Kontrol desktop tetap menggunakan keyboard/mouse.

const JOYSTICK_SIZE := 164.0
const KNOB_SIZE := 66.0
const JOYSTICK_RADIUS := 58.0
const HUD_LAYOUT_MANAGER_SCRIPT = preload("res://HUDLayoutManager.gd")

# Tombol ikon buang dengan siluet tempat sampah bergaris tangan.
class TrashIconButton extends Button:
	func _draw() -> void:
		var ink := Color(0.06, 0.07, 0.07, 1.0)
		var fill := Color(0.72, 0.74, 0.72, 0.96)
		var body := PackedVector2Array([Vector2(10, 13), Vector2(32, 12), Vector2(29, 37), Vector2(14, 36), Vector2(10, 13)])
		draw_colored_polygon(body, fill)
		for i in range(body.size() - 1):
			draw_line(body[i], body[i + 1], ink, 3.0, true)
		draw_line(Vector2(7, 11), Vector2(35, 10), ink, 3.0, true)
		draw_line(Vector2(15, 7), Vector2(27, 7), ink, 3.0, true)
		draw_line(Vector2(18, 5), Vector2(25, 5), ink, 2.5, true)
		draw_line(Vector2(17, 17), Vector2(18, 31), ink, 2.0, true)
		draw_line(Vector2(24, 17), Vector2(23, 31), ink, 2.0, true)

class SketchActionButton extends Button:
	var sketch_kind := "rough"
	var feedback_down := false
	var hovered := false

	func _ready() -> void:
		mouse_entered.connect(func(): hovered = true; queue_redraw())
		mouse_exited.connect(func(): hovered = false; queue_redraw())
		button_down.connect(func():
			feedback_down = true
			queue_redraw()
		)
		button_up.connect(func():
			feedback_down = false
			queue_redraw()
		)
		toggled.connect(func(_active: bool): queue_redraw())

	func _draw() -> void:
		var ink := Color(0.055, 0.06, 0.055, 1.0)
		var fill := Color(0.96, 0.97, 0.96, 1.0) if (feedback_down or button_pressed or hovered) else Color(0.68, 0.70, 0.68, 0.96)
		var w := size.x
		var h := size.y
		var points := PackedVector2Array()
		if sketch_kind == "circle":
			var center := size * 0.5
			var radius := minf(w, h) * 0.43
			for i in range(25):
				var angle := TAU * float(i) / 24.0
				var wobble := 1.0 + 0.025 * sin(float(i) * 2.7)
				points.append(center + Vector2(cos(angle), sin(angle)) * radius * wobble)
		elif sketch_kind == "box":
			points = PackedVector2Array([Vector2(3, 4), Vector2(w - 4, 2), Vector2(w - 2, h - 5), Vector2(5, h - 3), Vector2(3, 4)])
		else:
			points = PackedVector2Array([Vector2(5, 7), Vector2(w * 0.43, 3), Vector2(w - 5, 8), Vector2(w - 2, h * 0.42), Vector2(w - 7, h - 5), Vector2(w * 0.55, h - 2), Vector2(4, h - 7), Vector2(2, h * 0.48), Vector2(5, 7)])
		draw_colored_polygon(points, fill)
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], ink, 3.0, true)
		# Garis kedua yang sedikit bergeser memberi kesan sketsa tangan.
		if sketch_kind != "circle":
			draw_line(points[0] + Vector2(2, 2), points[1] + Vector2(1, 2), ink, 1.4, true)
		# Ikon aksi digambar manual agar tetap satu gaya dengan garis sketsa tombol.
		var c := Color(0.04, 0.045, 0.04, 1.0)
		var center_x := w * 0.5
		var cy := h * (0.34 if sketch_kind == "circle" else 0.30)
		var p := Vector2(center_x, cy)
		if sketch_kind == "circle" and text.to_upper() in ["SPK", "SPK ON", "SPK OFF", "MIC", "MIC ON", "MIC OFF", "CHAT"]:
			# Tombol komunikasi hanya menampilkan logo, tanpa tulisan.
			var label := "SPK" if text.to_upper().begins_with("SPK") else ("MIC" if text.to_upper().begins_with("MIC") else "CHAT")
			match label:
				"SPK":
					draw_rect(Rect2(p + Vector2(-9, -3), Vector2(3, 6)), c, true)
					draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -6), p + Vector2(0, -9), p + Vector2(0, 9), p + Vector2(-6, 6)]), c)
					draw_arc(p, 5.0, -PI * 0.35, PI * 0.35, 12, c, 1.8, true)
					draw_arc(p, 8.0, -PI * 0.30, PI * 0.30, 12, c, 1.8, true)
				"MIC":
					draw_rect(Rect2(p + Vector2(-2.5, -8), Vector2(5, 10)), c, true)
					draw_arc(p + Vector2(0, -1), 5.0, 0.0, PI, 12, c, 1.8, true)
					draw_line(p + Vector2(0, 4), p + Vector2(0, 7), c, 1.8, true)
					draw_line(p + Vector2(-3, 7), p + Vector2(3, 7), c, 1.8, true)
				"CHAT":
					draw_rect(Rect2(p + Vector2(-8, -6), Vector2(16, 11)), c, false, 1.8, true)
					draw_line(p + Vector2(-4, 5), p + Vector2(-7, 8), c, 1.8, true)
			return
		match text.to_upper():
			"LOMPAT":
				draw_line(p + Vector2(0, 13), p + Vector2(0, -13), c, 3.2, true)
				draw_line(p + Vector2(0, -13), p + Vector2(-8, -5), c, 3.2, true)
				draw_line(p + Vector2(0, -13), p + Vector2(8, -5), c, 3.2, true)
			"JONGKOK", "JONGKOK: ON":
				draw_circle(p + Vector2(-2, -9), 4.0, c)
				draw_line(p + Vector2(-2, -4), p + Vector2(7, 2), c, 3.0, true)
				draw_line(p + Vector2(2, 0), p + Vector2(-6, 8), c, 3.0, true)
				draw_line(p + Vector2(5, 2), p + Vector2(10, 9), c, 3.0, true)
			"LARI", "LARI: ON", "LARI: OFF":
				draw_line(p + Vector2(-8, 5), p + Vector2(8, -5), c, 3.0, true)
				draw_line(p + Vector2(2, -6), p + Vector2(8, -5), c, 3.0, true)
				draw_line(p + Vector2(8, -5), p + Vector2(7, 1), c, 3.0, true)
			"SEMBUNYI", "KELUAR":
				draw_arc(p, 10.0, PI, TAU, 20, c, 2.8, true)
				draw_circle(p, 3.5, c)
				draw_line(p + Vector2(-12, -11), p + Vector2(12, 11), c, 3.0, true)
			"SEMBUHKAN":
				draw_line(p + Vector2(0, -11), p + Vector2(0, 11), c, 3.5, true)
				draw_line(p + Vector2(-11, 0), p + Vector2(11, 0), c, 3.5, true)
			"SPK", "SPK ON", "SPK OFF":
				draw_arc(p + Vector2(-2, 0), 7.0, -PI * 0.35, PI * 0.35, 12, c, 2.2, true)
				draw_arc(p + Vector2(-2, 0), 12.0, -PI * 0.3, PI * 0.3, 12, c, 2.2, true)
				draw_rect(Rect2(p + Vector2(-13, -4), Vector2(5, 8)), c, true)
			"MIC", "MIC ON", "MIC OFF":
				draw_arc(p + Vector2(-1, -2), 5.0, 0.0, PI, 12, c, 2.5, true)
				draw_line(p + Vector2(-6, -2), p + Vector2(-6, 3), c, 2.5, true)
				draw_line(p + Vector2(4, -2), p + Vector2(4, 3), c, 2.5, true)
				draw_line(p + Vector2(-6, 3), p + Vector2(4, 3), c, 2.5, true)
				draw_line(p + Vector2(-1, 3), p + Vector2(-1, 8), c, 2.5, true)
				draw_line(p + Vector2(-5, 8), p + Vector2(3, 8), c, 2.5, true)
			"CHAT":
				draw_rect(Rect2(p + Vector2(-10, -7), Vector2(20, 14)), c, false, 2.5, true)
				draw_line(p + Vector2(-5, 7), p + Vector2(-8, 11), c, 2.5, true)
			"INTERAKSI":
				draw_circle(p, 7.0, c, false, 2.8, true)
				draw_line(p + Vector2(0, -13), p + Vector2(0, -8), c, 2.8, true)
				draw_line(p + Vector2(0, 8), p + Vector2(0, 13), c, 2.8, true)
				draw_line(p + Vector2(-13, 0), p + Vector2(-8, 0), c, 2.8, true)
				draw_line(p + Vector2(8, 0), p + Vector2(13, 0), c, 2.8, true)
			"1", "2":
				draw_rect(Rect2(p + Vector2(-7, -8), Vector2(14, 16)), c, false, 2.4, true)
				if text == "1":
					draw_line(p + Vector2(-3, -3), p + Vector2(0, -6), c, 2.0, true)
					draw_line(p + Vector2(0, -6), p + Vector2(0, 6), c, 2.0, true)
				else:
					draw_arc(p, 4.0, -PI * 0.8, PI * 0.1, 12, c, 2.0, true)
					draw_line(p + Vector2(3, 2), p + Vector2(-3, 6), c, 2.0, true)

## Pilih mode uji di Inspector sebelum menjalankan game.
@export_enum("Otomatis", "Komputer", "HP") var test_mode: int = 0
## Tampilkan tombol komunikasi (speaker, mikrofon, chat) di desktop juga.
@export var show_communication_hud_on_desktop: bool = true
## Opsi kompatibilitas lama untuk preview HUD.
@export var preview_mobile_hud: bool = false
@export var show_touch_hud_on_desktop: bool = false

var player: CharacterBody3D
var camera: Camera3D
var movement_vector := Vector2.ZERO
var run_enabled := false
var crouch_enabled := false
var interact_pressed := false
var heal_pressed := false
var hide_requested := false
var _jump_requested := false
var _joystick_base: Panel
var _joystick_knob: Panel
var _jump_button: Button
var _run_button: Button
var _crouch_button: Button
var _trash_button: TrashIconButton
var _speaker_button: Button
var _mic_button: Button
var _chat_button: Button
var _interact_button: Button
var _hide_button: Button
var _heal_button: Button
var _slot_one: Button
var _slot_two: Button
var _context_refresh := 0.0
var _notice_remaining := 0.0
var _notice_panel: PanelContainer
var _notice_label: Label
var _audio_muted := false
var _mic_enabled := false
var _controls_root: Control
var _communication_root: Control
var _look_area: Control
var _gameplay_group: Control
var _communication_group: Control
var _inventory_group: Control
var _context_group: Control
var _notice_group: Control
var _look_touch_id := -1
# Beberapa driver Windows melaporkan touchscreen_available=false walau layar sentuh aktif.
# Sentuhan nyata menjadi bukti runtime agar HUD tidak tetap tersembunyi.
var _touch_input_detected := false
var _desktop_mobile_preview_active := false
var _hud_layout_manager: Node
var _input_router: Node


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if player == null:
		push_error("MobileControls harus menjadi child CharacterBody3D.")
		set_process_unhandled_input(false)
		return
	camera = player.get_node_or_null("Camera3D") as Camera3D
	_input_router = player.get_node_or_null("InputRouter")
	if _input_router != null and _input_router.has_method("configure"):
		_input_router.call("configure", test_mode, _desktop_mobile_preview_active)
	# HUD komunikasi dibangun di desktop dan HP; kontrol sentuh saja yang disembunyikan di desktop.
	_build_controls()
	var mobile_hud := get_tree().root.find_child("MobileHUDScene", true, false)
	if mobile_hud != null and mobile_hud.has_method("set_preview_mode"):
		mobile_hud.call("set_preview_mode", is_mobile())
	_set_touch_controls_visible(is_mobile())
	if (preview_mobile_hud or show_touch_hud_on_desktop or is_mobile()) and not DisplayServer.is_touchscreen_available():
		# Cursor tetap terlihat agar tombol HUD bisa diklik dengan mouse saat preview.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not is_mobile():
		# Desktop tetap memakai keyboard/mouse; grup kontrol sentuh disembunyikan.
		set_process_unhandled_input(false)
		_set_touch_controls_visible(false)


func is_mobile() -> bool:
	if _input_router != null and _input_router.has_method("is_mobile_mode"):
		return bool(_input_router.call("is_mobile_mode"))
	if test_mode == 1:
		return false
	if test_mode == 2:
		return true
	var platform := OS.get_name()
	var running_on_mobile := platform == "Android" or platform == "iOS"
	var preview_enabled := (preview_mobile_hud or show_touch_hud_on_desktop) and not Engine.is_editor_hint()
	# Laptop/PC tetap Desktop meskipun memiliki layar sentuh; mode HP hanya otomatis pada OS mobile.
	return running_on_mobile or preview_enabled

func set_input_mode(selected_mode: int) -> void:
	# Mode runtime diputuskan sekali di InputRouter; semua input lama direset.
	test_mode = clampi(selected_mode, 0, 2)
	_desktop_mobile_preview_active = false
	show_touch_hud_on_desktop = false
	_touch_input_detected = false
	movement_vector = Vector2.ZERO
	run_enabled = false
	crouch_enabled = false
	_jump_requested = false
	if _run_button != null:
		_run_button.button_pressed = false
	if _crouch_button != null:
		_crouch_button.button_pressed = false
	if _input_router != null and _input_router.has_method("configure"):
		_input_router.call("configure", test_mode, false)
	var mobile_active := is_mobile()
	_set_touch_controls_visible(mobile_active)
	set_process_unhandled_input(mobile_active)
	var mobile_hud := get_tree().root.find_child("MobileHUDScene", true, false)
	if mobile_hud != null and mobile_hud.has_method("set_preview_mode"):
		mobile_hud.call("set_preview_mode", mobile_active)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mobile_active else Input.MOUSE_MODE_CAPTURED
	print("[Input Mode] ", "HP" if mobile_active else "Komputer")


func _toggle_desktop_mobile_preview() -> void:
	_desktop_mobile_preview_active = not _desktop_mobile_preview_active
	if _input_router != null and _input_router.has_method("configure"):
		_input_router.call("configure", test_mode, _desktop_mobile_preview_active)
	show_touch_hud_on_desktop = _desktop_mobile_preview_active
	_touch_input_detected = _desktop_mobile_preview_active
	var mobile_hud := get_tree().root.find_child("MobileHUDScene", true, false)
	var mobile_active := is_mobile()
	if mobile_hud != null and mobile_hud.has_method("set_preview_mode"):
		mobile_hud.call("set_preview_mode", mobile_active)
	_set_touch_controls_visible(mobile_active)
	# Cursor terlihat hanya saat jalur mobile/preview aktif; desktop normal kembali terkunci.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mobile_active else Input.MOUSE_MODE_CAPTURED
	print("[Mobile HUD Preview] ", "ON - klik tombol dengan mouse" if _desktop_mobile_preview_active else "OFF - kontrol desktop normal")


func _set_touch_controls_visible(enabled: bool) -> void:
	if _controls_root == null:
		return
	_controls_root.visible = true
	if _gameplay_group != null:
		_gameplay_group.visible = enabled
	if _inventory_group != null:
		_inventory_group.visible = enabled
	if _context_group != null:
		_context_group.visible = enabled
	if _communication_group != null:
		_communication_group.visible = enabled or show_communication_hud_on_desktop
	if _notice_group != null:
		_notice_group.visible = enabled
	if not enabled and _notice_panel != null:
		_notice_panel.visible = false


func set_whiteboard_mode(active: bool) -> void:
	# Jangan sembunyikan root HUD global saat papan tulis aktif: tindakan itu juga
	# menghilangkan Speaker/Mic/Chat dan mematikan akses kontrol sentuh lain.
	# HUD tetap terlihat; mode papan tulis dikelola terpisah oleh controller papan.
	if _controls_root != null:
		_controls_root.visible = true


func consume_jump_request() -> bool:
	var requested := _jump_requested
	_jump_requested = false
	return requested


func _unhandled_input(_event: InputEvent) -> void:
	# POV ditangani pada _input setelah mengecek apakah sentuhan dimulai di kontrol UI.
	pass


func _input(event: InputEvent) -> void:
	if player == null or camera == null:
		return
	# F5 di jendela game menyalakan/mematikan preview HUD HP di komputer.
	# F5 pada Godot Editor tetap berfungsi normal untuk menjalankan proyek.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5 and test_mode == 0 and (not is_mobile() or _desktop_mobile_preview_active):
		_toggle_desktop_mobile_preview()
		get_viewport().set_input_as_handled()
		return
	# Shortcut keyboard memanggil handler tombol HUD yang sama agar status visual
	# dan aksi speaker/mikrofon/chat tidak memiliki implementasi kedua.
	if event is InputEventKey and event.pressed and not event.echo and not is_mobile():
		var focused := get_viewport().gui_get_focus_owner()
		if focused is LineEdit or focused is TextEdit:
			return
		match event.keycode:
			KEY_L:
				_toggle_chat()
				get_viewport().set_input_as_handled()
				return
			KEY_M:
				_toggle_mic()
				get_viewport().set_input_as_handled()
				return
			KEY_N:
				_toggle_speaker()
				get_viewport().set_input_as_handled()
				return
	# Deteksi sentuhan sebelum memeriksa platform: sebagian driver Windows tidak
	# mengiklankan touchscreen, sehingga HUD sebelumnya bisa tersembunyi selamanya.
	if event is InputEventScreenTouch and event.pressed and not _touch_input_detected and test_mode != 1:
		_touch_input_detected = true
		if _input_router != null and _input_router.has_method("register_touch"):
			_input_router.call("register_touch")
		_set_touch_controls_visible(true)
		var mobile_hud := get_tree().root.find_child("MobileHUDScene", true, false)
		if mobile_hud != null and mobile_hud.has_method("register_touch_input"):
			mobile_hud.call("register_touch_input")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not is_mobile() or player == null or camera == null:
		return
	if bool(player.get_meta("is_hidden", false)) or bool(player.get_meta("capture_animation", false)) or bool(player.get_meta("whiteboard_mode", false)) or bool(player.get_meta("communication_ui_open", false)):
		_look_touch_id = -1
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			# POV hanya boleh dimulai di area kanan yang kosong, bukan di atas tombol/joystick.
			if event.position.x >= get_viewport().get_visible_rect().size.x * 0.5 and not _is_touch_over_hud_control(event.position):
				_look_touch_id = event.index
		else:
			if event.index == _look_touch_id:
				_look_touch_id = -1
	elif event is InputEventScreenDrag and event.index == _look_touch_id:
		var sensitivity := float(player.get("mouse_sensitivity"))
		player.rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -1.4, 1.4)
		get_viewport().set_input_as_handled()


func _is_touch_over_hud_control(screen_position: Vector2) -> bool:
	if _controls_root == null or not _controls_root.visible:
		return false
	var pending: Array[Node] = [_controls_root]
	if _communication_root != null:
		pending.append(_communication_root)
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
		if not node is Control or node == _controls_root or node == _communication_root or node == _look_area:
			continue
		var control := node as Control
		if not control.is_visible_in_tree() or control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		# Kontainer layar penuh seperti MobileHUDScene memakai PASS, tetapi bukan tombol.
		# Jangan biarkan kontainer itu memblokir POV di seluruh sisi kanan layar.
		if control.mouse_filter == Control.MOUSE_FILTER_PASS and control.get_signal_connection_list("gui_input").is_empty():
			continue
		if control.get_global_rect().has_point(screen_position):
			return true
	var menu_button := get_tree().root.find_child("InGameMenuButton", true, false) as Control
	if menu_button != null and menu_button.is_visible_in_tree() and menu_button.get_global_rect().has_point(screen_position):
		return true
	var pause_overlay := get_tree().root.find_child("PauseMenuOverlay", true, false) as Control
	if pause_overlay != null and pause_overlay.visible:
		return true
	return false


func _build_controls() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "MobileControlsLayer"
	canvas.layer = 30
	add_child(canvas)
	var root := Control.new()
	root.name = "ControlsRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls_root = root
	canvas.add_child(root)

	# HUD HP: kontrol gerak/aksi, inventori, konteks interaksi, dan notifikasi.
	# Elemen komunikasi dipisah ke layer global agar desktop dan HP memakai satu HUD bersama.
	_look_area = _make_control_group(root, "POVLookArea", -100, Control.MOUSE_FILTER_IGNORE)
	_gameplay_group = _make_control_group(root, "GameplayControls", 0, Control.MOUSE_FILTER_IGNORE)
	_inventory_group = _make_control_group(root, "InventoryControls", 3, Control.MOUSE_FILTER_IGNORE)
	_context_group = _make_control_group(root, "ContextControls", 4, Control.MOUSE_FILTER_IGNORE)
	_notice_group = _make_control_group(root, "NoticeControls", 8, Control.MOUSE_FILTER_IGNORE)

	# HUD global komunikasi berdiri pada CanvasLayer sendiri, di bawah kontrol HP
	# agar root layar penuh tidak menutupi hit-test tombol sentuh; pause/settings tetap di atas.
	var communication_canvas := CanvasLayer.new()
	communication_canvas.name = "GlobalCommunicationHUDLayer"
	communication_canvas.layer = 29
	add_child(communication_canvas)
	var communication_root := Control.new()
	communication_root.name = "GlobalCommunicationHUDRoot"
	communication_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	communication_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_communication_root = communication_root
	communication_canvas.add_child(communication_root)
	_communication_group = _make_control_group(communication_root, "CommunicationControls", 0, Control.MOUSE_FILTER_IGNORE)

	# Kontrol gerak/aksi berasal dari scene .tscn; jangan dibuat dua kali.
	var mobile_hud_scene: PackedScene = load("res://MobileHUD.tscn")
	if mobile_hud_scene == null:
		push_error("MobileHUD.tscn gagal dimuat; kontrol sentuh tidak dibuat.")
		return
	var mobile_hud := mobile_hud_scene.instantiate()
	mobile_hud.name = "MobileHUDScene"
	_gameplay_group.add_child(mobile_hud)
	_joystick_base = mobile_hud.get_node("MovementJoystick") as Panel
	_joystick_knob = mobile_hud.get_node("MovementJoystick/Knob") as Panel
	_jump_button = mobile_hud.get_node("JumpButton") as Button
	_run_button = mobile_hud.get_node("RunButton") as Button
	_crouch_button = mobile_hud.get_node("CrouchButton") as Button
	mobile_hud.movement_changed.connect(func(value: Vector2): movement_vector = value)
	mobile_hud.jump_requested.connect(func(): _jump_requested = true)
	mobile_hud.run_changed.connect(_on_run_toggled)
	mobile_hud.crouch_changed.connect(_on_crouch_toggled)
	_build_proposal_hud(_communication_group, _inventory_group, _notice_group)
	_build_context_buttons(_context_group, _inventory_group)
	_hud_layout_manager = HUD_LAYOUT_MANAGER_SCRIPT.new()
	_hud_layout_manager.name = "HUDLayoutManager"
	add_child(_hud_layout_manager)
	_hud_layout_manager.call("configure", root, [
		_joystick_base, _jump_button, _run_button, _crouch_button,
		_speaker_button, _mic_button, _chat_button, _trash_button,
		_interact_button, _hide_button, _heal_button, _slot_one, _slot_two
	])

func _make_control_group(parent: Control, group_name: String, z_value: int, filter: int) -> Control:
	var group := Control.new()
	group.name = group_name
	group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	group.mouse_filter = filter
	group.z_index = z_value
	parent.add_child(group)
	return group


func _build_proposal_hud(communication_root: Control, inventory_root: Control, notice_root: Control) -> void:
	_speaker_button = _make_round_button(communication_root, "SPK", Vector2.ZERO, "Suara")
	_speaker_button.toggle_mode = true
	_speaker_button.pressed.connect(_toggle_speaker)
	_mic_button = _make_round_button(communication_root, "MIC", Vector2.ZERO, "Mikrofon")
	_mic_button.toggle_mode = true
	_mic_button.pressed.connect(_toggle_mic)
	_chat_button = _make_round_button(communication_root, "CHAT", Vector2.ZERO, "Chat")
	_chat_button.pressed.connect(_toggle_chat)
	_position_communication_buttons.call_deferred()

	_trash_button = TrashIconButton.new()
	_trash_button.name = "DropItemButton"
	_trash_button.tooltip_text = "Buang item dari slot terpilih"
	_trash_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_trash_button.offset_left = 66.0
	_trash_button.offset_top = -74.0
	_trash_button.offset_right = 112.0
	_trash_button.offset_bottom = -26.0
	_trash_button.focus_mode = Control.FOCUS_NONE
	_trash_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_trash_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_trash_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_trash_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_trash_button.pressed.connect(_drop_selected_item)
	inventory_root.add_child(_trash_button)

	_notice_panel = PanelContainer.new()
	_notice_panel.name = "MobileNoticePanel"
	_notice_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice_panel.offset_left = -190.0
	_notice_panel.offset_top = 68.0
	_notice_panel.offset_right = 190.0
	_notice_panel.offset_bottom = 112.0
	_notice_panel.visible = false
	_notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_panel.add_theme_stylebox_override("panel", _button_style(Color(0.035, 0.05, 0.065, 0.94), Color(0.55, 0.7, 0.78, 0.9), 10))
	notice_root.add_child(_notice_panel)
	_notice_label = Label.new()
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_label.custom_minimum_size.y = 34.0
	_notice_label.add_theme_font_size_override("font_size", 12)
	_notice_label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
	_notice_panel.add_child(_notice_label)

func _build_context_buttons(context_root: Control, inventory_root: Control) -> void:
	_interact_button = _make_button(context_root, "INTERAKSI", Vector2(-120, -214), Vector2(94, 58))
	_interact_button.name = "ContextInteractButton"
	_interact_button.visible = false
	_interact_button.button_down.connect(_on_mobile_interact)
	_interact_button.button_up.connect(_on_mobile_stop_interact)
	_hide_button = _make_button(context_root, "SEMBUNYI", Vector2(-218, -210), Vector2(84, 56))
	_hide_button.name = "ContextHideButton"
	_hide_button.visible = false
	_hide_button.pressed.connect(_on_mobile_hide)
	_heal_button = _make_button(context_root, "SEMBUHKAN", Vector2(-218, -274), Vector2(84, 56))
	_heal_button.name = "ContextHealButton"
	_heal_button.visible = false
	_heal_button.button_down.connect(_on_mobile_heal)
	_heal_button.button_up.connect(_on_mobile_stop_heal)

	_slot_one = _make_inventory_slot(inventory_root, "1")
	_slot_one.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_slot_one.offset_left = -56.0
	_slot_one.offset_top = -74.0
	_slot_one.offset_right = -4.0
	_slot_one.offset_bottom = -26.0
	_slot_two = _make_inventory_slot(inventory_root, "2")
	_slot_two.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_slot_two.offset_left = 4.0
	_slot_two.offset_top = -74.0
	_slot_two.offset_right = 56.0
	_slot_two.offset_bottom = -26.0
	_slot_one.pressed.connect(_on_inventory_slot_pressed.bind(0))
	_slot_two.pressed.connect(_on_inventory_slot_pressed.bind(1))
	_refresh_inventory_buttons()


func _make_inventory_slot(parent: Control, caption: String) -> Button:
	var slot := SketchActionButton.new()
	slot.sketch_kind = "box"
	slot.name = "InventorySlot" + caption
	slot.text = caption
	slot.custom_minimum_size = Vector2(52, 48)
	slot.toggle_mode = true
	slot.focus_mode = Control.FOCUS_NONE
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.add_theme_font_size_override("font_size", 15)
	slot.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0, 1.0))
	slot.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	slot.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	slot.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	slot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(slot)
	return slot

func _get_inventory_node() -> Node:
	return player.get_node_or_null("ItemInventory") if player != null else null


func _on_inventory_slot_pressed(index: int) -> void:
	var inventory := _get_inventory_node()
	if inventory != null and inventory.has_method("_select_slot"):
		inventory.call("_select_slot", index)
	_refresh_inventory_buttons()


func _drop_selected_item() -> void:
	var inventory := _get_inventory_node()
	if inventory == null or not inventory.has_method("_drop_selected"):
		_show_hud_notice("Inventaris tidak tersedia.")
		return
	inventory.call("_drop_selected")
	_refresh_inventory_buttons()


func _refresh_inventory_buttons() -> void:
	var inventory := _get_inventory_node()
	if inventory == null:
		if _slot_one != null:
			_slot_one.disabled = true
		if _slot_two != null:
			_slot_two.disabled = true
		if _trash_button != null:
			_trash_button.disabled = true
		return
	var stored_items: Array = inventory.get("items")
	var selected := int(inventory.get("selected_slot"))
	if _slot_one != null:
		_slot_one.disabled = stored_items.is_empty()
		_slot_one.set_pressed_no_signal(selected == 0 and not stored_items.is_empty())
	if _slot_two != null:
		_slot_two.disabled = stored_items.size() < 2
		_slot_two.set_pressed_no_signal(selected == 1 and stored_items.size() > 1)
	if _trash_button != null:
		_trash_button.disabled = stored_items.is_empty()

func _get_interaction_input() -> Node:
	return player.get_node_or_null("InteractionInput") if player != null else null


func _get_look_target() -> Node:
	var input_node := _get_interaction_input()
	if input_node != null and input_node.has_method("get_mobile_look_target"):
		return input_node.call("get_mobile_look_target") as Node
	return null


func _update_context_buttons() -> void:
	if _interact_button == null or _hide_button == null or player == null:
		return
	var hidden := bool(player.get_meta("is_hidden", false))
	var target := _get_look_target()
	if hidden:
		_interact_button.visible = false
		_hide_button.visible = true
		_hide_button.text = "KELUAR"
		_heal_button.visible = false
		return
	var can_interact := target != null and (target.has_method("interact") or target.has_method("draw_answer"))
	var can_hide := target != null and target.has_method("toggle_hide")
	var can_heal := target != null and target.has_method("heal")
	_interact_button.visible = can_interact
	_hide_button.visible = can_hide
	_heal_button.visible = can_heal
	if can_interact:
		_interact_button.text = "INTERAKSI"
	if can_hide:
		_hide_button.text = "SEMBUNYI"


func _on_mobile_interact() -> void:
	var input_node := _get_interaction_input()
	if input_node != null and input_node.has_method("mobile_interact"):
		input_node.call("mobile_interact")


func _on_mobile_stop_interact() -> void:
	var input_node := _get_interaction_input()
	if input_node != null and input_node.has_method("mobile_stop_interact"):
		input_node.call("mobile_stop_interact")

func _on_mobile_hide() -> void:
	var input_node := _get_interaction_input()
	if input_node != null and input_node.has_method("mobile_hide"):
		input_node.call("mobile_hide")
	elif player != null:
		hide_requested = true


func _on_mobile_heal() -> void:
	var input_node := _get_interaction_input()
	if input_node != null and input_node.has_method("mobile_heal"):
		input_node.call("mobile_heal")
	else:
		heal_pressed = true


func _on_mobile_stop_heal() -> void:
	var input_node := _get_interaction_input()
	if input_node != null and input_node.has_method("mobile_stop_heal"):
		input_node.call("mobile_stop_heal")
	heal_pressed = false

var _minimap_panel_ref: Control = null
var _minimap_next_lookup_msec := 0
var _comm_last_base := Vector2(-99999.0, -99999.0)
var _comm_next_force_msec := 0
var _comm_was_editing := false


# MinimapPanel dicari sekali lalu disimpan. Sebelumnya find_child() menelusuri seluruh pohon
# scene (ribuan node) di SETIAP frame, itulah yang membuat game terasa berat terus-menerus.
func _get_minimap_panel() -> Control:
	if is_instance_valid(_minimap_panel_ref):
		return _minimap_panel_ref
	var now := Time.get_ticks_msec()
	if now < _minimap_next_lookup_msec:
		return null
	_minimap_next_lookup_msec = now + 1000
	_minimap_panel_ref = get_tree().root.find_child("MinimapPanel", true, false) as Control
	return _minimap_panel_ref


func _position_communication_buttons() -> void:
	if _hud_layout_manager != null and _hud_layout_manager.has_method("is_editing") and bool(_hud_layout_manager.call("is_editing")):
		_comm_was_editing = true
		return
	if _comm_was_editing:
		_comm_was_editing = false
		_comm_last_base = Vector2(-99999.0, -99999.0)

	if _speaker_button == null or _mic_button == null or _chat_button == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var base_position := Vector2(maxf(12.0, viewport_size.x - 158.0), 74.0)
	var map_panel := _get_minimap_panel()
	if map_panel != null and map_panel.is_inside_tree() and map_panel.is_visible_in_tree():
		var map_rect := map_panel.get_global_rect()
		base_position = Vector2(map_rect.position.x, map_rect.position.y + map_rect.size.y + 8.0)
	# Tulis ulang posisi hanya bila berubah (atau tiap 0,5 dtk sebagai pengaman). Menulis
	# anchor/offset tiga tombol di setiap frame memicu hitung ulang layout terus-menerus.
	var now := Time.get_ticks_msec()
	if base_position.is_equal_approx(_comm_last_base) and now < _comm_next_force_msec:
		return
	_comm_last_base = base_position
	_comm_next_force_msec = now + 500
	_anchor_top_left(_speaker_button, base_position)
	_anchor_top_left(_mic_button, base_position + Vector2(50.0, 0.0))
	_anchor_top_left(_chat_button, base_position + Vector2(100.0, 0.0))

func _anchor_top_left(button: Control, pos: Vector2) -> void:
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.offset_left = pos.x
	button.offset_top = pos.y
	button.offset_right = pos.x + 44.0
	button.offset_bottom = pos.y + 44.0


func _make_round_button(root: Control, caption: String, pos: Vector2, hint: String) -> Button:
	var button := SketchActionButton.new()
	button.sketch_kind = "circle"
	button.name = hint + "Button"
	button.text = caption
	button.tooltip_text = hint
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.offset_left = pos.x
	button.offset_top = pos.y
	button.offset_right = pos.x + 44.0
	button.offset_bottom = pos.y + 44.0
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 10 if caption != "CHAT" else 9)
	button.add_theme_color_override("font_color", Color(0.04, 0.045, 0.04, 0.0))
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	root.add_child(button)
	return button

func _button_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	return style

func _toggle_speaker() -> void:
	_audio_muted = not _audio_muted
	var communication := get_tree().root.find_child("MultiplayerCommunication", true, false)
	if communication != null and communication.has_method("set_remote_voice_muted"):
		communication.call("set_remote_voice_muted", _audio_muted)
	else:
		var bus := AudioServer.get_bus_index("VoicePlayback")
		if bus >= 0:
			AudioServer.set_bus_mute(bus, _audio_muted)
	if _speaker_button != null:
		_speaker_button.set_pressed_no_signal(_audio_muted)
		_speaker_button.tooltip_text = "Suara dimatikan" if _audio_muted else "Suara aktif"

func _toggle_mic() -> void:
	# Minta izin Android segera saat pemain menekan MIC, bahkan bila sesi multiplayer
	# belum aktif. Sebelumnya pemeriksaan sesi menghentikan alur sebelum dialog izin.
	if OS.get_name() == "Android" and not OS.get_granted_permissions().has("android.permission.RECORD_AUDIO"):
		OS.request_permission("android.permission.RECORD_AUDIO")
		_show_hud_notice("Izin mikrofon diminta. Izinkan pada dialog Android, lalu tekan MIC lagi.")
		return

	var communication := get_tree().root.find_child("MultiplayerCommunication", true, false)
	if communication == null or not communication.has_method("set_voice_enabled"):
		if _mic_button != null:
			_mic_button.set_pressed_no_signal(_mic_enabled)
		_show_hud_notice("Izin mikrofon tersedia; untuk berbicara, masuk ke sesi multiplayer terlebih dahulu.")
		return
	var requested := not _mic_enabled
	var activated: bool = bool(communication.call("set_voice_enabled", requested))
	if not activated and requested:
		if _mic_button != null:
			_mic_button.set_pressed_no_signal(_mic_enabled)
		_show_hud_notice("Mikrofon gagal aktif. Periksa izin dan koneksi.")
		return
	_mic_enabled = requested
	if _mic_button != null:
		_mic_button.set_pressed_no_signal(_mic_enabled)
		_mic_button.tooltip_text = "Mikrofon aktif" if _mic_enabled else "Mikrofon mati"

func _toggle_chat() -> void:
	var communication := get_tree().root.find_child("MultiplayerCommunication", true, false)
	if communication != null and communication.has_method("toggle_chat"):
		communication.call("toggle_chat")
	else:
		_show_hud_notice("Chat tersedia saat sesi multiplayer aktif.")



func show_notification(message: String) -> void:
	_show_hud_notice(message)


func _show_hud_notice(message: String) -> void:
	if _notice_label != null and _notice_panel != null:
		_notice_label.text = message
		_notice_panel.visible = true
		_notice_remaining = 2.8

func open_hud_layout_editor() -> void:
	if _hud_layout_manager != null and _hud_layout_manager.has_method("open_editor"):
		_hud_layout_manager.call("open_editor")

func _process(delta: float) -> void:
	_position_communication_buttons()
	if _hud_layout_manager != null and _hud_layout_manager.has_method("apply_layout"):
		_hud_layout_manager.call("apply_layout")
	_refresh_inventory_buttons()
	if _notice_remaining > 0.0:
		_notice_remaining -= delta
		if _notice_remaining <= 0.0 and _notice_panel != null:
			_notice_panel.visible = false
	if not is_mobile():
		return
	_context_refresh -= delta
	if _context_refresh <= 0.0:
		_context_refresh = 0.12
		_update_context_buttons()

func _make_button(root: Control, text_value: String, offset: Vector2, button_size: Vector2) -> Button:
	var button := SketchActionButton.new()
	button.sketch_kind = "circle" if text_value == "LOMPAT" or text_value == "JONGKOK" else "rough"
	button.name = text_value.replace("\n", "_").replace(" ", "") + "Button"
	button.text = text_value
	button.tooltip_text = text_value.replace("\n", " ")
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = offset.x
	button.offset_top = offset.y
	button.offset_right = offset.x + button_size.x
	button.offset_bottom = offset.y + button_size.y
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 14)
	var show_button_text := not (text_value == "LOMPAT" or text_value == "JONGKOK")
	button.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0, 1.0 if show_button_text else 0.0))
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	root.add_child(button)
	return button

func _panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style

# Input joystick hanya diproses oleh MobileHUD.gd. Handler joystick lama di sini
# sengaja dihapus agar tidak ada jalur kedua yang dapat mengubah movement_vector.


func _on_run_toggled(enabled: bool) -> void:
	run_enabled = enabled
	_run_button.text = "LARI: ON" if enabled else "LARI: OFF"


func _on_crouch_toggled(enabled: bool) -> void:
	crouch_enabled = enabled
	_crouch_button.text = "JONGKOK: ON" if enabled else "JONGKOK"
