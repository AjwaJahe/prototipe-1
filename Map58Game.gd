extends Node

## Otak utama gameplay Map58.
## Tidak mengubah posisi/rotasi map atau furniture.
## Sistem yang dikelola:
## - ujian pembuka 5 soal
## - transisi guru -> hantu
## - objective 10 kertas soal
## - maksimal 5 kertas aktif
## - soal semakin sulit
## - waktu mengerjakan di papan: 2 menit
## - jawaban benar: guru tenang 3 menit
## - jawaban salah: mode bersek 15 detik
## - selesai 10 soal: gerbang sekolah terbuka
## - penalti tertangkap: 5 soal untuk keluar
## - KO/revive memakai medkit
##
## Catatan dari proposal:
## proposal tidak menetapkan warna kunci -> ruangan secara eksplisit.
## Karena itu GameManager tidak menebak pasangan warna/ruangan tersebut.


signal phase_changed(phase: String)
signal objective_changed(solved: int, target: int)
signal paper_respawn_requested()
signal teacher_mode_changed(mode: String, target: Node)
signal player_knocked_out(player: Node)
signal player_revived(player: Node)
signal game_finished()
signal board_answer_result(correct: bool, message: String)


const PHASE_INTRO_BRIEFING := "INTRO_BRIEFING"
const PHASE_INTRO_EXAM := "INTRO_EXAM"
const PHASE_TRANSITION := "TRANSITION"
const PHASE_HUNT := "HUNT"
const PHASE_BOARD_SOLVING := "BOARD_SOLVING"
const PHASE_PENALTY_EXAM := "PENALTY_EXAM"
const PHASE_KO := "KO"
const PHASE_ESCAPE_READY := "ESCAPE_READY"
const PHASE_FINISHED := "FINISHED"

const TEACHER := "teacher"
const GHOST := "ghost"
const BERSERK := "berserk"
const RESPONDING := "responding"

const TOTAL_PAPERS_TO_ESCAPE := 10
const MAX_ACTIVE_PAPERS := 5
const BOARD_TIME_LIMIT := 120.0
const BERSERK_TIME := 15.0
const CALM_TIME := 180.0
const INITIAL_TEACHER_MIN_TIME := 180.0
const INITIAL_TEACHER_MAX_TIME := 300.0
const INTRO_BRIEFING_TIME := 5.0
const INTRO_TIME := 20.0
const TRANSITION_TIME := 5.0
const INTRO_BLACKOUT_DELAY := 1.5
const PENALTY_QUESTIONS := 5
const INTRO_QUESTIONS := 5

@export var intro_level: String = "SD"
@export var board_level: String = "SMA"
@export var auto_start: bool = true
# MODE UJI: mulai langsung dari alur guru membuka pintu dan ending.
# Biarkan false untuk gameplay normal.
@export var debug_escape_test_mode: bool = false


var phase: String = PHASE_INTRO_EXAM
var teacher_mode: String = TEACHER

var score: int = 0
var solved_papers: int = 0
var initial_exam_correct: int = 0

var intro_question_index: int = 0
var penalty_question_index: int = 0
var current_question: Dictionary = {}
var intro_questions: Array[Dictionary] = []
var intro_answers: Array[String] = []
var intro_remaining: float = 0.0
var question_database: RefCounted

var intro_briefing_remaining: float = 0.0
var transition_remaining: float = 0.0
var intro_blackout_remaining: float = -1.0
var intro_departure_active := false
var _intro_camera_tracking_teacher := false
var _intro_teacher_tween: Tween
var _intro_teacher_start_position := Vector3.ZERO
var _intro_teacher_start_rotation := Vector3.ZERO
var hunt_remaining: float = 0.0
var initial_teacher_remaining: float = 0.0
var _ui_refresh_remaining: float = 0.0
var board_remaining: float = 0.0
var calm_remaining: float = 0.0
var berserk_remaining: float = 0.0
var mode_before_responding: String = GHOST
var mode_before_berserk: String = GHOST
# Mode aktif dan target mode bersek sebelum penangkapan.
var mode_before_capture: String = GHOST
var target_before_capture: Node = null

var active_paper_count: int = 0
var board_player: Node = null
var board_node: Node3D = null
var berserk_target: Node = null
var penalty_player: Node = null
# Penalti adalah status milik murid yang tertangkap, bukan fase global game.
var _penalty_exam_active: bool = false

var knockout_players: Array[Node] = []
var _capture_in_progress := false

var _status_label: Label
var _objective_label: Label
var _timer_label: Label
var _quiz_label: Label
var _answer_label: Label
var _intro_answer_edits: Array[LineEdit] = []
var _phase_label: Label
var _penalty_exam_canvas: CanvasLayer
var _penalty_question_label: Label
var _penalty_answer_label: Label
var _penalty_answer_input: LineEdit
var _intro_paper_canvas: CanvasLayer
var _intro_paper_panel: PanelContainer
var _intro_paper_open := false
var _intro_answers_submitted := false
var game_result: String = ""
var _room_question_level: String = ""
var _multiplayer_intro_initialized := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	# Mode room ditetapkan host sebelum scene gameplay dimuat dan diterima semua pemain.
	if bool(get_tree().get_meta("kelas_malam_multiplayer_active", false)):
		var requested_level := String(get_tree().get_meta("kelas_malam_mode", "SD"))
		if requested_level in ["SD", "SMP", "SMA", "Dasar"]:
			_room_question_level = requested_level
		else:
			_room_question_level = "SD"
		intro_level = _room_question_level
		board_level = _room_question_level
	_load_question_database()
	_build_ui()
	_refresh_active_paper_count()

	# Host menjadi otoritas timer/fase dalam multiplayer; klien tetap memproses UI.
	if _is_multiplayer_client():
		return
	if debug_escape_test_mode:
		call_deferred("_start_escape_test_scenario")
	elif auto_start:
		call_deferred("_start_game")


func _is_multiplayer_client() -> bool:
	if not bool(get_tree().get_meta("kelas_malam_multiplayer_active", false)):
		return false
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return false
	return not multiplayer.is_server()


func _start_escape_test_scenario() -> void:
	# Skenario khusus untuk mengecek ending tanpa mengerjakan soal.
	# Tidak mengubah jalur normal karena hanya berjalan jika export flag diaktifkan.
	solved_papers = TOTAL_PAPERS_TO_ESCAPE
	active_paper_count = 0
	_clear_board_state()
	_penalty_exam_active = false
	_capture_in_progress = false
	_finish_objective()


func _update_intro_camera_tracking(delta: float) -> void:
	if not _intro_camera_tracking_teacher:
		return
	var player := get_tree().get_first_node_in_group("players") as CharacterBody3D
	var teacher := get_node_or_null("../Teacher") as Node3D
	var camera := player.get_node_or_null("Camera3D") as Camera3D if player != null else null
	if player == null or teacher == null or camera == null:
		_intro_camera_tracking_teacher = false
		return

	# Ikuti posisi guru dengan rotasi halus; input mouse tetap terkunci selama intro.
	var direction := teacher.global_position + Vector3.UP * 0.35 - camera.global_position
	var horizontal := Vector2(direction.x, direction.z).length()
	if horizontal > 0.001:
		var target_yaw := atan2(-direction.x, -direction.z)
		var target_pitch := atan2(direction.y, horizontal)
		player.rotation.y = lerp_angle(player.rotation.y, target_yaw, clampf(delta * 4.5, 0.0, 1.0))
		camera.rotation.x = lerp_angle(camera.rotation.x, target_pitch, clampf(delta * 4.5, 0.0, 1.0))


func _process(delta: float) -> void:
	_update_intro_camera_tracking(delta)
	# Klien tidak menjalankan simulasi fase/timer lokal, tetapi HUD tetap diperbarui.
	if _is_multiplayer_client():
		_ui_refresh_remaining -= delta
		if _ui_refresh_remaining <= 0.0:
			_ui_refresh_remaining = 0.10
			_update_ui()
		return
	match phase:
		PHASE_INTRO_BRIEFING:
			intro_briefing_remaining -= delta
			if intro_briefing_remaining <= 0.0:
				_begin_intro_exam()
		PHASE_INTRO_EXAM:
			intro_remaining -= delta
			if intro_remaining <= 0.0:
				_finish_intro_exam()
		PHASE_TRANSITION:
			if intro_blackout_remaining >= 0.0:
				intro_blackout_remaining -= delta
				if intro_blackout_remaining <= 0.0:
					intro_blackout_remaining = -1.0
					_blackout_nearest_class_lights()
			# Cutscene mengatur sendiri akhir transisi; timer lama tidak boleh
			# memulai fase berburu sebelum animasi guru selesai.
		PHASE_HUNT:
			# Bersek mengambil alih timer utama; timer mode sebelumnya dibekukan.
			if berserk_remaining > 0.0 and teacher_mode == BERSERK:
				berserk_remaining = maxf(0.0, berserk_remaining - delta)
				if berserk_remaining <= 0.0:
					berserk_target = null
					if mode_before_berserk == TEACHER and initial_teacher_remaining <= 0.0 and calm_remaining <= 0.0:
						_start_ghost_mode()
					else:
						_set_teacher_mode(mode_before_berserk, null)
						_set_status("Mode Bersek berakhir. Guru kembali ke mode sebelumnya: " + mode_before_berserk + ".")
			elif initial_teacher_remaining > 0.0:
				initial_teacher_remaining = maxf(0.0, initial_teacher_remaining - delta)
				if initial_teacher_remaining <= 0.0:
					_start_ghost_mode()
			elif calm_remaining > 0.0:
				calm_remaining = maxf(0.0, calm_remaining - delta)
				if calm_remaining <= 0.0:
					_start_ghost_mode()
		PHASE_BOARD_SOLVING:
			board_remaining -= delta
			if board_remaining <= 0.0:
				_board_timeout()
		PHASE_PENALTY_EXAM:
			pass
		PHASE_KO:
			pass

	_ui_refresh_remaining -= delta
	if _ui_refresh_remaining <= 0.0:
		_ui_refresh_remaining = 0.10
		_update_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if _penalty_exam_active:
		if _handle_numeric_exam_input(key_event):
			get_viewport().set_input_as_handled()
		return

	match phase:
		PHASE_PENALTY_EXAM:
			if _handle_numeric_exam_input(key_event):
				get_viewport().set_input_as_handled()


