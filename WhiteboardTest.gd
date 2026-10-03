extends Node3D


const INTERACT_DISTANCE: float = 6.0
const MAX_SLOTS: int = 2

const BOARD_WIDTH: float = 6.0
const BOARD_HEIGHT: float = 3.36

const IMAGE_WIDTH: int = 1200
const IMAGE_HEIGHT: int = 672

const WRITING_OFFSET: float = 0.08
const BRUSH_RADIUS: int = 10
const ERASER_DRAG_SENSITIVITY: float = 0.0045
const ERASER_HALF_WIDTH: float = 0.42
const ERASER_HALF_HEIGHT: float = 0.20
const DRAW_SENSITIVITY: float = 0.0045


@onready var player_body: CharacterBody3D = $Player/CharacterBody3D
@onready var camera: Camera3D = $Player/CharacterBody3D/Camera3D

@onready var board: StaticBody3D = $TestObjects/Blackboard
@onready var board_mesh: MeshInstance3D = $TestObjects/Blackboard/Mesh
@onready var board_question: Label3D = $TestObjects/Blackboard/Question

@onready var paper: StaticBody3D = $TestObjects/QuestionPaper
@onready var chalk: StaticBody3D = $TestObjects/Chalk

@onready var status_label: Label = $UI/Status
@onready var prompt_label: Label = $UI/Prompt
@onready var result_label: Label = $UI/Result

@onready var slot1_panel: Panel = $UI/Inventory/Slot1
@onready var slot2_panel: Panel = $UI/Inventory/Slot2

@onready var slot1_item: Label = $UI/Inventory/Slot1/Item
@onready var slot2_item: Label = $UI/Inventory/Slot2/Item

@onready var controls_label: Label = $UI/Controls


var inventory: Array = []
var selected_slot: int = -1

var question_active: bool = false
var question_text: String = "1 + 1 = ?"
var question_answer: String = "2"

var drawing: bool = false

var strokes: Array = []
var current_stroke: PackedVector2Array = PackedVector2Array()

var board_image: Image = null
var board_texture: ImageTexture = null
var writing_surface: MeshInstance3D = null

var recognizer: Object = null
var eraser_button: StaticBody3D = null
var eraser_dragging: bool = false
var brush_local_position: Vector3 = Vector3.ZERO
var brush_initialized: bool = false
var fresh_attempt_on_next_draw: bool = false

var cursor_layer: CanvasLayer = null
var cursor_root: Control = null
var cursor_h: ColorRect = null
var cursor_v: ColorRect = null
var cursor_dot: ColorRect = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_create_recognizer()
	_setup_board()
	_setup_eraser()
	_setup_crosshair()
	_update_inventory_ui()
	_update_eraser_visibility()

	_set_status("Ambil Kertas Soal dan Kapur.")
	_set_result("")

	controls_label.text = "Klik kiri: ambil/tulis | Klik kanan papan: tempel/koreksi | 1/2: pilih | P: buang | ESC: keluar"


func _process(_delta: float) -> void:
	_update_prompt()
	_update_crosshair()


func _input(event: InputEvent) -> void:

	if event is InputEventMouseMotion:

		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		if motion_event == null:
			return

		# Mouse tetap CAPTURED seperti mode FPS biasa. Karena Player.gd juga
		# menerima InputEventMouseMotion, POV tetap dapat diputar.
		# Saat menulis, titik pena mengikuti arah pandangan (tengah layar).
		if drawing:
			_add_board_point_from_relative(motion_event.relative)
			return

		# Saat penghapus dipegang, gerakan relatif mouse dipakai untuk
		# menggeser penghapus di permukaan papan. POV tetap menerima event yang sama.
		if eraser_dragging:
			_move_eraser_by_relative(motion_event.relative)
			return

		return


	if event is InputEventMouseButton:

		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event == null:
			return

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_handle_left_click()
			else:
				if eraser_dragging:
					_stop_eraser_drag()
				else:
					_stop_drawing()

			get_viewport().set_input_as_handled()
			return

		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_event.pressed:
				_handle_right_click()

			get_viewport().set_input_as_handled()
			return


	if event is InputEventKey:

		var key_event: InputEventKey = event as InputEventKey
		if key_event == null:
			return

		if not key_event.pressed:
			return

		if key_event.echo:
			return

		if key_event.keycode == KEY_1:
			_select_slot(0)
			get_viewport().set_input_as_handled()
			return

		if key_event.keycode == KEY_2:
			_select_slot(1)
			get_viewport().set_input_as_handled()
			return

		if key_event.keycode == KEY_P:
			_drop_selected()
			get_viewport().set_input_as_handled()
			return

		if key_event.keycode == KEY_ESCAPE:
			_exit_board_session()
			get_viewport().set_input_as_handled()
			return

