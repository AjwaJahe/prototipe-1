extends Node

## Controller papan tulis untuk Kelas XII D.
## Tidak mengubah furniture. Controller hanya membaca collider papan
## yang sudah ada dan menambahkan permukaan tulisan secara runtime.

const BOARD_PATH := NodePath("../Furniture/Kelas_12_D_Furniture/FurnitureRoot/Whiteboard")
const BOARD_WIDTH: float = 9.16
const BOARD_HEIGHT: float = 2.28
const IMAGE_WIDTH: int = 1200
const IMAGE_HEIGHT: int = 672
const BRUSH_RADIUS: int = 10
const DRAW_SENSITIVITY_MIN_DISTANCE: float = 1.0
const SURFACE_OFFSET: float = -0.081

var _game: Node = null
var _player: CharacterBody3D = null
var _camera: Camera3D = null
var _board_root: Node3D = null
var _board_collision: StaticBody3D = null

var _writing_surface: MeshInstance3D
var _question_label: Label3D
var _status_label: Label

var _image: Image
var _texture: ImageTexture
var _recognizer: RefCounted

var _question_active := false
var _network_question_visible := false
var _network_last_board_point := Vector2(-INF, -INF)
var _current_question: Dictionary = {}
var _drawing := false
var _draw_motion_pending := false
var _strokes: Array = []
var _current_stroke := PackedVector2Array()
var _last_board_point := Vector2(-INF, -INF)

# Mode POV khusus papan tulis. Posisi tubuh tetap; kamera dipindah sementara.
var _whiteboard_mode := false
var _whiteboard_mobile_mode := false
var _saved_camera_position := Vector3.ZERO
var _saved_camera_rotation := Vector3.ZERO
var _saved_camera_fov := 75.0
var _saved_player_rotation := Vector3.ZERO
var _mobile_controls: Node = null
var _tool_mode := "chalk"
var _tool_buttons: Dictionary = {}
var _whiteboard_canvas: CanvasLayer
var _whiteboard_controls: HBoxContainer
var _ui_touch_id := -1
var _draw_touch_id := -1


func _ready() -> void:
	call_deferred("_initialize")


func _initialize() -> void:
	_game = get_node_or_null("../GameManager")
	_player = get_node_or_null("../Player/CharacterBody3D") as CharacterBody3D

	if _player != null:
		_camera = _player.get_node_or_null("Camera3D") as Camera3D
		_mobile_controls = _player.get_node_or_null("MobileControls")

	_board_root = get_node_or_null(BOARD_PATH) as Node3D
	if _board_root == null:
		push_error("Map58Whiteboard: Kelas XII D Whiteboard tidak ditemukan.")
		return

	_board_collision = _board_root.get_node_or_null("FurnitureCollision") as StaticBody3D
	if _board_collision == null:
		push_error("Map58Whiteboard: collider Whiteboard XII D tidak ditemukan.")
		return

	var recognizer_script := load("res://DigitRecognizer.gd") as Script
	if recognizer_script != null:
		_recognizer = recognizer_script.new() as RefCounted

	_create_writing_surface()
	_create_question_label()
	_create_status_ui()
	if _game != null and _game.has_signal("phase_changed"):
		_game.phase_changed.connect(_on_game_phase_changed)


