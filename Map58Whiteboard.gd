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
var _current_question: Dictionary = {}
var _drawing := false
var _draw_motion_pending := false
var _strokes: Array = []
var _current_stroke := PackedVector2Array()
var _last_board_point := Vector2(-INF, -INF)


func _ready() -> void:
	call_deferred("_initialize")


func _initialize() -> void:
	_game = get_node_or_null("../GameManager")
	_player = get_node_or_null("../Player/CharacterBody3D") as CharacterBody3D

	if _player != null:
		_camera = _player.get_node_or_null("Camera3D") as Camera3D

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


func _input(event: InputEvent) -> void:
	if _camera == null or _board_collision == null:
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
			if _handle_left_press():
				get_viewport().set_input_as_handled()
		else:
			if _drawing:
				_stop_drawing()
				get_viewport().set_input_as_handled()
		return

	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		if _handle_right_press():
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _player == null or _camera == null or _board_collision == null:
		return

	if _drawing and _draw_motion_pending:
		_draw_motion_pending = false
		_add_board_point_from_center()

	_update_prompt()


func _handle_left_press() -> bool:
	if not _ray_hits_xiid_board():
		return false

	if _game == null or not _game.has_method("begin_board_question"):
		return false

	if not _question_active:
		_current_question = _game.begin_board_question(_player, _board_root)
		if _current_question.is_empty():
			return true

		_question_active = true
		_question_label.visible = true
		_question_label.text = "SOAL:\n" + String(_current_question.get("question", ""))
		_clear_answer()

	_start_drawing()
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


func _start_drawing() -> void:
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


func _submit_written_answer() -> void:
	if _recognizer == null:
		_set_status("DigitRecognizer.gd tidak tersedia.")
		return

	if _strokes.is_empty():
		_set_status("Belum ada jawaban di papan.")
		return

	var expected := String(_current_question.get("answer", "")).strip_edges()
	var result: Dictionary = _recognizer.recognize_against_answer(_strokes, expected)
	var recognized := String(result.get("text", "")).strip_edges()
	var readable := bool(result.get("ok", false))

	if not readable or recognized.is_empty():
		_set_status("Jawaban tidak terbaca. Hapus dengan klik kiri papan lalu coba lagi.")
		return

	var correct := recognized == expected
	if _game.has_method("submit_board_answer"):
		_game.submit_board_answer(_player, recognized)

	if correct:
		_set_status("BENAR: " + recognized)
	else:
		_set_status("SALAH: " + recognized)

	_question_active = false
	_question_label.visible = false
	_clear_answer()


func _ray_hits_xiid_board() -> bool:
	var viewport_center := _camera.get_viewport().get_visible_rect().size * 0.5
	var from := _camera.project_ray_origin(viewport_center)
	var to := from + _camera.project_ray_normal(viewport_center) * 3.0

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
	var viewport_center := _camera.get_viewport().get_visible_rect().size * 0.5
	var from := _camera.project_ray_origin(viewport_center)
	var to := from + _camera.project_ray_normal(viewport_center) * 3.0

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

	if _last_board_point.x == -INF:
		_current_stroke.append(point)
		_draw_dot(point)
	else:
		var distance := _last_board_point.distance_to(point)
		if distance >= DRAW_SENSITIVITY_MIN_DISTANCE:
			_current_stroke.append(point)
			_draw_segment(_last_board_point, point)

	_last_board_point = point


func _clear_answer() -> void:
	_strokes.clear()
	_current_stroke = PackedVector2Array()
	_last_board_point = Vector2(-INF, -INF)

	if _image != null:
		_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	if _texture != null and _image != null:
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


func _create_status_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "WhiteboardUI"
	canvas.layer = 31
	add_child(canvas)

	_status_label = Label.new()
	_status_label.position = Vector2(24, 140)
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_status_label)


func _update_prompt() -> void:
	if _status_label == null:
		return

	if _question_active:
		_status_label.text = "PAPAN XII D: tahan klik kiri = menulis | klik kanan = koreksi"
	elif _ray_hits_xiid_board():
		_status_label.text = "KLIK KIRI — mulai mengerjakan soal di papan XII D"
	else:
		_status_label.text = ""


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message