func _handle_left_click() -> void:

	var viewport_size: Vector2 = (
		get_viewport()
		.get_visible_rect()
		.size
	)

	var center: Vector2 = (
		viewport_size * 0.5
	)


	var hit: Dictionary = (
		_raycast_from_screen(
			center
		)
	)


	if hit.is_empty():

		_set_status(
			"Tidak ada objek di depan."
		)

		return


	var collider_value: Variant = (
		hit.get(
			"collider"
		)
	)


	if not collider_value is Node3D:
		return


	var collider: Node3D = (
		collider_value as Node3D
	)


	if collider == null:
		return


	var interaction_value: Variant = (
		collider.get_meta(
			"interaction_type",
			""
		)
	)


	var interaction_type: String = (
		String(
			interaction_value
		)
	)


	if interaction_type == "item":

		_pick_item(
			collider
		)

		return


	if interaction_type == "eraser":

		_start_eraser_drag()

		return


	if interaction_type == "blackboard":

		if question_active:

			_start_drawing()

		else:

			_set_status(
				"Klik kanan untuk menempelkan soal."
			)

		return


	_set_status(
		"Objek ini belum memiliki interaksi."
	)


func _handle_right_click() -> void:

	var viewport_size: Vector2 = (
		get_viewport()
		.get_visible_rect()
		.size
	)

	var center: Vector2 = (
		viewport_size * 0.5
	)


	var hit: Dictionary = (
		_raycast_from_screen(
			center
		)
	)


	if hit.is_empty():

		_set_status(
			"Arahkan pandangan ke papan."
		)

		return


	var collider_value: Variant = (
		hit.get(
			"collider"
		)
	)


	if not collider_value is Node3D:
		return


	var collider: Node3D = (
		collider_value as Node3D
	)


	if collider == null:
		return


	if collider != board:

		_set_status(
			"Klik kanan harus mengenai papan."
		)

		return


	if question_active:

		_check_answer()

	else:

		_attach_question()


func _attach_question() -> void:

	if not inventory.has(
		"paper"
	):

		_set_status(
			"Bawa Kertas Soal terlebih dahulu."
		)

		return


	question_active = true
	fresh_attempt_on_next_draw = false


	_clear_answer_only()


	board_question.visible = true

	board_question.billboard = (
		BaseMaterial3D.BILLBOARD_DISABLED
	)

	board_question.text = (
		question_text
	)

	board_question.position = Vector3(
		0.0,
		0.90,
		0.095
	)

	board_question.rotation = Vector3.ZERO


	_update_eraser_visibility()

	_set_result("")


	_set_status(
		"Soal ditempel. " +
		"Tahan klik kiri untuk menulis."
	)


func _start_drawing() -> void:

	if not question_active:
		return


	if not inventory.has(
		"chalk"
	):

		_set_status(
			"Kamu membutuhkan Kapur."
		)

		return


	if drawing:
		return


	# Setelah percobaan sebelumnya dinyatakan "tidak terbaca",
	# klik kiri berikutnya memulai jawaban baru agar coretan percobaan lama
	# tidak terus menumpuk di recognizer. Untuk stroke tambahan pada satu
	# jawaban, tidak ada reset selama belum dikoreksi.
	if fresh_attempt_on_next_draw:
		_clear_answer_only()
		fresh_attempt_on_next_draw = false

	drawing = true


	current_stroke = (
		PackedVector2Array()
	)


	# Tetap CAPTURED seperti mode FPS normal. Jangan memakai posisi mouse
	# absolut karena Godot memindahkan cursor ke posisi virtual saat capture.
	# Titik pena mengikuti ray tepat di tengah layar.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Titik awal diambil dari pusat pandangan, lalu setelah itu posisi
	# pena dikendalikan oleh gerakan relatif mouse. Kamera tetap boleh
	# berputar karena event mouse tidak di-handle oleh script ini.
	if not _initialize_brush_from_center():
		drawing = false
		_set_status(
			"Arahkan pandangan ke papan untuk mulai menulis."
		)
		return

	_set_status(
		"Menulis... " +
		"Gerakkan mouse untuk menggerakkan POV " +
		"dan menulis pada papan."
	)


func _stop_drawing() -> void:

	if not drawing:
		return


	drawing = false


	if current_stroke.size() >= 2:

		strokes.append(
			current_stroke
		)


	current_stroke = (
		PackedVector2Array()
	)

	brush_initialized = false


	# Setelah selesai menulis, kembali ke mode FPS normal.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


	_set_status(
		"Stroke tersimpan. " +
		"Tahan klik kiri lagi untuk melanjutkan."
	)