func _input(event: InputEvent) -> void:
	if _camera == null or _board_collision == null:
		return

	# Di HP, Godot dapat mengirim mouse event sintetis bersamaan dengan touch.
	# Saat mode papan aktif, abaikan mouse sintetis agar titik tengah layar tidak
	# ikut menggambar; coretan mobile hanya berasal dari posisi jari aktual.
	var mobile_input := _mobile_controls != null and _mobile_controls.has_method("is_mobile") and bool(_mobile_controls.call("is_mobile"))
	if _whiteboard_mode and mobile_input and (event is InputEventMouseButton or event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()
		return

	# UI harus mendapat kesempatan memproses klik/tap lebih dulu. _input berjalan
	# sebelum GUI, jadi kita perlu mengecek kontrol interaktif dan modal secara eksplisit.
	if event is InputEventMouseButton:
		var pointer_event := event as InputEventMouseButton
		if _is_pointer_over_ui(pointer_event.position):
			if not pointer_event.pressed and _drawing:
				_stop_drawing()
			return

	# Touch papan memulai soal; setelah masuk mode, drag jari hanya untuk menulis.
	# Event ditandai selesai agar MobileControls tidak menggeser POV bersamaan.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _is_pointer_over_ui(touch.position):
			_ui_touch_id = touch.index
			return
		if not touch.pressed and touch.index == _ui_touch_id:
			_ui_touch_id = -1
			return
		if _ui_touch_id == touch.index:
			return
		if _whiteboard_mode:
			if touch.pressed:
				# Kunci stroke pada jari yang benar-benar memulainya.
				if _draw_touch_id == -1 and _ray_hits_board_at(touch.position):
					_draw_touch_id = touch.index
					_start_drawing(touch.position)
			else:
				# Jari lain tidak boleh menghentikan coretan yang sedang berjalan.
				if touch.index == _draw_touch_id:
					_stop_drawing()
					_draw_touch_id = -1
			get_viewport().set_input_as_handled()
			return
		if touch.pressed and _ray_hits_board_at(touch.position):
			_handle_left_press_at(touch.position)
			if _whiteboard_mode and _drawing:
				_draw_touch_id = touch.index
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _ui_touch_id:
			return
		if _whiteboard_mode:
			if _drawing and drag.index == _draw_touch_id:
				_add_board_point_at(drag.position)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and _whiteboard_mode:
			if key_event.keycode == KEY_BACKSPACE:
				_stop_drawing()
				_clear_answer()
				_set_status("Jawaban dihapus. Tahan klik kiri untuk menulis ulang.")
				get_viewport().set_input_as_handled()
			elif key_event.keycode == KEY_P:
				_stop_drawing()
				_tool_mode = "eraser" if _tool_mode == "chalk" else "chalk"
				_set_status("Penghapus aktif." if _tool_mode == "eraser" else "Kapur aktif.")
				get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		if _drawing:
			_draw_motion_pending = true
		return

	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return

	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if mouse_event.pressed:
			# Gunakan posisi klik aktual; jangan raycast ke tengah layar saat tombol UI ditekan.
			if _handle_left_press_at(mouse_event.position):
				get_viewport().set_input_as_handled()
		else:
			if _drawing:
				_stop_drawing()
				get_viewport().set_input_as_handled()
		return

	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		# Klik kanan mengakhiri tulisan lalu mengoreksi jawaban.
		# Tetap proses saat soal aktif meski ray sedikit bergeser dari collider.
		if _question_active:
			_stop_drawing()
			_submit_written_answer()
			get_viewport().set_input_as_handled()
		elif _handle_right_press():
			get_viewport().set_input_as_handled()


const PROMPT_UPDATE_INTERVAL := 0.1
const STATUS_HOLD_DURATION := 2.5
var _prompt_remaining := 0.0
var _status_hold_remaining := 0.0


func _process(_delta: float) -> void:
	if _player == null or _camera == null or _board_collision == null:
		return

	_status_hold_remaining = maxf(0.0, _status_hold_remaining - _delta)

	if _question_active and _game != null and String(_game.get("phase")) != "BOARD_SOLVING":
		_stop_drawing()
		_reset_question_state()

	if _drawing and _draw_motion_pending:
		_draw_motion_pending = false
		if _whiteboard_mobile_mode:
			_add_board_point_from_center()
		else:
			_add_board_point_at(get_viewport().get_mouse_position())

	_prompt_remaining -= _delta
	if _prompt_remaining <= 0.0:
		_prompt_remaining = PROMPT_UPDATE_INTERVAL
		_update_prompt()


func _handle_left_press() -> bool:
	var center := _camera.get_viewport().get_visible_rect().size * 0.5
	return _handle_left_press_at(center)


func _handle_left_press_at(screen_position: Vector2) -> bool:
	if _whiteboard_mode:
		_start_drawing(screen_position)
		return true
	if not _ray_hits_board_at(screen_position):
		return false

	if _game == null or not _game.has_method("begin_board_question"):
		return false

	if not _question_active:
		if _is_network_client():
			var inventory := _player.get_node_or_null("ItemInventory")
			if inventory == null or not inventory.has_item("paper") or not inventory.has_item("chalk"):
				var missing_message := "Bawa Kertas Soal dan Kapur terlebih dahulu."
				_notify_player(missing_message)
				_set_status(missing_message)
				return true
			var network_game := get_tree().current_scene.get_node_or_null("MultiplayerGame")
			if network_game != null and network_game.has_method("request_board_question"):
				network_game.rpc_id(1, "request_board_question", String(get_tree().current_scene.get_path_to(_board_root)))
			else:
				_set_status("Koneksi multiplayer belum siap.")
			return true
		_current_question = _game.begin_board_question(_player, _board_root)
		if _current_question.is_empty():
			var inventory := _player.get_node_or_null("ItemInventory")
			var message := "Tidak ada kertas soal yang dapat dikerjakan."
			if inventory != null and not inventory.has_item("paper"):
				message = "Tidak ada kertas soal yang dapat dikerjakan. Ambil Kertas Soal terlebih dahulu."
			elif inventory != null and not inventory.has_item("chalk"):
				message = "Bawa Kapur terlebih dahulu untuk mengerjakan soal."
			elif _game != null and String(_game.get("phase")) != "HUNT" and String(_game.get("phase")) != "ESCAPE_READY":
				message = "Papan tulis belum bisa digunakan pada tahap ini."
			_notify_player(message)
			_set_status(message)
			return true

		_question_active = true
		_question_label.visible = true
		_question_label.text = "SOAL:\n" + String(_current_question.get("question", ""))
		_clear_answer()
		_enter_whiteboard_mode()

	_start_drawing(screen_position)
	return true


func _handle_right_press() -> bool:
	if not _ray_hits_xiid_board():
		return false

	if not _question_active:
		_set_status("Bawa Kertas Soal + Kapur, lalu klik kiri papan.")
		return true

	_stop_drawing()
	_submit_written_answer()
	return true


func _start_drawing(screen_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if not _question_active:
		return

	var inventory := _player.get_node_or_null("ItemInventory")
	if inventory == null:
		return

	if not inventory.has_item("paper") or not inventory.has_item("chalk"):
		_set_status("Kamu membutuhkan Kertas Soal dan Kapur.")
		return

	if _drawing:
		return

	_drawing = true
	_current_stroke = PackedVector2Array()
	_last_board_point = Vector2(-INF, -INF)
	# Pada HP, gunakan posisi jari aktual; desktop tetap memakai pusat layar
	# ketika tidak ada koordinat pointer yang diberikan.
	if screen_position.x >= 0.0 and screen_position.y >= 0.0:
		_add_board_point_at(screen_position)
	else:
		_add_board_point_from_center()
	_set_status("Menulis... klik kanan untuk mengoreksi.")


func _stop_drawing() -> void:
	if not _drawing:
		return

	_drawing = false
	if _current_stroke.size() >= 2:
		_strokes.append(_current_stroke)

	_current_stroke = PackedVector2Array()
	_draw_motion_pending = false


# Gambar papan (1200x672) dipetakan ke papan 9.16m x 2.28m, jadi sumbu X koordinat
# stroke ikut terpepat ~2.25x dibanding Y. Sebelum dibaca recognizer, kembalikan
# proporsi aslinya supaya bentuk angka sama seperti yang terlihat di papan.
func _strokes_for_recognition() -> Array:
	var x_scale: float = (BOARD_WIDTH / float(IMAGE_WIDTH - 1)) / (BOARD_HEIGHT / float(IMAGE_HEIGHT - 1))
	var corrected: Array = []
	for stroke_value in _strokes:
		var stroke: PackedVector2Array = stroke_value
		var scaled := PackedVector2Array()
		for point in stroke:
			scaled.append(Vector2(point.x * x_scale, point.y))
		corrected.append(scaled)
	return corrected

func _submit_written_answer() -> void:
	if _recognizer == null:
		_set_status("DigitRecognizer.gd tidak tersedia.")
		return

	if _strokes.is_empty():
		_set_status("Belum ada jawaban di papan.")
		return

	var expected := String(_current_question.get("answer", "")).strip_edges()
	var recog_strokes: Array = _strokes_for_recognition()
	var result: Dictionary = _recognizer.recognize_against_answer(recog_strokes, expected)
	var recognized := String(result.get("text", "")).strip_edges()
	var readable := bool(result.get("ok", false))

	# "ok" dari recognize_against_answer berarti tulisan cocok dengan jawaban
	# yang diharapkan, bukan sekadar berhasil dibaca. Jika ada digit terbaca
	# tetapi berbeda dari kunci, tetap kirim ke game agar dinilai SALAH,
	# mode papan ditutup, dan guru masuk mode BERSEK.
	if recognized.is_empty():
		var diagnostic: Dictionary = _recognizer.recognize_strokes(recog_strokes)
		var diagnostic_text := String(diagnostic.get("text", "")).strip_edges()
		var diagnostic_score := float(diagnostic.get("score", 0.0))
		var diagnostic_ok := bool(diagnostic.get("ok", false))
		if not diagnostic_ok or diagnostic_text.is_empty():
			if diagnostic_text.is_empty():
				_set_status("Anda menulis: [sistem belum berhasil membaca angka] | skor: " + str(snappedf(diagnostic_score, 0.01)))
			else:
				_set_status("Anda menulis: " + diagnostic_text + " | skor: " + str(snappedf(diagnostic_score, 0.01)) + " | belum dapat dinilai")
			return
		recognized = diagnostic_text

	if _game == null or not _game.has_method("submit_board_answer"):
		_set_status("Game belum siap menerima jawaban.")
		return

	if _is_network_client():
		var network_game := get_tree().current_scene.get_node_or_null("MultiplayerGame")
		if network_game != null and network_game.has_method("request_board_answer"):
			network_game.rpc_id(1, "request_board_answer", recognized)
			_set_status("Jawaban dikirim ke host untuk diperiksa...")
		else:
			_set_status("Koneksi multiplayer belum siap.")
		return

	var correct: bool = _game.submit_board_answer(_player, recognized)
	if not correct and String(_game.get("phase")) == "BOARD_SOLVING":
		_set_status("Jawaban belum diterima game. Coba lagi.")
		return

	if correct:
		_set_status("BENAR: " + recognized)
	else:
		_set_status("SALAH: " + recognized)

	_reset_question_state()


func _reset_question_state() -> void:
	_question_active = false
	_current_question = {}
	_question_label.visible = false
	_clear_answer()
	_drawing = false
	_draw_motion_pending = false
	_exit_whiteboard_mode()


func _ray_hits_xiid_board() -> bool:
	var center := _camera.get_viewport().get_visible_rect().size * 0.5
	return _ray_hits_board_at(center)


func _ray_hits_board_at(screen_position: Vector2) -> bool:
	var from := _camera.project_ray_origin(screen_position)
	var to := from + _camera.project_ray_normal(screen_position) * (7.0 if _whiteboard_mode else 3.0)

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [_player.get_rid()]

	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false

	var collider := hit.get("collider") as Node
	if collider == null:
		return false

	var current: Node = collider
	while current != null:
		if current == _board_collision:
			return true
		current = current.get_parent()

	return false


func _add_board_point_from_center() -> void:
	var center := _camera.get_viewport().get_visible_rect().size * 0.5
	_add_board_point_at(center)


func _add_board_point_at(screen_position: Vector2) -> void:
	var from := _camera.project_ray_origin(screen_position)
	var to := from + _camera.project_ray_normal(screen_position) * (7.0 if _whiteboard_mode else 3.0)

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [_player.get_rid()]

	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var collider := hit.get("collider") as Node
	if collider == null or collider != _board_collision:
		return

	var hit_position: Vector3 = hit.get("position", _board_root.global_position)
	var local := _board_root.global_transform.affine_inverse() * hit_position

	# Papan XII D membentang sepanjang lokal Z, bukan X.
	var px := (local.z / BOARD_WIDTH + 0.5) * float(IMAGE_WIDTH - 1)
	var py := (0.5 - local.y / BOARD_HEIGHT) * float(IMAGE_HEIGHT - 1)
	var point := Vector2(px, py)

	if point.x < 0.0 or point.x >= IMAGE_WIDTH or point.y < 0.0 or point.y >= IMAGE_HEIGHT:
		return

	if _tool_mode == "eraser":
		_erase_board_point(point)
		_send_network_board_point(point, true)
		_last_board_point = point
		return

	if _last_board_point.x == -INF:
		_current_stroke.append(point)
		_draw_dot(point)
	else:
		var distance := _last_board_point.distance_to(point)
		if distance >= DRAW_SENSITIVITY_MIN_DISTANCE:
			_current_stroke.append(point)
			_draw_segment(_last_board_point, point)

	_send_network_board_point(point, false)
	_last_board_point = point


func _send_network_board_point(point: Vector2, eraser: bool) -> void:
	if not _question_active or not _is_network_client():
		return
	if not is_finite(point.x) or not is_finite(point.y):
		return
	var network_game := get_tree().current_scene.get_node_or_null("MultiplayerGame")
	if network_game != null and network_game.has_method("request_board_draw_point"):
		network_game.rpc_id(1, "request_board_draw_point", point, eraser)


func _is_network_client() -> bool:
	if not bool(get_tree().get_meta("kelas_malam_multiplayer_active", false)):
		return false
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return false
	return not multiplayer.is_server()


func _send_network_board_clear() -> void:
	if not _question_active or not _is_network_client():
		return
	var network_game := get_tree().current_scene.get_node_or_null("MultiplayerGame")
	if network_game != null and network_game.has_method("request_board_clear"):
		network_game.rpc_id(1, "request_board_clear")


func network_clear_board() -> void:
	_clear_answer()
	_network_last_board_point = Vector2(-INF, -INF)


func network_draw_point(point: Vector2, eraser: bool) -> void:
	if not is_finite(point.x) or not is_finite(point.y):
		return
	if _image == null or point.x < 0.0 or point.x >= IMAGE_WIDTH or point.y < 0.0 or point.y >= IMAGE_HEIGHT:
		return
	if eraser:
		_erase_board_point(point)
	else:
		if _network_last_board_point.x == -INF:
			_draw_circle(point)
		else:
			_draw_segment(_network_last_board_point, point)
	_network_last_board_point = point
	if _texture != null:
		_texture.update(_image)


func _clear_answer() -> void:
	_strokes.clear()
	_current_stroke = PackedVector2Array()
	_last_board_point = Vector2(-INF, -INF)

	if _image != null:
		_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	if _texture != null and _image != null:
		_texture.update(_image)


func _erase_board_point(point: Vector2) -> void:
	# Hapus tinta pada area kecil di sekitar ujung penghapus.
	var radius := BRUSH_RADIUS * 2
	var cx := int(round(point.x))
	var cy := int(round(point.y))
	for y in range(maxi(0, cy - radius), mini(IMAGE_HEIGHT - 1, cy + radius) + 1):
		for x in range(maxi(0, cx - radius), mini(IMAGE_WIDTH - 1, cx + radius) + 1):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= radius * radius:
				_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))

	# Sinkronkan titik OCR dengan coretan yang masih tersisa setelah dihapus.
	var filtered_strokes: Array = []
	for stroke_value in _strokes:
		var stroke: PackedVector2Array = stroke_value
		var segment := PackedVector2Array()
		for stroke_point in stroke:
			if stroke_point.distance_to(point) <= float(radius):
				if segment.size() >= 2:
					filtered_strokes.append(segment)
				segment = PackedVector2Array()
			else:
				segment.append(stroke_point)
		if segment.size() >= 2:
			filtered_strokes.append(segment)
	_strokes = filtered_strokes
	if _texture != null:
		_texture.update(_image)