func _start_game() -> void:
	score = 0
	solved_papers = 0
	initial_exam_correct = 0
	intro_question_index = 0
	penalty_question_index = 0
	board_player = null
	board_node = null
	berserk_target = null
	mode_before_responding = GHOST
	mode_before_berserk = GHOST
	knockout_players.clear()
	penalty_player = null
	_penalty_exam_active = false
	intro_questions.clear()
	intro_answers.clear()
	_intro_answers_submitted = false
	game_result = ""
	if question_database != null:
		question_database.reset_session()
	intro_briefing_remaining = INTRO_BRIEFING_TIME
	intro_remaining = INTRO_TIME

	_set_phase(PHASE_INTRO_BRIEFING)
	_set_teacher_mode(TEACHER, null)
	_set_intro_locked(true)
	_set_intro_pov_locked(false)
	_prepare_intro_desk()
	_position_teacher_for_intro()
	_prepare_intro_paper()
	_hide_intro_paper()
	_set_status("Perhatikan instruksi ujian...")
	_update_objective()


func apply_multiplayer_intro_state(state: Dictionary) -> void:
	if not _is_multiplayer_client():
		return
	var synced_phase := String(state.get("phase", phase))
	if synced_phase == PHASE_INTRO_BRIEFING:
		_set_intro_pov_locked(false)
	elif synced_phase in [PHASE_INTRO_EXAM, PHASE_TRANSITION]:
		_set_intro_pov_locked(true)
	if synced_phase in [PHASE_INTRO_BRIEFING, PHASE_INTRO_EXAM, PHASE_TRANSITION] and not _multiplayer_intro_initialized:
		_set_intro_locked(true)
		_prepare_intro_desk()
		intro_questions.clear()
		intro_answers.clear()
		var synced_questions: Array = state.get("intro_questions", [])
		for question_value in synced_questions:
			if question_value is Dictionary:
				intro_questions.append((question_value as Dictionary).duplicate(true))
				intro_answers.append("")
		_intro_answers_submitted = false
		if not intro_questions.is_empty():
			current_question = intro_questions[0]
		_update_intro_paper_visuals()
		_refresh_intro_paper_ui()
		_multiplayer_intro_initialized = true

	if synced_phase == PHASE_INTRO_EXAM and not intro_questions.is_empty():
		if not _intro_paper_open:
			open_intro_paper()
	elif synced_phase == PHASE_TRANSITION and _intro_paper_open:
		_hide_intro_paper()

func _begin_intro_exam() -> void:
	if phase != PHASE_INTRO_BRIEFING:
		return
	intro_remaining = INTRO_TIME
	_set_phase(PHASE_INTRO_EXAM)
	_set_intro_pov_locked(true)
	open_intro_paper()


func _load_question_database() -> void:
	var database_script := load("res://QuestionDatabase.gd") as Script
	if database_script == null:
		push_error("Map58Game: QuestionDatabase.gd tidak dapat dimuat.")
		return

	question_database = database_script.new() as RefCounted


func _position_teacher_for_intro() -> void:
	var teacher := get_node_or_null("../Teacher") as CharacterBody3D
	var class_teacher_spawn := get_node_or_null("../SpawnManager/ClassTeacherSpawn") as Node3D
	var teacher_room_spawn := get_node_or_null("../SpawnManager/TeacherSpawn") as Node3D
	if teacher == null or class_teacher_spawn == null or teacher_room_spawn == null:
		push_error("Map58Game: Teacher, ClassTeacherSpawn, atau TeacherSpawn tidak ditemukan; posisi/arah guru tidak diubah.")
		return
	teacher.global_position = class_teacher_spawn.global_position
	# Guru menghadap ke arah titik spawn ruang guru, bukan lagi ke papan Kelas 10 A.
	teacher.look_at(Vector3(teacher_room_spawn.global_position.x, teacher.global_position.y, teacher_room_spawn.global_position.z), Vector3.UP)
	_intro_teacher_start_position = teacher.global_position
	_intro_teacher_start_rotation = teacher.global_rotation


func _prepare_intro_desk() -> void:
	var player := get_node_or_null("../Player/CharacterBody3D") as CharacterBody3D
	if player == null:
		return

	var spawn_class := _find_player_spawn_class(player)
	if spawn_class == null:
		push_error("Map58Game: tidak menemukan kelas spawn player.")
		return

	var chair := _find_nearest_chair(spawn_class, player)
	if chair == null:
		push_error("Map58Game: tidak menemukan kursi di kelas spawn player.")
		return

	var desk := _find_nearest_desk(spawn_class, chair)
	if desk == null:
		push_error("Map58Game: tidak menemukan meja untuk kursi spawn player.")
		return

	player.global_position = chair.global_position + Vector3(0.0, 0.48, 0.0)
	player.rotation.y = chair.global_rotation.y
	player.set_meta("intro_sitting", true)
	player.set_meta("intro_locked", true)
	player.camera.position.y = 0.95

	_remove_all_intro_papers(get_tree().current_scene)

	var paper := StaticBody3D.new()
	paper.name = "IntroQuestionPaper"
	var pickup_script := load("res://items/PickupItem.gd") as Script
	if pickup_script != null:
		paper.set_script(pickup_script)
	desk.add_child(paper)

	var desk_top := _find_desk_top(desk)
	if desk_top != null:
		paper.global_position = desk_top.global_position + Vector3(0.0, 0.035, 0.0)
	else:
		paper.global_position = desk.global_position + Vector3(0.0, 1.055, 0.0)

	paper.set_meta("intro_paper", true)
	paper.set_meta("interaction_type", "item")
	paper.set_meta("item_type", "paper")
	paper.set_meta("display_name", "Kertas Soal")
	paper.set_meta("in_inventory", false)

	# Kertas fisik sederhana di atas meja. Soal dibaca melalui UI ujian,
	# bukan tekstur SubViewport 3D yang sebelumnya menghasilkan bidang ungu.
	var paper_mesh := MeshInstance3D.new()
	paper_mesh.name = "PaperMesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.52, 0.012, 0.68)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.96, 0.945, 0.88, 1.0)
	material.roughness = 0.94
	box.material = material
	paper_mesh.mesh = box
	paper_mesh.position.y = 0.006
	paper.add_child(paper_mesh)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.52, 0.012, 0.68)
	collision.shape = shape
	collision.position.y = 0.006
	paper.add_child(collision)

	var question_viewport := SubViewport.new()
	question_viewport.name = "QuestionPaperViewport"
	question_viewport.size = Vector2i(512, 680)
	question_viewport.transparent_bg = false
	question_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	paper.add_child(question_viewport)

	var page := Control.new()
	page.name = "QuestionPaperPage"
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	question_viewport.add_child(page)

	var page_background := ColorRect.new()
	page_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	page_background.color = Color(0.96, 0.945, 0.88, 1.0)
	page.add_child(page_background)

	var page_margin := MarginContainer.new()
	page_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	page_margin.add_theme_constant_override("margin_left", 28)
	page_margin.add_theme_constant_override("margin_right", 24)
	page_margin.add_theme_constant_override("margin_top", 24)
	page_margin.add_theme_constant_override("margin_bottom", 20)
	page.add_child(page_margin)

	var page_content := VBoxContainer.new()
	page_content.add_theme_constant_override("separation", 12)
	page_margin.add_child(page_content)

	var page_title := Label.new()
	page_title.name = "PaperTitle"
	page_title.text = "UJIAN PEMBUKA"
	page_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_title.add_theme_font_size_override("font_size", 27)
	page_content.add_child(page_title)

	var page_subtitle := Label.new()
	page_subtitle.text = "Nama: __________________\nKelas: __________   Waktu: 20 detik"
	page_subtitle.add_theme_font_size_override("font_size", 14)
	page_content.add_child(page_subtitle)

	var separator := HSeparator.new()
	page_content.add_child(separator)

	var questions_label := Label.new()
	questions_label.name = "IntroQuestions"
	questions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	questions_label.add_theme_font_size_override("font_size", 17)
	questions_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	questions_label.text = "Memuat soal..."
	page_content.add_child(questions_label)

	var page_footer := Label.new()
	page_footer.text = "Jawaban diisi melalui kolom jawaban pada layar."
	page_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_footer.add_theme_font_size_override("font_size", 12)
	page_content.add_child(page_footer)




func _find_player_spawn_class(player: Node3D) -> Node3D:
	if player == null:
		return null
	var marker_name := String(player.get_meta("intro_spawn_marker_name", ""))
	if marker_name.is_empty():
		return null
	if marker_name.to_upper().contains("12_D"):
		return null

	var furniture_name := marker_name + "_Furniture"
	return _find_first_node_named(get_tree().current_scene, furniture_name) as Node3D


func _find_nearest_chair(root: Node, target: Node3D) -> Node3D:
	if root == null or target == null:
		return null
	var best: Node3D = null
	var best_distance: float = INF
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Node3D and String(current.name).begins_with("Chair_"):
			var candidate: Node3D = current as Node3D
			var distance: float = candidate.global_position.distance_to(target.global_position)
			if distance < best_distance:
				best_distance = distance
				best = candidate
		for child in current.get_children():
			stack.append(child)
	return best