func _check_answer() -> void:

	if drawing:

		_stop_drawing()


	if strokes.is_empty():

		_set_result(
			"BELUM ADA JAWABAN",
			Color(
				1.0,
				0.8,
				0.3,
				1.0
			)
		)


		_set_status(
			"Tulis jawaban terlebih dahulu."
		)


		return


	if recognizer == null:

		_set_result(
			"RECOGNIZER ERROR",
			Color(
				1.0,
				0.3,
				0.3,
				1.0
			)
		)


		_set_status(
			"DigitRecognizer.gd tidak dapat dimuat."
		)


		return


	var result_value: Variant = (
		recognizer.call(
			"recognize_against_answer",
			strokes,
			question_answer
		)
	)


	if not result_value is Dictionary:

		_set_result(
			"RECOGNIZER ERROR",
			Color(
				1.0,
				0.3,
				0.3,
				1.0
			)
		)

		return


	var result: Dictionary = (
		result_value as Dictionary
	)


	var readable_value: Variant = (
		result.get(
			"ok",
			false
		)
	)


	var text_value: Variant = (
		result.get(
			"text",
			""
		)
	)


	var score_value: Variant = (
		result.get(
			"score",
			0.0
		)
	)


	var readable: bool = (
		bool(
			readable_value
		)
	)


	var answer_text: String = (
		String(
			text_value
		)
	)


	var confidence: float = (
		float(
			score_value
		)
	)


	if not readable and answer_text.is_empty():

		_set_result(
			"TIDAK TERBACA",
			Color(
				1.0,
				0.8,
				0.3,
				1.0
			)
		)


		fresh_attempt_on_next_draw = true

		_set_status(
			"Jawaban tidak cukup yakin. " +
			"Gunakan penghapus papan atau klik kiri untuk memulai ulang."
		)


		return


	var confidence_text: String = (
		str(
			round(
				confidence * 100.0
			)
		)
	)


	if answer_text == question_answer:

		_set_result(
			"BENAR  "
			+
			answer_text,
			Color(
				0.4,
				1.0,
				0.55,
				1.0
			)
		)


		_set_status(
			"Jawaban benar."
		)

	else:

		_set_result(
			"SALAH  "
			+
			answer_text,
			Color(
				1.0,
				0.35,
				0.35,
				1.0
			)
		)


		_set_status(
			"Jawaban salah. "
			+
			"Confidence: "
			+
			confidence_text
			+
			"%"
		)


	board_question.text = (
		question_text
		+
		"\n\nJawaban: "
		+
		answer_text
	)


	_consume_item(
		"paper"
	)


	_consume_item(
		"chalk"
	)


	_update_inventory_ui()


	question_active = false


	_update_eraser_visibility()


func _erase_answer() -> void:

	fresh_attempt_on_next_draw = false

	if not question_active:

		_set_status(
			"Tidak ada soal aktif."
		)

		return


	if drawing:

		_stop_drawing()


	strokes.clear()


	current_stroke = (
		PackedVector2Array()
	)


	if board_image != null:

		board_image.fill(
			Color(
				0.0,
				0.0,
				0.0,
				0.0
			)
		)


	if board_texture != null:

		board_texture.update(
			board_image
		)


	_set_result("")


	_set_status(
		"Jawaban dihapus. " +
		"Soal tetap berada di papan."
	)


func _clear_answer_only() -> void:

	strokes.clear()


	current_stroke = (
		PackedVector2Array()
	)


	if board_image != null:

		board_image.fill(
			Color(
				0.0,
				0.0,
				0.0,
				0.0
			)
		)


	if board_texture != null:

		board_texture.update(
			board_image
		)


func _exit_board_session() -> void:

	if eraser_dragging:
		_stop_eraser_drag()

	if drawing:

		_stop_drawing()


	if not question_active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return


	question_active = false


	_clear_answer_only()


	board_question.visible = false


	_update_eraser_visibility()


	_set_result("")


	_set_status(
		"Keluar dari papan."
	)


func _initialize_brush_from_center() -> bool:

	var viewport_size: Vector2 = (
		get_viewport()
		.get_visible_rect()
		.size
	)

	var center: Vector2 = (
		viewport_size * 0.5
	)

	var hit: Dictionary = (
		_raycast_from_screen(
			center
		)
	)

	if hit.is_empty():
		return false

	var collider_value: Variant = (
		hit.get(
			"collider"
		)
	)

	if not collider_value is Node3D:
		return false

	var collider: Node3D = (
		collider_value as Node3D
	)

	if collider == null or collider != board:
		return false

	var position_value: Variant = (
		hit.get(
			"position"
		)
	)

	if not position_value is Vector3:
		return false

	var world_position: Vector3 = (
		position_value as Vector3
	)

	brush_local_position = (
		board.global_transform.affine_inverse()
		*
		world_position
	)

	var min_x: float = -BOARD_WIDTH * 0.5
	var max_x: float = BOARD_WIDTH * 0.5
	var min_y: float = -BOARD_HEIGHT * 0.5
	var max_y: float = BOARD_HEIGHT * 0.5

	brush_local_position.x = clampf(
		brush_local_position.x,
		min_x,
		max_x
	)

	brush_local_position.y = clampf(
		brush_local_position.y,
		min_y,
		max_y
	)

	brush_local_position.z = WRITING_OFFSET
	brush_initialized = true

	_add_board_point_from_local(
		brush_local_position
	)

	return true


func _add_board_point_from_relative(relative_motion: Vector2) -> void:

	if not brush_initialized:
		return

	brush_local_position.x += (
		relative_motion.x * DRAW_SENSITIVITY
	)

	brush_local_position.y -= (
		relative_motion.y * DRAW_SENSITIVITY
	)

	brush_local_position.x = clampf(
		brush_local_position.x,
		-BOARD_WIDTH * 0.5,
		BOARD_WIDTH * 0.5
	)

	brush_local_position.y = clampf(
		brush_local_position.y,
		-BOARD_HEIGHT * 0.5,
		BOARD_HEIGHT * 0.5
	)

	_add_board_point_from_local(
		brush_local_position
	)