func _draw_dot(point: Vector2) -> void:
	_draw_circle(point)
	if _texture != null:
		_texture.update(_image)


func _draw_segment(from_point: Vector2, to_point: Vector2) -> void:
	var distance := from_point.distance_to(to_point)
	var steps: int = maxi(1, int(ceil(distance / 3.0)))

	for i in range(steps + 1):
		var t := float(i) / float(steps)
		_draw_circle(from_point.lerp(to_point, t))

	if _texture != null:
		_texture.update(_image)


func _draw_circle(point: Vector2) -> void:
	var cx := int(round(point.x))
	var cy := int(round(point.y))
	var radius := BRUSH_RADIUS

	var min_x: int = maxi(0, cx - radius)
	var max_x: int = mini(IMAGE_WIDTH - 1, cx + radius)
	var min_y: int = maxi(0, cy - radius)
	var max_y: int = mini(IMAGE_HEIGHT - 1, cy + radius)

	var radius_sq := radius * radius

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= radius_sq:
				_image.set_pixel(x, y, Color(0.93, 0.93, 0.90, 1.0))


func _create_writing_surface() -> void:
	_image = Image.create(IMAGE_WIDTH, IMAGE_HEIGHT, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_texture = ImageTexture.create_from_image(_image)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = _texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var quad := QuadMesh.new()
	quad.size = Vector2(BOARD_WIDTH, BOARD_HEIGHT)

	_writing_surface = MeshInstance3D.new()
	_writing_surface.name = "XIIDWritingSurface"
	_writing_surface.position = Vector3(SURFACE_OFFSET, 0.0, 0.0)
	_writing_surface.rotation.y = -PI * 0.5
	_writing_surface.mesh = quad
	_writing_surface.material_override = material
	_board_root.add_child(_writing_surface)


func _create_question_label() -> void:
	_question_label = Label3D.new()
	_question_label.name = "XIIDQuestion"
	_question_label.visible = false
	_question_label.position = Vector3(SURFACE_OFFSET - 0.01, 0.78, 0.0)
	_question_label.rotation.y = -PI * 0.5
	_question_label.modulate = Color(0.92, 0.96, 0.88, 1.0)
	_question_label.text = ""
	_question_label.font_size = 32
	_question_label.pixel_size = 0.0035
	_question_label.no_depth_test = true
	_board_root.add_child(_question_label)


func _enter_whiteboard_mode() -> void:
	if _whiteboard_mode or _camera == null or _board_root == null:
		return
	_whiteboard_mode = true
	_whiteboard_mobile_mode = _mobile_controls != null and _mobile_controls.has_method("is_mobile") and bool(_mobile_controls.call("is_mobile"))
	# Flag AI terpisah dari lock gerak; desktop tetap boleh berjalan/menoleh.
	_player.set_meta("whiteboard_active", true)
	if _whiteboard_mobile_mode:
		_saved_camera_position = _camera.position
		_saved_camera_rotation = _camera.rotation
		_saved_camera_fov = _camera.fov
		_player.set_meta("whiteboard_mode", true)
		_player.velocity = Vector3.ZERO
		# HP: arahkan POV ke papan dan kunci seluruh gerak pemain.
		var camera_target := _board_root.to_global(Vector3(SURFACE_OFFSET, 0.18, 0.0))
		_camera.global_position = _board_root.to_global(Vector3(-5.4, 0.18, 0.0))
		_camera.look_at(camera_target, Vector3.UP)
		_camera.fov = 58.0
	else:
		# Komputer: jangan kunci WASD/POV atau pindahkan kameranya.
		_player.set_meta("whiteboard_mode", false)
	if _mobile_controls != null and _mobile_controls.has_method("set_whiteboard_mode"):
		_mobile_controls.call("set_whiteboard_mode", _whiteboard_mobile_mode)
	if _whiteboard_controls != null:
		# Kolom alat papan hanya untuk HP; komputer memakai mouse + tombol keyboard.
		_whiteboard_controls.visible = _whiteboard_mobile_mode
	_tool_mode = "chalk"


func _exit_whiteboard_mode() -> void:
	if not _whiteboard_mode:
		return
	_whiteboard_mode = false
	if _whiteboard_mobile_mode and is_instance_valid(_camera):
		_camera.position = _saved_camera_position
		_camera.rotation = _saved_camera_rotation
		_camera.fov = _saved_camera_fov
	if is_instance_valid(_player):
		_player.set_meta("whiteboard_mode", false)
		_player.set_meta("whiteboard_active", false)
		if _whiteboard_mobile_mode:
			_player.velocity = Vector3.ZERO
	if _mobile_controls != null and _mobile_controls.has_method("set_whiteboard_mode"):
		_mobile_controls.call("set_whiteboard_mode", false)
	if _whiteboard_controls != null:
		_whiteboard_controls.visible = false
	_whiteboard_mobile_mode = false


func _create_status_ui() -> void:
	_whiteboard_canvas = CanvasLayer.new()
	_whiteboard_canvas.name = "WhiteboardUI"
	_whiteboard_canvas.layer = 31
	add_child(_whiteboard_canvas)

	var root := Control.new()
	root.name = "WhiteboardRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Root papan hanya wadah; jangan biarkan area layar penuh menghalangi HUD layer 29-30.
	# Tombol anak WhiteboardTools tetap menerima input saat panel alatnya terlihat.
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_whiteboard_canvas.add_child(root)

	_status_label = Label.new()
	_status_label.position = Vector2(24, 100)
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_status_label)

	_whiteboard_controls = HBoxContainer.new()
	_whiteboard_controls.name = "WhiteboardTools"
	_whiteboard_controls.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_whiteboard_controls.offset_left = 18.0
	_whiteboard_controls.offset_top = -76.0
	_whiteboard_controls.offset_right = 588.0
	_whiteboard_controls.offset_bottom = -14.0
	_whiteboard_controls.add_theme_constant_override("separation", 8)
	_whiteboard_controls.visible = false
	root.add_child(_whiteboard_controls)

	_add_tool_button("KAPUR", "chalk", 82)
	_add_tool_button("PENGHAPUS", "eraser", 100)
	_add_tool_button("HAPUS SEMUA", "clear", 112)
	_add_tool_button("SELESAI / KOREKSI", "submit", 148)