func _find_nearest_desk(root: Node, target: Node3D) -> Node3D:
	if root == null or target == null:
		return null
	var best: Node3D = null
	var best_distance: float = INF
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Node3D and String(current.name).begins_with("Desk_"):
			var candidate: Node3D = current as Node3D
			var distance: float = candidate.global_position.distance_to(target.global_position)
			if distance < best_distance:
				best_distance = distance
				best = candidate
		for child in current.get_children():
			stack.append(child)
	return best


func _find_desk_top(desk: Node3D) -> Node3D:
	if desk == null:
		return null
	var stack: Array[Node] = [desk]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Node3D:
			var node_name := String(current.name).to_lower()
			if node_name == "top" or node_name.contains("desktoptop"):
				return current as Node3D
		for child in current.get_children():
			stack.append(child)
	return null


func _remove_all_intro_papers(root: Node) -> void:
	if root == null:
		return
	var to_remove: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current.get_meta("intro_paper", false):
			to_remove.append(current)
		else:
			for child in current.get_children():
				stack.append(child)
	for paper in to_remove:
		paper.queue_free()


func _find_first_node_named(node: Node, target_name: String) -> Node:
	if node == null:
		return null
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_first_node_named(child, target_name)
		if found != null:
			return found
	return null


func _prepare_intro_paper() -> bool:
	if question_database == null:
		return false

	intro_questions.clear()
	intro_answers.clear()
	var intro_max_difficulty := 2
	match intro_level:
		"SMP":
			intro_max_difficulty = 3
		"SMA", "Dasar":
			intro_max_difficulty = 5
		"SD":
			intro_max_difficulty = 2
	for i in range(INTRO_QUESTIONS):
		var question: Dictionary = question_database.get_random_question(intro_level, intro_max_difficulty)
		if question.is_empty():
			push_error("Map58Game: bank soal tidak menyediakan 5 soal untuk mode " + intro_level + ".")
			return false
		intro_questions.append(question)
		intro_answers.append("")

	current_question = intro_questions[0]
	_update_intro_paper_visuals()
	_refresh_intro_paper_ui()
	return true


func _update_intro_paper_visuals() -> void:
	var paper := _find_first_node_named(get_tree().current_scene, "IntroQuestionPaper") as Node3D
	if paper == null:
		return
	var label := paper.get_node_or_null("QuestionPaperViewport/QuestionPaperPage/MarginContainer/VBoxContainer/IntroQuestions") as Label
	if label == null:
		return
	var text_value := ""
	for i in range(intro_questions.size()):
		text_value += "%d. %s\n\nJawaban: ____________________\n\n" % [i + 1, String(intro_questions[i].get("question", ""))]
	label.text = text_value


func _finish_intro_exam() -> void:
	if phase != PHASE_INTRO_EXAM or intro_departure_active:
		return

	_submit_intro_paper_answers()
	_hide_intro_paper()
	_set_phase(PHASE_TRANSITION)
	transition_remaining = 0.0
	intro_blackout_remaining = INTRO_BLACKOUT_DELAY
	intro_departure_active = true
	_set_teacher_mode(TEACHER, null)
	_update_objective()
	_run_intro_departure_cutscene()


func _run_intro_departure_cutscene() -> void:
	var teacher := get_node_or_null("../Teacher") as CharacterBody3D
	var destination := get_node_or_null("../SpawnManager/TeacherSpawn") as Node3D
	var player := get_tree().get_first_node_in_group("players") as CharacterBody3D
	var rooms_node := get_tree().current_scene.get_node_or_null("Map58/Rooms")
	var exit_marker: Node3D = null
	var door: Node3D = null
	var best_distance := INF
	var spawn_name := String(player.get_meta("intro_spawn_marker_name", "")) if player != null else ""

	if teacher == null or player == null:
		intro_departure_active = false
		_start_hunt()
		return

	# Pilih pintu kelas berdasarkan metadata spawn, lalu fallback ke marker terdekat.
	if rooms_node != null:
		for room in rooms_node.get_children():
			if not room is Node3D:
				continue
			var marker := room.get_node_or_null("Door") as Node3D
			if marker == null:
				continue
			var source_name := String(room.get_meta("door_source", ""))
			var distance := player.global_position.distance_to(marker.global_position)
			if not spawn_name.is_empty() and source_name.contains(spawn_name):
				distance = -1.0
			if distance < best_distance:
				best_distance = distance
				exit_marker = marker
				var found_door := _find_first_node_named(get_tree().current_scene, source_name) as Node3D
				if found_door != null and found_door.has_method("interact"):
					door = found_door

	if door == null and exit_marker != null:
		var nearest := INF
		for candidate in get_tree().get_nodes_in_group("doors"):
			if candidate is Node3D and candidate.has_method("interact"):
				var d := exit_marker.global_position.distance_to((candidate as Node3D).global_position)
				if d < nearest:
					nearest = d
					door = candidate as Node3D

	player.set_meta("intro_locked", true)
	player.set_process_unhandled_input(false)
	var camera := player.get_node_or_null("Camera3D") as Camera3D
	var teacher_anim := teacher.get_node_or_null("TeacherAnimation")
	if teacher_anim != null and teacher_anim.has_method("set_intro_floating"):
		teacher_anim.call("set_intro_floating", true)

	var start_pos := teacher.global_position
	var door_pos := door.global_position if door != null else (exit_marker.global_position if exit_marker != null else start_pos + Vector3.FORWARD * 2.0)

	# Cari arah tegak lurus dinding dari sisi pintu yang ditempati pemain.
	# Ini membuat guru mendekati ambang dari dalam kelas, bukan memotong dinding secara diagonal.
	var door_to_player := player.global_position - door_pos
	door_to_player.y = 0.0
	var inward := Vector3(0.0, 0.0, -1.0)
	if absf(door_to_player.x) > absf(door_to_player.z):
		inward = Vector3(signf(door_to_player.x), 0.0, 0.0)
	else:
		inward = Vector3(0.0, 0.0, signf(door_to_player.z))
	if inward.length_squared() < 0.001:
		inward = Vector3(0.0, 0.0, -1.0)

	var floating_height := 1.0
	var approach_point := door_pos + inward * 2.2 + Vector3.UP * floating_height
	var threshold_point := door_pos + Vector3.UP * floating_height
	var outside_point := door_pos - inward * 2.4 + Vector3.UP * floating_height

	# POV mulai mengikuti guru sejak ia terangkat, bukan diarahkan ke pintu.
	_intro_camera_tracking_teacher = true

	# A. Guru perlahan terangkat; beri jeda agar momen terasa ganjil.
	var rise := create_tween()
	rise.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rise.tween_property(teacher, "global_position", start_pos + Vector3.UP * 1.35, 2.4)
	await rise.finished
	await get_tree().create_timer(0.8).timeout

	# B. Kamera terus mengikuti posisi guru saat ia bergerak menuju pintu.

	# C. Guru berputar menghadap pintu sambil melayang ke ambang.
	# Arah rotasi dihitung dari posisi guru menuju pintu, bukan arah awal model.
	var face_door_direction := door_pos - approach_point
	face_door_direction.y = 0.0
	var approach := create_tween()
	approach.set_parallel(true)
	approach.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	approach.tween_property(teacher, "global_position", approach_point, 3.2)
	if face_door_direction.length_squared() > 0.001:
		var face_door_yaw := atan2(-face_door_direction.x, -face_door_direction.z)
		approach.tween_property(teacher, "global_rotation:y", face_door_yaw, 1.0)
	await approach.finished
	await get_tree().create_timer(0.7).timeout

	# D. Buka pintu fisik yang sama dengan marker, tunggu daun pintu selesai bergerak.
	if door != null:
		if not (door.has_method("is_open") and bool(door.call("is_open"))):
			door.call("interact", teacher)
		await get_tree().create_timer(0.9).timeout

	# E. Lintasi ambang lurus tegak lurus dinding, bukan bergerak diagonal menembus tembok.
	var reach_threshold := create_tween()
	reach_threshold.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reach_threshold.tween_property(teacher, "global_position", threshold_point, 1.8)
	await reach_threshold.finished
	var cross := create_tween()
	cross.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cross.tween_property(teacher, "global_position", outside_point, 2.8)
	await cross.finished
	# Hentikan tracking tepat setelah guru benar-benar melewati ambang pintu.
	_intro_camera_tracking_teacher = false
	await get_tree().create_timer(0.6).timeout

	# F. Guru menghilang menuju ruang guru setelah benar-benar keluar dari pintu.
	if destination != null:
		var settle := create_tween()
		settle.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		settle.tween_property(teacher, "global_position", destination.global_position + Vector3.UP * 0.8, 2.5)
		await settle.finished
	if door != null and door.has_method("is_open") and bool(door.call("is_open")):
		door.call("interact", teacher)
		await get_tree().create_timer(0.8).timeout
	if teacher_anim != null and teacher_anim.has_method("set_intro_floating"):
		teacher_anim.call("set_intro_floating", false)
	teacher.velocity = Vector3.ZERO
	player.set_meta("intro_locked", false)
	player.set_process_unhandled_input(true)
	_set_mouse_mode_for_gameplay()
	intro_departure_active = false
	_start_hunt()


func _set_mouse_mode_for_gameplay() -> void:
	# Jangan mengunci kursor saat HUD sentuh aktif, termasuk preview HUD di PC.
	var player_node := get_tree().get_first_node_in_group("players")
	var controls := player_node.get_node_or_null("MobileControls") if player_node != null else null
	var touch_hud_enabled := controls != null and controls.has_method("is_mobile") and bool(controls.call("is_mobile"))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if touch_hud_enabled else Input.MOUSE_MODE_CAPTURED