func _add_board_point_from_center() -> void:

	_initialize_brush_from_center()


func _add_board_point_from_screen(screen_position: Vector2) -> void:

	var hit: Dictionary = (
		_raycast_from_screen(
			screen_position
		)
	)

	if hit.is_empty():
		return

	var collider_value: Variant = (
		hit.get(
			"collider"
		)
	)

	if not collider_value is Node3D:
		return

	var collider: Node3D = (
		collider_value as Node3D
	)

	if collider == null or collider != board:
		return

	var position_value: Variant = (
		hit.get(
			"position"
		)
	)

	if not position_value is Vector3:
		return

	var world_position: Vector3 = (
		position_value as Vector3
	)

	var local_position: Vector3 = (
		board.global_transform.affine_inverse()
		*
		world_position
	)

	_add_board_point_from_local(
		local_position
	)


func _add_board_point_from_local(local_position: Vector3) -> void:

	if absf(local_position.x) > BOARD_WIDTH * 0.5:
		return

	if absf(local_position.y) > BOARD_HEIGHT * 0.5:
		return

	var px: float = (
		(local_position.x / BOARD_WIDTH) + 0.5
	) * float(IMAGE_WIDTH - 1)

	var py: float = (
		0.5 - (local_position.y / BOARD_HEIGHT)
	) * float(IMAGE_HEIGHT - 1)

	var board_point: Vector2 = Vector2(
		px,
		py
	)

	if current_stroke.is_empty():

		current_stroke.append(
			board_point
		)

		_draw_dot(board_point)

		return

	var last_point: Vector2 = (
		current_stroke[
			current_stroke.size() - 1
		]
	)

	if last_point.distance_to(board_point) >= 1.0:

		current_stroke.append(
			board_point
		)

		_draw_line(
			last_point,
			board_point
		)


func _pick_item(
	target: Node3D
) -> void:

	if inventory.size() >= MAX_SLOTS:

		_set_status(
			"Inventory penuh. " +
			"Tekan P untuk membuang item."
		)

		return


	var item_value: Variant = (
		target.get_meta(
			"item_type",
			""
		)
	)


	var item_type: String = (
		String(
			item_value
		)
	)


	if item_type.is_empty():
		return


	if inventory.has(
		item_type
	):

		_set_status(
			"Kamu sudah membawa "
			+
			_item_name(
				item_type
			)
			+
			"."
		)

		return


	inventory.append(
		item_type
	)


	if selected_slot < 0:

		selected_slot = 0


	target.visible = false


	var collision: CollisionShape3D = (
		target.get_node_or_null(
			"CollisionShape3D"
		)
		as CollisionShape3D
	)


	if collision != null:

		collision.disabled = true


	_update_inventory_ui()


	_set_status(
		"Mengambil "
		+
		_item_name(
			item_type
		)
		+
		"."
	)


func _drop_selected() -> void:

	if question_active:

		_set_status(
			"Jangan membuang item saat berada " +
			"di papan."
		)

		return


	if selected_slot < 0:

		_set_status(
			"Tidak ada item yang dipilih."
		)

		return


	if selected_slot >= inventory.size():

		_set_status(
			"Slot kosong."
		)

		return


	var item_type: String = (
		String(
			inventory[
				selected_slot
			]
		)
	)


	var target: Node3D = null


	if item_type == "paper":

		target = paper

	elif item_type == "chalk":

		target = chalk


	if target == null:

		_set_status(
			"Objek item tidak ditemukan."
		)

		return


	inventory.remove_at(
		selected_slot
	)


	var forward: Vector3 = (
		-player_body
		.global_transform
		.basis.z
	)


	target.visible = true


	target.global_position = (
		player_body.global_position
		+
		forward * 1.5
		+
		Vector3.UP * 0.2
	)


	var collision: CollisionShape3D = (
		target.get_node_or_null(
			"CollisionShape3D"
		)
		as CollisionShape3D
	)


	if collision != null:

		collision.disabled = false


	_select_valid_slot()


	_update_inventory_ui()


	_set_status(
		"Membuang "
		+
		_item_name(
			item_type
		)
		+
		"."
	)


func _select_slot(
	index: int
) -> void:

	if (
		index < 0
		or
		index >= inventory.size()
	):

		_set_status(
			"Slot "
			+
			str(
				index + 1
			)
			+
			" kosong."
		)

		return


	selected_slot = index


	_update_inventory_ui()


	_set_status(
		"Dipilih: "
		+
		_item_name(
			String(
				inventory[
					index
				]
			)
		)
	)


func _select_valid_slot() -> void:

	if inventory.is_empty():

		selected_slot = -1

		return


	if selected_slot >= inventory.size():

		selected_slot = (
			inventory.size() - 1
		)