func _is_pointer_over_ui(screen_position: Vector2) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	var pending: Array[Node] = [get_tree().root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
		if not node is Control:
			continue
		var control := node as Control
		if not control.is_visible_in_tree() or control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		var rect := control.get_global_rect()
		if not rect.has_point(screen_position):
			continue
		# Form fields, sliders and buttons always belong to the GUI, never to the 3D board.
		if control is BaseButton or control is LineEdit or control is TextEdit or control is Range or control is Tree or control is ItemList:
			return true
		# Modal dimmers cover the screen; clicks on their blank area must not hit the board.
		if control is ColorRect and control.mouse_filter == Control.MOUSE_FILTER_STOP and rect.size.x >= viewport_size.x * 0.8 and rect.size.y >= viewport_size.y * 0.8:
			return true
	return false


func _add_tool_button(caption: String, action: String, width: float) -> void:
	var button := Button.new()
	button.name = "Whiteboard_" + action.capitalize()
	button.text = caption
	button.custom_minimum_size = Vector2(width, 54)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(_on_tool_button_pressed.bind(action))
	_whiteboard_controls.add_child(button)
	_tool_buttons[action] = button


func _on_tool_button_pressed(action: String) -> void:
	match action:
		"chalk":
			_stop_drawing()
			_tool_mode = "chalk"
			_set_status("Kapur aktif. Sentuh dan geser di papan untuk menulis.")
		"eraser":
			_stop_drawing()
			_tool_mode = "eraser"
			_set_status("Penghapus aktif. Geser di bagian tulisan yang ingin dihapus.")
		"clear":
			_stop_drawing()
			_clear_answer()
			_send_network_board_clear()
			_set_status("Semua tulisan dihapus.")
		"submit":
			_stop_drawing()
			_submit_written_answer()


func network_public_board_question(question_text: String) -> void:
	if _question_label == null:
		return
	_network_question_visible = true
	_network_last_board_point = Vector2(-INF, -INF)
	_clear_answer()
	_question_label.visible = true
	_question_label.text = "SOAL:\n" + question_text


func network_start_board_question(question: Dictionary) -> void:
	if question.is_empty() or _board_root == null or _question_label == null:
		return
	_network_question_visible = true
	_question_active = true
	_current_question = question.duplicate(true)
	_question_label.visible = true
	_question_label.text = "SOAL:\n" + String(_current_question.get("question", ""))
	_clear_answer()
	_enter_whiteboard_mode()
	_set_status("Soal diterima dari host. Tulis jawaban lalu kirim.")


func network_board_answer_result(correct: bool, recognized: String) -> void:
	_set_status(("BENAR: " if correct else "SALAH: ") + recognized)
	_reset_question_state()


func _on_game_phase_changed(new_phase: String) -> void:
	if new_phase == "BOARD_SOLVING":
		return
	if not _question_active and not _network_question_visible:
		return

	# Saat host mengakhiri soal klien, barang yang dipakai ikut habis secara lokal.
	if _is_network_client():
		var inventory := _player.get_node_or_null("ItemInventory") if is_instance_valid(_player) else null
		if inventory != null and inventory.has_method("consume_item_type"):
			inventory.call("consume_item_type", "paper")
			inventory.call("consume_item_type", "chalk")

	# Timeout / perubahan fase menutup soal dan membersihkan tulisan di papan.
	_question_active = false
	_network_question_visible = false
	_network_last_board_point = Vector2(-INF, -INF)
	_question_label.visible = false
	_drawing = false
	_draw_motion_pending = false
	_clear_answer()
	_exit_whiteboard_mode()
	if new_phase == "HUNT":
		_set_status("Soal ditutup. Waktu habis atau jawaban sudah dikirim.")


func _update_prompt() -> void:
	if _status_label == null or _status_hold_remaining > 0.0:
		return

	if _whiteboard_mode:
		_status_label.text = "MODE PAPAN XII D: pilih KAPUR/PENGHAPUS di kiri bawah, lalu geser pada papan."
	elif _question_active:
		_status_label.text = "PAPAN XII D: tahan klik kiri = menulis | klik kanan = kirim | BACKSPACE = hapus"
	elif _ray_hits_xiid_board():
		_status_label.text = "ARAHKAN KE PAPAN XII D, lalu KLIK KIRI untuk mulai soal"
	else:
		_status_label.text = ""


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message
		_status_hold_remaining = STATUS_HOLD_DURATION


func _notify_player(message: String) -> void:
	var mobile_controls := _player.get_node_or_null("MobileControls") if is_instance_valid(_player) else null
	if mobile_controls != null and mobile_controls.has_method("is_mobile") and bool(mobile_controls.call("is_mobile")):
		if mobile_controls.has_method("show_notification"):
			mobile_controls.call("show_notification", message)
		return
	var ui := get_tree().root.find_child("UIManager", true, false)
	if ui != null and ui.has_method("show_notification"):
		ui.call("show_notification", message)