func _start_intro_teacher_departure() -> void:
	# Kept as a compatibility wrapper; departure is now a scripted cutscene.
	_run_intro_departure_cutscene()


func _is_intro_departure_complete() -> bool:
	var teacher := get_node_or_null("../Teacher")
	if teacher == null:
		return true
	if teacher.has_method("is_intro_departure_complete"):
		return bool(teacher.is_intro_departure_complete())
	return false


func _start_intro_teacher_floating() -> void:
	var teacher := get_node_or_null("../Teacher") as Node3D
	if teacher == null:
		return
	_intro_teacher_start_position = teacher.global_position
	_intro_teacher_start_rotation = teacher.global_rotation
	_intro_teacher_tween = create_tween()
	_intro_teacher_tween.set_parallel(true)
	_intro_teacher_tween.tween_property(teacher, "global_position:y", teacher.global_position.y + 2.2, 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_intro_teacher_tween.tween_property(teacher, "rotation_degrees:x", teacher.rotation_degrees.x + 8.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _restore_intro_teacher_transform() -> void:
	if _intro_teacher_tween != null and _intro_teacher_tween.is_running():
		_intro_teacher_tween.kill()
	var teacher := get_node_or_null("../Teacher") as Node3D
	if teacher != null:
		teacher.global_position = _intro_teacher_start_position
		teacher.global_rotation = _intro_teacher_start_rotation


func get_intro_paper_text() -> String:
	var text_value := "KERTAS SOAL\n"
	for i in range(intro_questions.size()):
		text_value += "%d. %s\n" % [i + 1, String(intro_questions[i].get("question", ""))]
	return text_value


func open_intro_paper() -> void:
	if phase != PHASE_INTRO_EXAM:
		return
	if _intro_paper_open:
		return
	_intro_paper_open = true
	if _intro_paper_canvas != null:
		_intro_paper_canvas.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not _intro_answer_edits.is_empty():
		_intro_answer_edits[0].grab_focus()


func _hide_intro_paper() -> void:
	_intro_paper_open = false
	if _intro_paper_canvas != null:
		_intro_paper_canvas.visible = false
	_set_mouse_mode_for_gameplay()


func _submit_intro_paper_answers() -> void:
	if _intro_answers_submitted:
		return
	_intro_answers_submitted = true
	initial_exam_correct = 0
	for i in range(intro_questions.size()):
		var supplied := ""
		if i < _intro_answer_edits.size():
			supplied = _intro_answer_edits[i].text.strip_edges()
		if i < intro_answers.size():
			intro_answers[i] = supplied
		var expected := String(intro_questions[i].get("answer", "")).strip_edges()
		if not supplied.is_empty() and supplied == expected:
			initial_exam_correct += 1
			score += 10
		else:
			score -= 5


func _finish_intro_paper_early() -> void:
	if phase != PHASE_INTRO_EXAM:
		return
	var all_answered := not _intro_answer_edits.is_empty()
	for answer_edit in _intro_answer_edits:
		if answer_edit.text.strip_edges().is_empty():
			all_answered = false
			break
	if all_answered:
		_finish_intro_exam()
		return
	_submit_intro_paper_answers()
	_hide_intro_paper()
	_set_status("Jawaban disimpan. Isi semua jawaban untuk mengakhiri ujian lebih awal, atau tunggu waktu habis.")


func _set_intro_locked(locked: bool) -> void:
	var player := get_node_or_null("../Player/CharacterBody3D")
	if player != null:
		player.set_meta("intro_locked", locked)


func _set_intro_pov_locked(locked: bool) -> void:
	var player := get_node_or_null("../Player/CharacterBody3D")
	if player != null:
		player.set_meta("intro_pov_locked", locked)


func _close_nearest_class_door() -> void:
	var player := get_node_or_null("../Player/CharacterBody3D") as Node3D
	if player == null:
		return
	var nearest: Node3D = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("doors"):
		if not node is Node3D or not node.has_method("is_open") or not node.has_method("interact"):
			continue
		var door := node as Node3D
		var distance := player.global_position.distance_to(door.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = door
	if nearest != null and nearest_distance <= 8.0 and bool(nearest.is_open()):
		nearest.interact(player)


func _blackout_nearest_class_lights() -> void:
	var player := get_node_or_null("../Player/CharacterBody3D") as Node3D
	if player == null:
		return
	var lights: Array[Node] = []
	var lighting_root := get_node_or_null("../Map58_Lighting")
	if lighting_root != null:
		_collect_lights(lighting_root, lights)
	for node in lights:
		var light := node as Light3D
		if light != null and light.global_position.distance_to(player.global_position) <= 10.5:
			light.set_meta("intro_blackout", true)
			light.visible = false

	set_meta("intro_blackout_applied", true)


func _collect_lights(node: Node, result: Array[Node]) -> void:
	if node is Light3D:
		result.append(node)
	for child in node.get_children():
		_collect_lights(child, result)


func _prepare_next_penalty_question() -> bool:
	if question_database == null:
		return false

	current_question = question_database.get_penalty_question(penalty_question_index, _room_question_level if not _room_question_level.is_empty() else intro_level)

	if current_question.is_empty():
		push_error("Map58Game: bank soal untuk penalti tidak tersedia.")
		return false

	_answer_label.text = ""
	return true


func _prepare_next_board_question(player: Node) -> bool:
	if question_database == null:
		return false

	current_question = question_database.get_board_question(solved_papers + 1, _room_question_level)

	if current_question.is_empty():
		_set_status("Bank soal untuk tahap ini tidak tersedia.")
		return false

	board_player = player
	_answer_label.text = ""
	return true


func _get_level_base_difficulty(level: String) -> int:
	if question_database == null:
		return 1

	var minimum := 999
	for value in question_database.questions:
		if not value is Dictionary:
			continue
		var question: Dictionary = value
		if String(question.get("level", "")) != level:
			continue
		minimum = mini(minimum, int(question.get("difficulty", 1)))

	if minimum == 999:
		return 1
	return clampi(minimum, 1, 5)


func _on_penalty_answer_submitted(value: String) -> void:
	_submit_exam_answer(value)


func _on_penalty_submit_pressed() -> void:
	if _penalty_answer_input != null:
		_submit_exam_answer(_penalty_answer_input.text)


func _handle_numeric_exam_input(event: InputEventKey) -> bool:
	var changed := false

	if event.keycode == KEY_BACKSPACE:
		var text_value := _answer_label.text
		if not text_value.is_empty():
			_answer_label.text = text_value.substr(0, text_value.length() - 1)
		changed = true

	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_submit_exam_answer(_answer_label.text)
		changed = true

	elif event.unicode >= 48 and event.unicode <= 57:
		if _answer_label.text.length() < 12:
			_answer_label.text += String.chr(event.unicode)
		changed = true

	return changed


func _submit_exam_answer(answer_text: String) -> void:
	if (_penalty_exam_active or phase == PHASE_PENALTY_EXAM) and _is_multiplayer_client():
		var network_game := get_tree().current_scene.get_node_or_null("MultiplayerGame")
		if network_game != null and network_game.has_method("request_penalty_answer"):
			network_game.rpc_id(1, "request_penalty_answer", answer_text.strip_edges())
			_answer_label.text = ""
			if _penalty_answer_input != null:
				_penalty_answer_input.text = ""
			_set_status("Jawaban hukuman dikirim ke host...")
		return

	var supplied := answer_text.strip_edges()
	var expected := String(current_question.get("answer", "")).strip_edges()

	if supplied.is_empty():
		_set_status("Masukkan jawaban terlebih dahulu.")
		return

	# Alur penalti dipisah dari ujian pembuka agar jawaban benar maupun salah
	# selalu memuat soal baru, membersihkan input, lalu langsung menyegarkan UI.
	if _penalty_exam_active or phase == PHASE_PENALTY_EXAM:
		var was_correct := supplied == expected
		if was_correct:
			score += 10
		else:
			score -= 5

		penalty_question_index += 1
		_answer_label.text = ""
		if _penalty_answer_input != null:
			_penalty_answer_input.text = ""
		if penalty_question_index >= PENALTY_QUESTIONS:
			_exit_penalty_and_knockout()
			return

		if not _prepare_next_penalty_question():
			_set_status("Soal berikutnya gagal dimuat. Coba kirim jawaban lagi.")
			return

		if was_correct:
			_set_status("Benar. Soal berikutnya.")
		else:
			_set_status("Salah. Jawaban benar: " + expected + ". Soal baru dimuat.")
		_update_ui()
		return

	# Ujian pembuka tetap memakai alur yang sudah ada.
	if supplied == expected:
		initial_exam_correct += 1
		score += 10
		_set_status("Benar. " + str(intro_question_index + 1) + "/" + str(INTRO_QUESTIONS))
	else:
		score -= 5
		_set_status("Salah. Jawaban benar: " + expected)



func _begin_transition() -> void:
	_set_phase(PHASE_TRANSITION)
	transition_remaining = TRANSITION_TIME
	_set_teacher_mode(GHOST, null)
	_set_status("Guru mengamuk. Bersiap...")
	_update_objective()


func _start_hunt() -> void:
	var ending_transition := phase == PHASE_TRANSITION
	if ending_transition:
		intro_blackout_remaining = -1.0
		intro_departure_active = false
		_set_intro_locked(false)
		_hide_intro_paper()
		var player := get_tree().get_first_node_in_group("players") as CharacterBody3D
		if player != null:
			player.set_meta("intro_sitting", false)
	_set_phase(PHASE_HUNT)
	berserking_end()
	calm_remaining = 0.0
	berserk_remaining = 0.0
	hunt_remaining = 0.0
	initial_teacher_remaining = randf_range(INITIAL_TEACHER_MIN_TIME, INITIAL_TEACHER_MAX_TIME)
	_set_teacher_mode(TEACHER, null)
	_update_objective()


func _start_ghost_mode() -> void:
	if phase != PHASE_HUNT or calm_remaining > 0.0 or berserk_remaining > 0.0:
		return
	initial_teacher_remaining = 0.0
	hunt_remaining = 0.0
	_set_teacher_mode(GHOST, null)
	_set_status("Mode Hantu aktif. Guru akan terus mengejar sampai kamu menjawab soal papan tulis dengan benar.")

func begin_board_question(player: Node, board: Node3D) -> Dictionary:
	if phase != PHASE_HUNT and phase != PHASE_ESCAPE_READY:
		return {}

	if solved_papers >= TOTAL_PAPERS_TO_ESCAPE or board_player != null:
		return {}

	var inventory := player.get_node_or_null("ItemInventory")
	if inventory == null and bool(player.get_meta("is_network_proxy", false)):
		var remote_items: Array = player.get_meta("inventory_types", [])
		if not remote_items.has("paper"):
			_set_status("Pemain harus membawa Kertas Soal.")
			return {}
		if not remote_items.has("chalk"):
			_set_status("Pemain harus membawa Kapur.")
			return {}
	elif inventory == null:
		return {}
	else:
		if not inventory.has_item("paper"):
			_set_status("Bawa Kertas Soal terlebih dahulu.")
			return {}
		if not inventory.has_item("chalk"):
			_set_status("Bawa Kapur terlebih dahulu.")
			return {}

	if not _prepare_next_board_question(player):
		return {}

	board_node = board
	board_remaining = BOARD_TIME_LIMIT
	# RESPONDING hanya berlaku saat soal papan dikerjakan; simpan mode utama untuk pemulihan.
	mode_before_responding = teacher_mode if teacher_mode in [TEACHER, GHOST] else GHOST
	_set_phase(PHASE_BOARD_SOLVING)
	_set_teacher_mode(RESPONDING, player)
	_set_status("Guru mengetahui kelasmu. Waktu menjawab: 2 menit.")

	return current_question.duplicate(true)


func submit_board_answer(player: Node, answer_text: String) -> bool:
	if phase != PHASE_BOARD_SOLVING:
		return false

	if player != board_player:
		return false

	var inventory := player.get_node_or_null("ItemInventory")
	if inventory == null and not bool(player.get_meta("is_network_proxy", false)):
		return false

	var expected := String(current_question.get("answer", "")).strip_edges()
	var supplied := answer_text.strip_edges()

	_consume_used_board_items(inventory)

	if supplied == expected and not supplied.is_empty():
		score += 10
		solved_papers += 1
		active_paper_count = max(0, active_paper_count - 1)

		_set_status("Jawaban benar. Soal berikutnya akan muncul di lokasi baru.")
		board_answer_result.emit(true, "BENAR! +10 poin")
		_clear_board_state()
		_set_teacher_mode(TEACHER, null)

		if solved_papers >= TOTAL_PAPERS_TO_ESCAPE:
			_finish_objective()
		else:
			_start_calm_phase()
			paper_respawn_requested.emit()
			_update_objective()

		return true

	score -= 5
	active_paper_count = max(0, active_paper_count - 1)
	berserk_target = player
	# Bersek berlangsung 15 detik lalu mengembalikan mode utama yang aktif sebelum soal.
	mode_before_berserk = mode_before_responding if mode_before_responding in [TEACHER, GHOST] else GHOST
	berserk_remaining = BERSERK_TIME
	_clear_board_state()

	_set_phase(PHASE_HUNT)
	_set_teacher_mode(BERSERK, player)
	_set_status("SALAH. Guru masuk mode BERSEK selama 15 detik.")
	board_answer_result.emit(false, "SALAH! -5 poin. Guru mengamuk!")
	paper_respawn_requested.emit()
	_update_objective()
	return false


func _clear_board_state() -> void:
	board_player = null
	board_node = null
	board_remaining = 0.0


func _consume_used_board_items(inventory: Node) -> void:
	if inventory != null and inventory.has_method("consume_item_type"):
		inventory.consume_item_type("paper")
		inventory.consume_item_type("chalk")
	elif inventory == null and is_instance_valid(board_player) and bool(board_player.get_meta("is_network_proxy", false)):
		var peer_id := int(board_player.get_meta("network_peer_id", 0))
		var scene := get_tree().current_scene
		var network_game := scene.get_node_or_null("MultiplayerGame") if scene != null else null
		if peer_id > 1 and network_game != null and network_game.has_method("consume_peer_inventory_item"):
			network_game.call("consume_peer_inventory_item", peer_id, "paper")
			network_game.call("consume_peer_inventory_item", peer_id, "chalk")
		else:
			var remote_items: Array = board_player.get_meta("inventory_types", [])
			remote_items.erase("paper")
			remote_items.erase("chalk")
			board_player.set_meta("inventory_types", remote_items)


func _board_timeout() -> void:
	if phase != PHASE_BOARD_SOLVING:
		return

	var player := board_player
	var inventory := player.get_node_or_null("ItemInventory") if player != null else null
	if inventory != null or (is_instance_valid(player) and bool(player.get_meta("is_network_proxy", false))):
		_consume_used_board_items(inventory)

	active_paper_count = max(0, active_paper_count - 1)
	score -= 5
	paper_respawn_requested.emit()

	berserk_target = player
	_clear_board_state()
	_set_phase(PHASE_HUNT)
	_set_teacher_mode(GHOST, null)
	_set_status("Waktu habis. Guru mengejarmu lagi.")
	board_answer_result.emit(false, "Waktu habis! -5 poin")
	_update_objective()


func _start_calm_phase() -> void:
	_set_phase(PHASE_HUNT)
	# Jawaban benar memulai ulang jendela Mode Guru tepat 3 menit.
	initial_teacher_remaining = 0.0
	calm_remaining = CALM_TIME
	hunt_remaining = CALM_TIME
	_set_teacher_mode(TEACHER, null)
	_set_status("Guru kembali ke mode guru selama 3 menit.")


func _finish_objective() -> void:
	_set_phase(PHASE_ESCAPE_READY)
	hunt_remaining = 0.0
	calm_remaining = 0.0
	berserk_remaining = 0.0
	_set_teacher_mode(TEACHER, null)
	_unlock_school_gate()
	var gate := get_node_or_null("../Furniture/PintuSekolah_MainEntrance") as Node3D
	var teacher := get_node_or_null("../Teacher")
	if teacher != null and teacher.has_method("begin_escape_to_gate") and gate != null:
		teacher.call("begin_escape_to_gate", gate)
	_set_status("10 soal benar. Guru berjalan ke pintu utama dan membukanya. Lewati pintu untuk menang.")
	_update_objective()


func complete_escape(player: Node = null) -> bool:
	if phase != PHASE_ESCAPE_READY:
		return false

	_set_phase(PHASE_FINISHED)
	_set_teacher_mode(TEACHER, null)
	_set_status("Kamu berhasil keluar dari sekolah. Nilai akhir: " + str(get_final_grade()) + ".")
	game_finished.emit()
	return true


func get_final_grade() -> String:
	if question_database == null:
		return "D"

	var data_value: Variant = question_database.data.get("grading_reference", {})
	if not data_value is Dictionary:
		return "D"

	var grading: Dictionary = data_value
	var grades_value: Variant = grading.get("grades", [])
	if not grades_value is Array:
		return "D"

	for entry_value in grades_value:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var minimum := int(entry.get("min", -999999))
		var maximum := int(entry.get("max", 999999))
		if score >= minimum and score <= maximum:
			return String(entry.get("grade", "D"))

	return "D"


func _unlock_school_gate() -> void:
	var gate := get_node_or_null("../Furniture/PintuSekolah_MainEntrance")
	if gate != null and gate.has_method("set_locked"):
		gate.set_locked(false)


func player_caught(player: Node) -> void:
	if player == null or phase == PHASE_FINISHED or _capture_in_progress:
		return

	# UI soal hanya satu pada satu waktu; jangan menimpa hukuman murid aktif.
	# Guru dapat mencoba menangkap murid berikutnya setelah penalti ini selesai.
	if _penalty_exam_active and player != penalty_player:
		return
	if teacher_mode in [TEACHER, GHOST, BERSERK]:
		mode_before_capture = teacher_mode
	elif teacher_mode == RESPONDING:
		mode_before_capture = mode_before_responding if mode_before_responding in [TEACHER, GHOST] else GHOST
	else:
		mode_before_capture = GHOST
	target_before_capture = berserk_target if mode_before_capture == BERSERK else null
	_capture_in_progress = true
	var audio := get_tree().get_first_node_in_group("game_audio")
	if audio != null and audio.has_method("play_sfx"):
		audio.play_sfx("fuzzy_jumpscare")
	_capture_sequence(player)


func _capture_sequence(player: Node) -> void:
	# Kunci input selama jumpscare dan adegan penyeretan agar penangkapan
	# tidak dapat dipicu berulang atau diganggu gerakan pemain.
	if not is_instance_valid(player):
		_capture_in_progress = false
		return

	player.set_meta("capture_animation", true)
	player.set_meta("intro_locked", true)
	var teacher := get_node_or_null("../Teacher") as Node3D
	if teacher != null:
		teacher.set_meta("capture_pose", true)
		# Put the teacher's look target on the same horizontal plane.
		# A target 2.7 m above the teacher makes Node3D.look_at pitch the entire body upward.
		var face_position := Vector3(player.global_position.x, teacher.global_position.y, player.global_position.z)
		var horizontal_to_player := face_position - teacher.global_position
		if horizontal_to_player.length_squared() > 0.0025:
			teacher.look_at(face_position, Vector3.UP)

	var camera := player.get_node_or_null("Camera3D") as Camera3D
	var original_fov := camera.fov if camera != null else 75.0
	var original_camera_rotation := camera.rotation if camera != null else Vector3.ZERO
	if camera != null and teacher != null:
		# Arahkan POV langsung ke wajah guru, bukan hanya mengguncang kamera.
		var face_target := teacher.global_position + Vector3.UP * 2.7
		camera.look_at(face_target, Vector3.UP)
		var face_rotation := camera.global_rotation
		camera.rotation = original_camera_rotation
		var camera_tween := create_tween()
		camera_tween.set_parallel(true)
		camera_tween.tween_property(camera, "fov", minf(original_fov + 15.0, 105.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		camera_tween.tween_property(camera, "global_rotation", face_rotation, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "CaptureFlash"
	overlay_layer.layer = 90
	add_child(overlay_layer)
	var flash := ColorRect.new()
	flash.name = "RedFlash"
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(0.35, 0.0, 0.015, 0.0)
	overlay_layer.add_child(flash)
	var flash_tween := create_tween()
	# Two strong pulses make the capture beat readable even on a dark map.
	flash_tween.tween_property(flash, "color:a", 0.88, 0.07)
	flash_tween.tween_property(flash, "color:a", 0.12, 0.10)
	flash_tween.tween_property(flash, "color:a", 0.72, 0.08)
	flash_tween.tween_property(flash, "color:a", 0.0, 0.42)

	# Beat singkat setelah wajah guru memenuhi pandangan, lalu tubuh pemain
	# ditarik ke pintu ruang tamu dengan gerakan kontinu.
	await get_tree().create_timer(0.72).timeout
	if not is_instance_valid(player) or phase == PHASE_FINISHED:
		if is_instance_valid(overlay_layer):
			overlay_layer.queue_free()
		if is_instance_valid(teacher):
			teacher.set_meta("capture_pose", false)
		_capture_in_progress = false
		return

	# Hello Neighbor-inspired capture: carry the player along the navigation mesh,
	# with physics collision enabled, while the teacher follows instead of posing in place.
	player.set_meta("capture_dragging", true)
	if is_instance_valid(teacher):
		teacher.set_meta("capture_dragging", true)
	var guest_room := get_node_or_null("../Furniture/GuestRoom_Furniture/FurnitureRoot/Sofa_03Seat") as Node3D
	if guest_room == null:
		guest_room = get_node_or_null("../Map58_Furniture/GuestRoom_Furniture/FurnitureRoot/Sofa_03Seat") as Node3D
	if guest_room != null and player is CharacterBody3D:
		var seat_approach := guest_room.global_position + guest_room.global_basis.z * 1.8
		seat_approach.y = player.global_position.y
		await _move_captured_player_to(player as CharacterBody3D, teacher, seat_approach)
	else:
		push_warning("Map58Game: Sofa_03Seat atau CharacterBody3D murid tidak ditemukan; penyeretan dibatalkan agar tidak memindahkan murid menembus geometri.")

	if not is_instance_valid(player) or phase == PHASE_FINISHED:
		if is_instance_valid(player):
			player.set_meta("capture_dragging", false)
			player.set_meta("capture_animation", false)
			player.set_meta("intro_locked", false)
		if is_instance_valid(overlay_layer):
			overlay_layer.queue_free()
		if is_instance_valid(teacher):
			teacher.set_meta("capture_pose", false)
			teacher.set_meta("capture_dragging", false)
		_capture_in_progress = false
		return

	player.set_meta("capture_dragging", false)
	player.set_meta("capture_animation", false)
	# Pertahankan kontrol terkunci dan pose duduk selama 5 soal hukuman.
	player.set_meta("intro_sitting", true)
	player.set_meta("intro_locked", true)
	if guest_room != null:
		# Node sofa memakai origin lantai; offset ini menempatkan badan pada tinggi dudukan.
		player.global_position = guest_room.global_position + guest_room.global_basis * Vector3(0.0, 0.48, 0.12)
		player.global_rotation.y = guest_room.global_rotation.y
		var seated_camera := player.get_node_or_null("Camera3D") as Camera3D
		if seated_camera != null:
			seated_camera.position.y = 0.95
	if camera != null and is_instance_valid(camera):
		var reset_tween := create_tween()
		reset_tween.set_parallel(true)
		reset_tween.tween_property(camera, "fov", original_fov, 0.25)
		reset_tween.tween_property(camera, "rotation", original_camera_rotation, 0.25)
	if teacher != null and is_instance_valid(teacher):
		teacher.set_meta("capture_pose", false)
		teacher.set_meta("capture_dragging", false)
	if is_instance_valid(overlay_layer):
		overlay_layer.queue_free()

	penalty_player = player
	# Pertahankan target mode berserk bila targetnya murid lain yang masih aktif.
	# Murid yang baru ditangkap tidak boleh langsung menjadi target lagi.
	var restored_mode_target: Node = null
	if mode_before_capture == BERSERK and is_instance_valid(target_before_capture):
		if target_before_capture != player and not bool(target_before_capture.get_meta("knocked_out", false)):
			restored_mode_target = target_before_capture
	berserk_target = restored_mode_target
	board_player = null
	board_node = null
	# Jangan mengganti fase global: murid lain dan AI harus tetap bermain.
	_penalty_exam_active = true
	_set_teacher_mode(mode_before_capture, restored_mode_target)
	# Bersihkan target/state pengejaran lama. AI akan melanjutkan mode yang tersimpan
	# saat fase gameplay aktif lagi (misalnya setelah revive).
	if is_instance_valid(teacher):
		teacher.set("_current_target", null)
		teacher.set("_current_state", 0)
		teacher.set("_state_timer", 0.0)
		teacher.set_meta("capture_pose", false)
		teacher.set_meta("capture_dragging", false)
	penalty_question_index = 0
	_prepare_next_penalty_question()
	_set_status("Tertangkap. Jawab soal untuk keluar dari ruangan hukuman.")
	_capture_in_progress = false


func _move_captured_player_to(player: CharacterBody3D, teacher: Node3D, destination: Vector3) -> void:
	# Use the teacher's baked navigation map, then move the player in short
	# physics steps so walls and furniture can block movement normally.
	var nav_agent := teacher.get_node_or_null("NavigationAgent3D") as NavigationAgent3D if teacher != null else null
	if nav_agent == null or not nav_agent.get_navigation_map().is_valid():
		push_warning("Map58Game: navigation map guru tidak tersedia; rute penangkapan dibatalkan.")
		return

	await get_tree().physics_frame
	var nav_map: RID = nav_agent.get_navigation_map()
	var path := NavigationServer3D.map_get_path(nav_map, player.global_position, destination, true)
	if path.size() < 2:
		push_warning("Map58Game: tidak ada rute navigasi menuju sofa ruang tamu.")
		return

	# Gerakan penyeretan sudah mengambil alih AI melalui meta capture_dragging.
	# Jangan mengubah fase global ke TRANSITION: fase itu khusus cutscene intro,
	# dan membuat timer gameplay, AI guru, serta state multiplayer seolah berhenti.
	# Pertahankan fase aktif agar game lanjut setelah jumpscare/penyeretan.
	# Percepat penyeretan murid dan langkah guru agar cutscene tidak terasa lambat.
	var speed := 12.0
	var teacher_speed := 13.5
	for path_index in range(1, path.size()):
		var waypoint: Vector3 = path[path_index]
		var waypoint_frames := 0
		while is_instance_valid(player) and player.global_position.distance_to(waypoint) > 0.22:
			await get_tree().physics_frame
			if not is_instance_valid(player) or phase == PHASE_FINISHED:
				return
			waypoint_frames += 1
			if waypoint_frames > 150:
				# A blocked waypoint must not trap the cutscene forever; continue to
				# the next baked waypoint and let collision keep the body in the world.
				push_warning("Map58Game: waypoint penyeretan terhalang; mencoba waypoint berikutnya.")
				break
			var dt := 1.0 / float(Engine.physics_ticks_per_second)
			var offset := waypoint - player.global_position
			offset.y = 0.0
			if offset.length() <= 0.22:
				break
			var step := offset.normalized() * minf(speed * dt, offset.length())

			# Guru memakai NavigationAgent3D dan collision; jalur player tetap bergerak
			# agar satu tabrakan guru tidak membekukan seluruh adegan penyeretan.
			if teacher is CharacterBody3D and is_instance_valid(teacher):
				var teacher_body := teacher as CharacterBody3D
				var teacher_nav := teacher_body.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
				var player_to_teacher := player.global_position - teacher_body.global_position
				player_to_teacher.y = 0.0
				if teacher_nav != null and player_to_teacher.length() > 1.25:
					# Target berada sedikit di belakang player, agar guru mengikuti
					# tanpa mencoba menembus tubuh player.
					var trailing_target := player.global_position - step.normalized() * 1.25
					if trailing_target.distance_to(teacher_nav.target_position) > 0.75:
						teacher_nav.target_position = trailing_target
					var next_teacher_point := teacher_nav.get_next_path_position()
					var teacher_follow := next_teacher_point - teacher_body.global_position
					teacher_follow.y = 0.0
					if teacher_follow.length() > 0.12:
						var teacher_step := teacher_follow.normalized() * minf(teacher_speed * dt, teacher_follow.length())
						teacher_body.velocity = teacher_step / maxf(dt, 0.0001)
						teacher_body.rotation.y = atan2(-teacher_step.x, -teacher_step.z)
						# move_and_slide mempertahankan collision response dan memungkinkan
						# badan guru meluncur di sepanjang sisi furnitur/tembok.
						teacher_body.move_and_slide()
						teacher_body.rotation.x = 0.0
						teacher_body.rotation.z = 0.0
						if teacher_body.get_slide_collision_count() > 0:
							var teacher_collision := teacher_body.get_slide_collision(0)
							# Jika guru menyentuh pintu, buka dengan sistem pintu yang ada.
							var teacher_blocking_door := _find_capture_door(teacher_collision.get_collider())
							if teacher_blocking_door != null:
								var door_is_open := bool(teacher_blocking_door.call("is_open")) if teacher_blocking_door.has_method("is_open") else false
								var door_is_transitioning := bool(teacher_blocking_door.call("is_transitioning")) if teacher_blocking_door.has_method("is_transitioning") else false
								if not door_is_open and not door_is_transitioning:
									teacher_blocking_door.call("interact", teacher)
				else:
						teacher_body.velocity = Vector3.ZERO

			var collision := player.move_and_collide(step)
			if collision != null:
				# Jika tabrakan berasal dari daun pintu, minta guru membukanya,
				# tunggu animasi pintu, lalu coba waypoint yang sama lagi.
				var blocking_door := _find_capture_door(collision.get_collider())
				if blocking_door != null:
					var was_open := bool(blocking_door.call("is_open")) if blocking_door.has_method("is_open") else false
					var transitioning := bool(blocking_door.call("is_transitioning")) if blocking_door.has_method("is_transitioning") else false
					if not was_open and not transitioning:
						blocking_door.call("interact", teacher)
						transitioning = true
					if transitioning:
						var door_wait_frames := 0
						while is_instance_valid(blocking_door) and door_wait_frames < 90:
							if not blocking_door.has_method("is_transitioning") or not bool(blocking_door.call("is_transitioning")):
								break
							await get_tree().physics_frame
							door_wait_frames += 1
						continue
				# Pintu bukan penghalang yang bisa dibuka: geser sepanjang dinding
				# dan tetap gunakan collision fisika.
				var slide_step := step.slide(collision.get_normal())
				if slide_step.length_squared() > 0.0001:
					player.move_and_collide(slide_step)

	if is_instance_valid(teacher) and teacher is CharacterBody3D:
		(teacher as CharacterBody3D).velocity = Vector3.ZERO


func _find_capture_door(collider: Object) -> Node3D:
	var current := collider as Node
	while current != null:
		if current.is_in_group("doors") and current.has_method("interact"):
			return current as Node3D
		current = current.get_parent()
	return null


func _exit_penalty_and_knockout() -> void:
	# Akhiri hanya hukuman milik murid yang sedang mengerjakan soal.
	var punished_player := penalty_player
	_penalty_exam_active = false
	penalty_player = null

	if punished_player != null and is_instance_valid(punished_player):
		_set_player_knocked_out(punished_player)
	elif board_player != null and is_instance_valid(board_player):
		_set_player_knocked_out(board_player)
	else:
		var fallback_player := get_node_or_null("../Player/CharacterBody3D")
		if fallback_player != null:
			_set_player_knocked_out(fallback_player)

	# Buka kembali pintu ruang hukuman setelah ujian selesai.
	# Pemain tetap KO di tempatnya; hanya pintu terdekat dengan sofa ruang tamu yang dibuka.
	_open_penalty_room_door(punished_player)

	# Jangan mengubah fase global ke KO; murid lain tetap melanjutkan permainan.
	if phase != PHASE_FINISHED:
		_set_status("Kamu keluar dari hukuman dalam kondisi KO. Teman dapat memakai Medkit.")
	_update_objective()


func _open_penalty_room_door(player: Node) -> void:
	var sofa := get_node_or_null("../Furniture/GuestRoom_Furniture/FurnitureRoot/Sofa_03Seat")
	if sofa == null:
		sofa = get_node_or_null("../Map58_Furniture/GuestRoom_Furniture/FurnitureRoot/Sofa_03Seat")

	var reference_position := Vector3.ZERO
	if sofa is Node3D:
		reference_position = (sofa as Node3D).global_position
	elif player is Node3D:
		reference_position = (player as Node3D).global_position
	else:
		return

	var nearest_door: Node3D = null
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("doors"):
		if not candidate is Node3D or not candidate.has_method("interact"):
			continue
		var door := candidate as Node3D
		var distance := door.global_position.distance_squared_to(reference_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_door = door

	if nearest_door != null and nearest_door.has_method("is_open") and not bool(nearest_door.call("is_open")):
		# Aktor guru melewati pemeriksaan kunci pintu.
		var teacher := get_tree().get_first_node_in_group("teacher")
		nearest_door.call("interact", teacher)


func _set_player_knocked_out(player: Node) -> void:
	if player == null:
		return

	# Simpan titik tumbang supaya script gerak dapat mengunci posisi secara konsisten.
	if player is Node3D:
		player.set_meta("knocked_out_position", (player as Node3D).global_position)
	player.set_meta("knocked_out", true)
	if not knockout_players.has(player):
		knockout_players.append(player)

	player_knocked_out.emit(player)

	# Hitung pemain valid yang masih hidup, bukan sekadar memeriksa array KO.
	var alive_count := 0
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate):
			continue
		if not bool(candidate.get_meta("knocked_out", false)):
			alive_count += 1

	if alive_count < 1 and not get_tree().get_nodes_in_group("players").is_empty():
		game_result = "LOSE"
		_set_phase(PHASE_FINISHED)
		_set_teacher_mode(TEACHER, null)
		_set_status("SEMUA MURID KO. PERMAINAN BERAKHIR.")
		game_finished.emit()


func revive_player(target: Node, healer: Node) -> bool:
	if target == null or healer == null:
		return false

	if not target.get_meta("knocked_out", false):
		return false

	var inventory := healer.get_node_or_null("ItemInventory")
	if inventory == null or not inventory.has_item("medkit"):
		return false

	inventory.consume_item_type("medkit")
	target.set_meta("knocked_out", false)
	target.remove_meta("knocked_out_position")
	knockout_players.erase(target)
	if penalty_player == target:
		penalty_player = null
	score -= 2
	player_revived.emit(target)

	if knockout_players.is_empty():
		target.set_meta("intro_locked", false)
		target.set_meta("intro_sitting", false)
		if mode_before_capture == BERSERK and is_instance_valid(target_before_capture):
			berserk_target = target_before_capture
		_set_phase(PHASE_HUNT)
		_set_teacher_mode(mode_before_capture, berserk_target if mode_before_capture == BERSERK else null)
		_set_status("Medkit berhasil digunakan. Guru kembali ke mode sebelum penangkapan.")
	else:
		_set_status("Teman berhasil dihidupkan.")

	return true


func register_spawned_paper() -> bool:
	if active_paper_count >= MAX_ACTIVE_PAPERS:
		return false

	active_paper_count += 1
	_update_objective()
	return true


func unregister_spawned_paper() -> void:
	active_paper_count = max(0, active_paper_count - 1)
	_update_objective()


func set_initial_active_papers(count: int) -> void:
	active_paper_count = clampi(count, 0, MAX_ACTIVE_PAPERS)
	_update_objective()


func _refresh_active_paper_count() -> void:
	active_paper_count = 0
	var scene_root := get_parent()
	if scene_root != null:
		_count_papers_recursive(scene_root)
	_update_objective()


func _count_papers_recursive(node: Node) -> void:
	if node == null:
		return

	if node is StaticBody3D and String(node.get_meta("item_type", "")) == "paper":
		active_paper_count += 1

	for child in node.get_children():
		_count_papers_recursive(child)


func _set_phase(new_phase: String) -> void:
	phase = new_phase
	phase_changed.emit(phase)
	_update_ui()


func _set_teacher_mode(mode: String, target: Node) -> void:
	teacher_mode = mode

	var teacher := get_node_or_null("../Teacher")
	if teacher != null:
		teacher.set_meta("teacher_mode", mode)
		teacher.set_meta("teacher_target", target)

	teacher_mode_changed.emit(mode, target)


func berserking_end() -> void:
	berserk_remaining = 0.0
	berserk_target = null


func _update_objective() -> void:
	objective_changed.emit(solved_papers, TOTAL_PAPERS_TO_ESCAPE)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "GameLogicUI"
	canvas.layer = 30
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	_phase_label = Label.new()
	_phase_label.position = Vector2(24, 20)
	_phase_label.add_theme_font_size_override("font_size", 18)
	root.add_child(_phase_label)

	_status_label = Label.new()
	_status_label.position = Vector2(24, 50)
	_status_label.add_theme_font_size_override("font_size", 16)
	root.add_child(_status_label)

	_objective_label = Label.new()
	_objective_label.position = Vector2(24, 80)
	_objective_label.add_theme_font_size_override("font_size", 16)
	root.add_child(_objective_label)

	_timer_label = Label.new()
	_timer_label.position = Vector2(24, 110)
	_timer_label.add_theme_font_size_override("font_size", 16)
	root.add_child(_timer_label)

	_quiz_label = Label.new()
	_quiz_label.set_anchors_preset(Control.PRESET_CENTER)
	_quiz_label.offset_left = -380.0
	_quiz_label.offset_top = -145.0
	_quiz_label.offset_right = 380.0
	_quiz_label.offset_bottom = 35.0
	_quiz_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quiz_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quiz_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quiz_label.add_theme_font_size_override("font_size", 20)
	_quiz_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_quiz_label)

	_answer_label = Label.new()
	_answer_label.set_anchors_preset(Control.PRESET_CENTER)
	_answer_label.offset_left = -170.0
	_answer_label.offset_top = 55.0
	_answer_label.offset_right = 170.0
	_answer_label.offset_bottom = 110.0
	_answer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_answer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_answer_label.add_theme_font_size_override("font_size", 26)
	_answer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_answer_label)

	# Overlay khusus penalti dibuat terpisah dari HUD biasa agar soal tetap jelas
	# terlihat setelah kamera dikembalikan dari animasi penangkapan.
	_penalty_exam_canvas = CanvasLayer.new()
	_penalty_exam_canvas.name = "PenaltyExamUI"
	# Menu/pengaturan UIManager berada di layer 40; soal hukuman harus di bawahnya
	# agar pengaturan tetap dapat tampil dan menerima sentuhan saat terbuka.
	_penalty_exam_canvas.layer = 35
	add_child(_penalty_exam_canvas)
	_penalty_exam_canvas.visible = false

	var penalty_dim := ColorRect.new()
	penalty_dim.name = "PenaltyDim"
	penalty_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	penalty_dim.color = Color(0.015, 0.012, 0.02, 0.82)
	penalty_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_penalty_exam_canvas.add_child(penalty_dim)

	var penalty_panel := PanelContainer.new()
	penalty_panel.name = "PenaltyPanel"
	penalty_panel.set_anchors_preset(Control.PRESET_CENTER)
	penalty_panel.offset_left = -420.0
	penalty_panel.offset_top = -190.0
	penalty_panel.offset_right = 420.0
	penalty_panel.offset_bottom = 190.0
	_penalty_exam_canvas.add_child(penalty_panel)

	var penalty_box := VBoxContainer.new()
	penalty_box.add_theme_constant_override("separation", 18)
	penalty_panel.add_child(penalty_box)

	var penalty_title := Label.new()
	penalty_title.name = "PenaltyTitle"
	penalty_title.text = "RUANG HUKUMAN"
	penalty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	penalty_title.add_theme_font_size_override("font_size", 28)
	penalty_box.add_child(penalty_title)

	_penalty_question_label = Label.new()
	_penalty_question_label.name = "PenaltyQuestion"
	_penalty_question_label.custom_minimum_size = Vector2(760, 130)
	_penalty_question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_penalty_question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_penalty_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_penalty_question_label.add_theme_font_size_override("font_size", 24)
	penalty_box.add_child(_penalty_question_label)

	_penalty_answer_label = Label.new()
	_penalty_answer_label.name = "PenaltyAnswer"
	_penalty_answer_label.text = "Ketik jawaban angka, lalu tekan ENTER"
	_penalty_answer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_penalty_answer_label.add_theme_font_size_override("font_size", 20)
	penalty_box.add_child(_penalty_answer_label)

	# Label saja tidak bisa menerima input sentuh/keyboard virtual di HP.
	_penalty_answer_input = LineEdit.new()
	_penalty_answer_input.name = "PenaltyAnswerInput"
	_penalty_answer_input.placeholder_text = "Masukkan jawaban angka"
	_penalty_answer_input.max_length = 12
	_penalty_answer_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_penalty_answer_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_penalty_answer_input.custom_minimum_size = Vector2(260, 48)
	_penalty_answer_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_penalty_answer_input.text_submitted.connect(_on_penalty_answer_submitted)
	penalty_box.add_child(_penalty_answer_input)

	var penalty_submit := Button.new()
	penalty_submit.name = "SubmitPenaltyAnswerButton"
	penalty_submit.text = "KIRIM JAWABAN"
	penalty_submit.custom_minimum_size = Vector2(220, 48)
	penalty_submit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	penalty_submit.pressed.connect(_on_penalty_submit_pressed)
	penalty_box.add_child(penalty_submit)

	_intro_paper_canvas = CanvasLayer.new()
	_intro_paper_canvas.name = "IntroPaperUI"
	_intro_paper_canvas.layer = 40
	add_child(_intro_paper_canvas)
	_intro_paper_canvas.visible = false

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.02, 0.018, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro_paper_canvas.add_child(overlay)

	_intro_paper_panel = PanelContainer.new()
	_intro_paper_panel.set_anchors_preset(Control.PRESET_CENTER)
	_intro_paper_panel.offset_left = -360.0
	_intro_paper_panel.offset_top = -285.0
	_intro_paper_panel.offset_right = 360.0
	_intro_paper_panel.offset_bottom = 285.0
	_intro_paper_canvas.add_child(_intro_paper_panel)

	var paper_box := VBoxContainer.new()
	paper_box.add_theme_constant_override("separation", 12)
	_intro_paper_panel.add_child(paper_box)

	var title := Label.new()
	title.text = "KERTAS SOAL — 20 DETIK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	paper_box.add_child(title)

	for i in range(INTRO_QUESTIONS):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		paper_box.add_child(row)

		var question_label := Label.new()
		question_label.name = "Question_%02d" % (i + 1)
		question_label.custom_minimum_size = Vector2(450, 42)
		question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		question_label.add_theme_font_size_override("font_size", 18)
		row.add_child(question_label)

		var edit := LineEdit.new()
		edit.name = "Answer_%02d" % (i + 1)
		edit.custom_minimum_size = Vector2(120, 42)
		edit.placeholder_text = "Jawaban"
		edit.max_length = 12
		edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(edit)
		_intro_answer_edits.append(edit)

	var hint := Label.new()
	hint.text = "Isi 5 jawaban pada kertas ini. Setelah selesai, tekan tombol selesai."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	paper_box.add_child(hint)

	var submit := Button.new()
	submit.name = "SubmitIntroPaperButton"
	submit.text = "SELESAI MENGERJAKAN"
	submit.custom_minimum_size = Vector2(0, 46)
	submit.mouse_filter = Control.MOUSE_FILTER_STOP
	submit.pressed.connect(_finish_intro_paper_early)
	paper_box.add_child(submit)


func _refresh_intro_paper_ui() -> void:
	if _intro_paper_panel == null:
		return
	var paper_box := _intro_paper_panel.get_child(0) as VBoxContainer
	if paper_box == null:
		return
	for i in range(INTRO_QUESTIONS):
		var row := paper_box.get_child(i + 1) as HBoxContainer
		if row == null:
			continue
		var label := row.get_node_or_null("Question_%02d" % (i + 1)) as Label
		if label != null and i < intro_questions.size():
			label.text = "%d. %s" % [i + 1, String(intro_questions[i].get("question", ""))]


func _update_ui() -> void:
	if _phase_label == null:
		return

	# HUD debug lama di bagian atas dihilangkan; skor tetap ditampilkan di hasil akhir.
	_phase_label.visible = false
	_objective_label.visible = false
	_timer_label.visible = false

	var active_timer := 0.0
	if phase == PHASE_INTRO_BRIEFING:
		active_timer = max(0.0, intro_briefing_remaining)
	elif phase == PHASE_INTRO_EXAM:
		active_timer = max(0.0, intro_remaining)
	elif phase == PHASE_TRANSITION:
		active_timer = max(0.0, transition_remaining)
	elif phase == PHASE_HUNT:
		active_timer = max(initial_teacher_remaining, calm_remaining, hunt_remaining, berserk_remaining)
	elif phase == PHASE_BOARD_SOLVING:
		active_timer = max(0.0, board_remaining)

	if _penalty_exam_canvas != null:
		var penalty_ui_active := _penalty_exam_active or phase == PHASE_PENALTY_EXAM
		_penalty_exam_canvas.visible = penalty_ui_active
		# Soal hukuman perlu kursor bebas agar kolom jawaban dan tombol bisa diklik.
		if penalty_ui_active:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if phase == PHASE_INTRO_BRIEFING:
		_quiz_label.text = "UJIAN AKAN DIMULAI\n\nKamu duduk di bangku ujian.\nSaat kertas muncul, isi jawaban untuk 5 soal.\nKamu memiliki waktu 20 detik.\n\nBersiaplah... " + str(maxi(0, int(ceil(intro_briefing_remaining))))
		_answer_label.text = ""
	elif phase == PHASE_INTRO_EXAM:
		_quiz_label.text = ""
		_answer_label.text = ""
		_refresh_intro_paper_ui()
	elif _penalty_exam_active or phase == PHASE_PENALTY_EXAM:
		for edit in _intro_answer_edits:
			edit.visible = false
		_quiz_label.text = ""
		_quiz_label.visible = false
		_answer_label.visible = false
		if _penalty_question_label != null:
			var question_text := String(current_question.get("question", "")).strip_edges()
			if question_text.is_empty():
				_penalty_question_label.text = "Soal sedang dimuat..."
			else:
				_penalty_question_label.text = question_text
		if _penalty_answer_label != null:
			_penalty_answer_label.text = "Jawab soal ini untuk melanjutkan."
		if _penalty_answer_input != null:
			_penalty_answer_input.visible = true
	else:
		_quiz_label.visible = true
		_answer_label.visible = true
		for edit in _intro_answer_edits:
			edit.visible = false
		_quiz_label.position = Vector2(-380, -145)
		_quiz_label.size = Vector2(760, 180)
		_quiz_label.text = ""


func _set_status(text_value: String) -> void:
	# Pesan status gameplay generik dinonaktifkan: sebelumnya menimpa minimap
	# dan berulang saat mengambil item, mengerjakan soal, atau tertangkap.
	# Notifikasi khusus perubahan mode guru/multiplayer ditangani terpisah.
	return


func _format_time(seconds_value: float) -> String:
	var total_seconds := maxi(0, int(ceil(seconds_value)))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