func _consume_item(
	item_type: String
) -> void:

	var index: int = (
		inventory.find(
			item_type
		)
	)


	if index < 0:
		return


	inventory.remove_at(
		index
	)


	if index == selected_slot:

		_select_valid_slot()

	elif index < selected_slot:

		selected_slot -= 1


func _item_name(
	item_type: String
) -> String:

	if item_type == "paper":

		return "Kertas Soal"


	if item_type == "chalk":

		return "Kapur"


	if item_type == "medkit":

		return "Medkit"


	return item_type


func _update_inventory_ui() -> void:

	slot1_item.text = (
		_slot_text(
			0
		)
	)


	slot2_item.text = (
		_slot_text(
			1
		)
	)


	if selected_slot == 0:

		slot1_panel.modulate = Color(
			1.0,
			1.0,
			0.65,
			1.0
		)

	else:

		slot1_panel.modulate = Color.WHITE


	if selected_slot == 1:

		slot2_panel.modulate = Color(
			1.0,
			1.0,
			0.65,
			1.0
		)

	else:

		slot2_panel.modulate = Color.WHITE


func _slot_text(
	index: int
) -> String:

	if index >= inventory.size():

		return (
			str(
				index + 1
			)
			+
			"\n—"
		)


	return (
		str(
			index + 1
		)
		+
		"\n"
		+
		_item_name(
			String(
				inventory[
					index
				]
			)
		)
	)


func _setup_board() -> void:

	# Pastikan collider papan selalu dikenali sebagai papan interaktif.
	board.set_meta("interaction_type", "blackboard")
	paper.set_meta("interaction_type", "item")
	paper.set_meta("item_type", "paper")
	chalk.set_meta("interaction_type", "item")
	chalk.set_meta("item_type", "chalk")

	var board_material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)


	board_material.albedo_color = Color(
		0.04,
		0.14,
		0.075,
		1.0
	)


	board_material.roughness = 0.92


	board_mesh.material_override = (
		board_material
	)


	board_question.billboard = (
		BaseMaterial3D.BILLBOARD_DISABLED
	)


	board_question.visible = false


	board_image = Image.create(
		IMAGE_WIDTH,
		IMAGE_HEIGHT,
		false,
		Image.FORMAT_RGBA8
	)


	board_image.fill(
		Color(
			0.0,
			0.0,
			0.0,
			0.0
		)
	)


	board_texture = (
		ImageTexture.create_from_image(
			board_image
		)
	)


	var writing_material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)


	writing_material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)


	writing_material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA
	)


	writing_material.albedo_texture = (
		board_texture
	)


	writing_material.cull_mode = (
		BaseMaterial3D.CULL_DISABLED
	)


	var quad: QuadMesh = (
		QuadMesh.new()
	)


	quad.size = Vector2(
		BOARD_WIDTH - 0.12,
		BOARD_HEIGHT - 0.12
	)


	writing_surface = (
		MeshInstance3D.new()
	)


	writing_surface.name = (
		"WritingSurface"
	)


	writing_surface.mesh = quad


	writing_surface.material_override = (
		writing_material
	)


	writing_surface.position = Vector3(
		0.0,
		0.0,
		WRITING_OFFSET
	)


	board.add_child(
		writing_surface
	)


# ============================================================
# PENGHAPUS PAPAN FISIK
# ============================================================

func _setup_eraser() -> void:

	eraser_button = (
		StaticBody3D.new()
	)


	eraser_button.name = (
		"BoardEraser"
	)


	eraser_button.collision_layer = 1
	eraser_button.collision_mask = 0


	eraser_button.set_meta(
		"interaction_type",
		"eraser"
	)


	board.add_child(
		eraser_button
	)


	# Posisi penghapus:
	# pojok kanan atas papan.
	eraser_button.position = Vector3(
		2.12,
		1.26,
		0.28
	)


	# --------------------------------------------------------
	# Badan penghapus
	# --------------------------------------------------------

	var body_mesh: MeshInstance3D = (
		MeshInstance3D.new()
	)


	body_mesh.name = (
		"EraserBody"
	)


	var body_box: BoxMesh = (
		BoxMesh.new()
	)


	body_box.size = Vector3(
		0.78,
		0.28,
		0.38
	)


	var body_material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)


	body_material.albedo_color = Color(
		0.88,
		0.88,
		0.82,
		1.0
	)


	body_material.roughness = 0.90


	body_box.material = (
		body_material
	)


	body_mesh.mesh = (
		body_box
	)


	eraser_button.add_child(
		body_mesh
	)


	# --------------------------------------------------------
	# Bagian felt bawah penghapus
	# --------------------------------------------------------

	var felt_mesh: MeshInstance3D = (
		MeshInstance3D.new()
	)


	felt_mesh.name = (
		"EraserFelt"
	)


	var felt_box: BoxMesh = (
		BoxMesh.new()
	)


	felt_box.size = Vector3(
		0.70,
		0.07,
		0.30
	)


	var felt_material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)


	felt_material.albedo_color = Color(
		0.12,
		0.12,
		0.10,
		1.0
	)


	felt_material.roughness = 1.0


	felt_box.material = (
		felt_material
	)


	felt_mesh.mesh = (
		felt_box
	)


	felt_mesh.position = Vector3(
		0.0,
		0.0,
		-0.20
	)


	eraser_button.add_child(
		felt_mesh
	)


	# --------------------------------------------------------
	# Collision penghapus
	# --------------------------------------------------------

	var collision: CollisionShape3D = (
		CollisionShape3D.new()
	)


	collision.name = (
		"CollisionShape3D"
	)


	var shape: BoxShape3D = (
		BoxShape3D.new()
	)


	shape.size = Vector3(
		0.82,
		0.36,
		0.42
	)


	collision.shape = (
		shape
	)


	eraser_button.add_child(
		collision
	)


func _start_eraser_drag() -> void:

	if not question_active:
		return

	if drawing:
		_stop_drawing()

	eraser_dragging = true

	# Tetap CAPTURED agar Player.gd terus menerima gerakan mouse untuk POV.
	# Gerakan relatif mouse di sini juga dipakai untuk menggeser penghapus.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_set_status(
		"Penghapus dipegang. " +
		"Tahan klik kiri lalu geser mouse di papan."
	)


func _stop_eraser_drag() -> void:

	if not eraser_dragging:
		return

	eraser_dragging = false

	# Kembali ke mode FPS setelah penghapus dilepas.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_set_status(
		"Penghapus dilepas. " +
		"Tahan klik kiri lagi untuk menggesernya."
	)


func _move_eraser_by_relative(relative_motion: Vector2) -> void:

	if eraser_button == null:
		return

	if not question_active:
		return

	# Papan menggunakan sumbu X untuk kiri/kanan dan Y untuk atas/bawah.
	# Mouse Y bertambah saat bergerak ke bawah, sedangkan koordinat papan Y
	# bertambah ke atas, jadi tandanya dibalik.
	eraser_button.position.x += relative_motion.x * ERASER_DRAG_SENSITIVITY
	eraser_button.position.y -= relative_motion.y * ERASER_DRAG_SENSITIVITY

	var min_x: float = -BOARD_WIDTH * 0.5 + ERASER_HALF_WIDTH
	var max_x: float = BOARD_WIDTH * 0.5 - ERASER_HALF_WIDTH
	var min_y: float = -BOARD_HEIGHT * 0.5 + ERASER_HALF_HEIGHT
	var max_y: float = BOARD_HEIGHT * 0.5 - ERASER_HALF_HEIGHT

	eraser_button.position.x = clampf(eraser_button.position.x, min_x, max_x)
	eraser_button.position.y = clampf(eraser_button.position.y, min_y, max_y)
	eraser_button.position.z = 0.28

	_erase_under_eraser()

func _erase_under_eraser() -> void:

	if board_image == null:
		return

	if board_texture == null:
		return

	var local_position: Vector3 = eraser_button.position

	var center_x: int = int(
		round(
			(local_position.x / BOARD_WIDTH + 0.5) * float(IMAGE_WIDTH - 1)
		)
	)

	var center_y: int = int(
		round(
			(0.5 - local_position.y / BOARD_HEIGHT) * float(IMAGE_HEIGHT - 1)
		)
	)

	var half_width_px: int = int(
		round(
			(ERASER_HALF_WIDTH / BOARD_WIDTH) * float(IMAGE_WIDTH)
		)
	)

	var half_height_px: int = int(
		round(
			(ERASER_HALF_HEIGHT / BOARD_HEIGHT) * float(IMAGE_HEIGHT)
		)
	)

	var start_x: int = maxi(0, center_x - half_width_px)
	var end_x: int = mini(IMAGE_WIDTH - 1, center_x + half_width_px)
	var start_y: int = maxi(0, center_y - half_height_px)
	var end_y: int = mini(IMAGE_HEIGHT - 1, center_y + half_height_px)

	for y in range(start_y, end_y + 1):
		for x in range(start_x, end_x + 1):
			board_image.set_pixel(
				x,
				y,
				Color(0.0, 0.0, 0.0, 0.0)
			)

	board_texture.update(board_image)
	_filter_strokes_by_eraser()


func _filter_strokes_by_eraser() -> void:

	if strokes.is_empty():
		return

	var center: Vector2 = Vector2(
		local_position_to_image_x(eraser_button.position.x),
		local_position_to_image_y(eraser_button.position.y)
	)

	var half_width: float = (ERASER_HALF_WIDTH / BOARD_WIDTH) * float(IMAGE_WIDTH)
	var half_height: float = (ERASER_HALF_HEIGHT / BOARD_HEIGHT) * float(IMAGE_HEIGHT)

	var filtered_strokes: Array = []

	for stroke_value in strokes:
		if not stroke_value is PackedVector2Array:
			continue

		var stroke: PackedVector2Array = stroke_value as PackedVector2Array
		var filtered: PackedVector2Array = PackedVector2Array()

		for point in stroke:
			if absf(point.x - center.x) > half_width or absf(point.y - center.y) > half_height:
				filtered.append(point)

		if filtered.size() >= 2:
			filtered_strokes.append(filtered)

	strokes = filtered_strokes


func local_position_to_image_x(local_x: float) -> float:
	return (local_x / BOARD_WIDTH + 0.5) * float(IMAGE_WIDTH - 1)


func local_position_to_image_y(local_y: float) -> float:
	return (0.5 - local_y / BOARD_HEIGHT) * float(IMAGE_HEIGHT - 1)


func _update_eraser_visibility() -> void:

	if eraser_button == null:
		return


	eraser_button.visible = (
		question_active
	)


func _draw_dot(
	point: Vector2
) -> void:

	_draw_circle(
		point,
		BRUSH_RADIUS
	)


	if board_texture != null:

		board_texture.update(
			board_image
		)


func _draw_line(
	start_point: Vector2,
	end_point: Vector2
) -> void:

	var distance: float = (
		start_point.distance_to(
			end_point
		)
	)


	var steps: int = maxi(
		1,
		int(
			ceil(
				distance
				/
				3.0
			)
		)
	)


	for i in range(
		steps + 1
	):

		var t: float = (
			float(i)
			/
			float(steps)
		)


		var point: Vector2 = (
			start_point.lerp(
				end_point,
				t
			)
		)


		_draw_circle(
			point,
			BRUSH_RADIUS
		)


	if board_texture != null:

		board_texture.update(
			board_image
		)


func _draw_circle(
	point: Vector2,
	radius: int
) -> void:

	var center_x: int = int(
		round(
			point.x
		)
	)


	var center_y: int = int(
		round(
			point.y
		)
	)


	for y_offset in range(
		-radius,
		radius + 1
	):

		for x_offset in range(
			-radius,
			radius + 1
		):

			if (
				x_offset * x_offset
				+
				y_offset * y_offset
				>
				radius * radius
			):

				continue


			var pixel_x: int = (
				center_x
				+
				x_offset
			)


			var pixel_y: int = (
				center_y
				+
				y_offset
			)


			if (
				pixel_x < 0
				or
				pixel_x >= IMAGE_WIDTH
			):

				continue


			if (
				pixel_y < 0
				or
				pixel_y >= IMAGE_HEIGHT
			):

				continue


			board_image.set_pixel(
				pixel_x,
				pixel_y,
				Color(
					0.98,
					0.98,
					0.94,
					1.0
				)
			)


func _raycast_from_screen(
	screen_position: Vector2
) -> Dictionary:

	var origin: Vector3 = (
		camera.project_ray_origin(
			screen_position
		)
	)


	var direction: Vector3 = (
		camera.project_ray_normal(
			screen_position
		)
	)


	var end_point: Vector3 = (
		origin
		+
		direction
		*
		INTERACT_DISTANCE
	)


	var query: PhysicsRayQueryParameters3D = (
		PhysicsRayQueryParameters3D.create(
			origin,
			end_point
		)
	)


	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false


	var result: Dictionary = (
		get_world_3d()
		.direct_space_state
		.intersect_ray(
			query
		)
	)


	return result


func _raycast_board_from_screen(screen_position: Vector2) -> Dictionary:

	var origin: Vector3 = (
		camera.project_ray_origin(
			screen_position
		)
	)

	var direction: Vector3 = (
		camera.project_ray_normal(
			screen_position
		)
	)

	var end_point: Vector3 = (
		origin
		+
		direction
		*
		INTERACT_DISTANCE
	)

	var query: PhysicsRayQueryParameters3D = (
		PhysicsRayQueryParameters3D.create(
			origin,
			end_point
		)
	)

	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false

	# Saat drag berlangsung, jangan biarkan penghapus atau player
	# memblokir ray ke papan.
	query.exclude = [
		eraser_button.get_rid(),
		player_body.get_rid()
	]

	var result: Dictionary = (
		get_world_3d()
		.direct_space_state
		.intersect_ray(
			query
		)
	)

	if result.is_empty():
		return {}

	var collider_value: Variant = result.get("collider")
	if not collider_value is Node3D:
		return {}

	var collider: Node3D = collider_value as Node3D
	if collider != board:
		return {}

	return result


func _update_prompt() -> void:

	if drawing:

		prompt_label.text = (
			"MENULIS — tahan klik kiri dan gerakkan POV dengan mouse"
		)

		return

	if eraser_dragging:

		prompt_label.text = (
			"MENGHAPUS — tahan klik kiri dan geser penghapus"
		)

		return


	var viewport_size: Vector2 = (
		get_viewport()
		.get_visible_rect()
		.size
	)


	var center: Vector2 = (
		viewport_size * 0.5
	)


	var hit: Dictionary = (
		_raycast_from_screen(
			center
		)
	)


	if hit.is_empty():

		prompt_label.text = ""

		return


	var collider_value: Variant = (
		hit.get(
			"collider"
		)
	)


	if not collider_value is Node3D:

		prompt_label.text = ""

		return


	var collider: Node3D = (
		collider_value as Node3D
	)


	if collider == null:

		prompt_label.text = ""

		return


	var interaction_value: Variant = (
		collider.get_meta(
			"interaction_type",
			""
		)
	)


	var interaction_type: String = (
		String(
			interaction_value
		)
	)


	if interaction_type == "item":

		var item_value: Variant = (
			collider.get_meta(
				"item_type",
				""
			)
		)


		var item_type: String = (
			String(
				item_value
			)
		)


		prompt_label.text = (
			"KLIK KIRI — Ambil "
			+
			_item_name(
				item_type
			)
		)


	elif interaction_type == "blackboard":

		if question_active:

			prompt_label.text = (
				"TAHAN KLIK KIRI — Tulis | " +
				"KLIK KANAN — Koreksi"
			)

		else:

			prompt_label.text = (
				"KLIK KANAN — Tempel Soal"
			)


	elif interaction_type == "eraser":

		prompt_label.text = (
			"TAHAN KLIK KIRI — Geser Penghapus"
		)


	else:

		prompt_label.text = ""


func _set_status(
	text_value: String
) -> void:

	status_label.text = (
		text_value
	)


func _set_result(
	text_value: String,
	color_value: Color = Color.WHITE
) -> void:

	result_label.text = (
		text_value
	)

	result_label.modulate = (
		color_value
	)


func _create_recognizer() -> void:

	var recognizer_script: Script = (
		load(
			"res://DigitRecognizer.gd"
		)
		as Script
	)


	if recognizer_script == null:

		push_error(
			"DigitRecognizer.gd tidak dapat dimuat."
		)

		return


	recognizer = (
		recognizer_script.new()
	)


func _setup_crosshair() -> void:

	cursor_layer = (
		CanvasLayer.new()
	)


	cursor_layer.name = (
		"CrosshairLayer"
	)


	add_child(
		cursor_layer
	)


	cursor_root = (
		Control.new()
	)


	cursor_root.name = (
		"Crosshair"
	)


	cursor_root.size = Vector2(
		26.0,
		26.0
	)


	cursor_root.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	cursor_layer.add_child(
		cursor_root
	)


	cursor_h = (
		ColorRect.new()
	)


	cursor_h.position = Vector2(
		3.0,
		12.0
	)


	cursor_h.size = Vector2(
		20.0,
		2.0
	)


	cursor_h.color = Color(
		1.0,
		1.0,
		1.0,
		0.9
	)


	cursor_h.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	cursor_root.add_child(
		cursor_h
	)


	cursor_v = (
		ColorRect.new()
	)


	cursor_v.position = Vector2(
		12.0,
		3.0
	)


	cursor_v.size = Vector2(
		2.0,
		20.0
	)


	cursor_v.color = Color(
		1.0,
		1.0,
		1.0,
		0.9
	)


	cursor_v.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	cursor_root.add_child(
		cursor_v
	)


	cursor_dot = (
		ColorRect.new()
	)


	cursor_dot.position = Vector2(
		11.0,
		11.0
	)


	cursor_dot.size = Vector2(
		4.0,
		4.0
	)


	cursor_dot.color = Color.WHITE


	cursor_dot.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	cursor_root.add_child(
		cursor_dot
	)


func _update_crosshair() -> void:

	if cursor_root == null:
		return

	# Saat menulis/menghapus, mouse asli terlihat. Crosshair FPS tidak perlu
	# berada di tengah karena titik interaksi mengikuti cursor tersebut.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		cursor_root.visible = false
		return

	cursor_root.visible = true


	var viewport_size: Vector2 = (
		get_viewport()
		.get_visible_rect()
		.size
	)


	var center: Vector2 = (
		viewport_size * 0.5
	)


	cursor_root.position = (
		center
		-
		Vector2(
			13.0,
			13.0
		)
	)


	var hit: Dictionary = (
		_raycast_from_screen(
			center
		)
	)


	var cursor_color: Color = Color(
		1.0,
		1.0,
		1.0,
		0.9
	)


	if drawing:

		cursor_color = Color(
			1.0,
			0.85,
			0.30,
			1.0
		)


	elif not hit.is_empty():

		var collider_value: Variant = (
			hit.get(
				"collider"
			)
		)


		if collider_value is Node3D:

			var collider: Node3D = (
				collider_value as Node3D
			)


			if collider != null:

				var interaction_value: Variant = (
					collider.get_meta(
						"interaction_type",
						""
					)
				)


				var interaction_type: String = (
					String(
						interaction_value
					)
				)


				if interaction_type == "item":

					cursor_color = Color(
						0.50,
						1.0,
						0.60,
						1.0
					)


				elif interaction_type == "blackboard":

					cursor_color = Color(
						0.50,
						1.0,
						0.60,
						1.0
					)


				elif interaction_type == "eraser":

					cursor_color = Color(
						0.50,
						1.0,
						0.60,
						1.0
					)


	cursor_h.color = (
		cursor_color
	)

	cursor_v.color = (
		cursor_color
	)

	cursor_dot.color = (
		cursor_color
	)
