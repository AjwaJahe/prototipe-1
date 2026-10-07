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
const INTRO_TIME := 20.0
const TRANSITION_TIME := 2.5
const PENALTY_QUESTIONS := 5
const INTRO_QUESTIONS := 5

@export var intro_level: String = "SD"
@export var board_level: String = "SMA"
@export var auto_start: bool = true

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

var transition_remaining: float = 0.0
var hunt_remaining: float = 0.0
var _ui_refresh_remaining: float = 0.0
var board_remaining: float = 0.0
var calm_remaining: float = 0.0
var berserk_remaining: float = 0.0

var active_paper_count: int = 0
var board_player: Node = null
var board_node: Node3D = null
var berserk_target: Node = null
var penalty_player: Node = null

var knockout_players: Array[Node] = []

var _status_label: Label
var _objective_label: Label
var _timer_label: Label
var _quiz_label: Label
var _answer_label: Label
var _intro_answer_edits: Array[LineEdit] = []
var _phase_label: Label
var _intro_paper_canvas: CanvasLayer
var _intro_paper_panel: PanelContainer
var _intro_paper_open := false
var _intro_answers_submitted := false
var game_result: String = ""


func _ready() -> void:
	_load_question_database()
	_build_ui()
	_refresh_active_paper_count()

	if auto_start:
		call_deferred("_start_game")


func _process(delta: float) -> void:
	match phase:
		PHASE_INTRO_EXAM:
			intro_remaining -= delta
			if intro_remaining <= 0.0:
				_finish_intro_exam()
		PHASE_TRANSITION:
			transition_remaining -= delta
			if transition_remaining <= 0.0:
				_start_hunt()
		PHASE_HUNT:
			if berserk_remaining > 0.0:
				berserk_remaining -= delta
				hunt_remaining -= delta
				if berserk_remaining <= 0.0 and teacher_mode == BERSERK:
					berserk_remaining = 0.0
					berserk_target = null
					_set_teacher_mode(GHOST, null)
					_set_status("Mode bersek berakhir. Guru kembali mengejar secara normal.")
				elif hunt_remaining <= 0.0 and berserk_remaining <= 0.0:
					_start_hunt()
			elif calm_remaining > 0.0:
				calm_remaining -= delta
				hunt_remaining -= delta
				if calm_remaining <= 0.0:
					calm_remaining = 0.0
					_start_hunt()
			elif hunt_remaining > 0.0:
				hunt_remaining -= delta
				if hunt_remaining <= 0.0:
					_start_hunt()
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
	knockout_players.clear()
	penalty_player = null
	intro_questions.clear()
	intro_answers.clear()
	_intro_answers_submitted = false
	game_result = ""
	if question_database != null:
		question_database.reset_session()
	intro_remaining = INTRO_TIME

	_set_phase(PHASE_INTRO_EXAM)
	_set_teacher_mode(TEACHER, null)
	_set_intro_locked(true)
	_prepare_intro_desk()
	_prepare_intro_paper()
	_set_status("Kertas soal dibagikan. Kamu punya 20 detik untuk mengisi 5 soal.")
	_update_objective()


func _load_question_database() -> void:
	var database_script := load("res://QuestionDatabase.gd") as Script
	if database_script == null:
		push_error("Map58Game: QuestionDatabase.gd tidak dapat dimuat.")
		return

	question_database = database_script.new() as RefCounted


func _prepare_intro_desk() -> void:
	var player := get_tree().get_first_node_in_group("players") as CharacterBody3D
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

	var paper_mesh := MeshInstance3D.new()
	paper_mesh.name = "PaperMesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.52, 0.018, 0.68)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.96, 0.94, 0.84, 1.0)
	material.roughness = 0.92
	box.material = material
	paper_mesh.mesh = box
	paper_mesh.position.y = 0.009
	paper.add_child(paper_mesh)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.52, 0.018, 0.68)
	collision.shape = shape
	collision.position.y = 0.009
	paper.add_child(collision)

	var label := Label3D.new()
	label.name = "IntroQuestions"
	label.position = Vector3(0.0, 0.018, 0.0)
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.font_size = 22
	label.pixel_size = 0.0014
	label.width = 280.0
	label.modulate = Color(0.08, 0.08, 0.07, 1.0)
	label.text = "KERTAS SOAL"
	paper.add_child(label)


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
	for i in range(INTRO_QUESTIONS):
		var question: Dictionary = question_database.get_random_question(intro_level, 2)
		if question.is_empty():
			push_error("Map58Game: bank soal SD tidak menyediakan 5 soal untuk kertas pembuka.")
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
	var label := paper.get_node_or_null("IntroQuestions") as Label3D
	if label == null:
		return
	var text_value := "KERTAS SOAL\n"
	for i in range(intro_questions.size()):
		text_value += "%d. %s\n" % [i + 1, String(intro_questions[i].get("question", ""))]
	label.text = text_value


func _finish_intro_exam() -> void:
	if phase != PHASE_INTRO_EXAM:
		return

	_submit_intro_paper_answers()
	_set_intro_locked(false)
	_hide_intro_paper()
	var player := get_tree().get_first_node_in_group("players") as CharacterBody3D
	if player != null:
		player.set_meta("intro_sitting", false)
	_close_nearest_class_door()
	_blackout_nearest_class_lights()
	_set_phase(PHASE_TRANSITION)
	transition_remaining = TRANSITION_TIME
	_set_teacher_mode(GHOST, null)
	_set_status("20 detik habis. Guru meninggalkan kelas dan melayang. Pintu tertutup, lampu padam...")
	_update_objective()


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
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	_submit_intro_paper_answers()
	_hide_intro_paper()
	_set_status("Jawaban kertas disimpan. Tunggu sampai 20 detik habis.")


func _set_intro_locked(locked: bool) -> void:
	var player := get_node_or_null("../Player/CharacterBody3D")
	if player != null:
		player.set_meta("intro_locked", locked)


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


func _collect_lights(node: Node, result: Array[Node]) -> void:
	if node is Light3D:
		result.append(node)
	for child in node.get_children():
		_collect_lights(child, result)


func _prepare_next_penalty_question() -> bool:
	if question_database == null:
		return false

	current_question = question_database.get_penalty_question(penalty_question_index)

	if current_question.is_empty():
		push_error("Map58Game: bank soal untuk penalti tidak tersedia.")
		return false

	_answer_label.text = ""
	return true


func _prepare_next_board_question(player: Node) -> bool:
	if question_database == null:
		return false

	current_question = question_database.get_board_question(solved_papers + 1)

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
	var supplied := answer_text.strip_edges()
	var expected := String(current_question.get("answer", "")).strip_edges()

	if supplied.is_empty():
		_set_status("Masukkan jawaban terlebih dahulu.")
		return

	if supplied == expected:
		if phase == PHASE_INTRO_EXAM:
			initial_exam_correct += 1
			score += 10
			_set_status("Benar. " + str(intro_question_index + 1) + "/" + str(INTRO_QUESTIONS))
		else:
			score += 10
			penalty_question_index += 1
			if penalty_question_index >= PENALTY_QUESTIONS:
				_exit_penalty_and_knockout()
				return
			_prepare_next_penalty_question()
			_set_status("Benar. " + str(penalty_question_index) + "/" + str(PENALTY_QUESTIONS))

	else:
		score -= 5
		if phase == PHASE_INTRO_EXAM:
			_set_status("Salah. Jawaban benar: " + expected)
		else:
			penalty_question_index += 1
			if penalty_question_index >= PENALTY_QUESTIONS:
				_exit_penalty_and_knockout()
				return
			_set_status("Salah. Lanjut soal " + str(penalty_question_index + 1) + "/" + str(PENALTY_QUESTIONS))

		if phase == PHASE_PENALTY_EXAM:
			if penalty_question_index < PENALTY_QUESTIONS:
				_prepare_next_penalty_question()
			return



func _begin_transition() -> void:
	_set_phase(PHASE_TRANSITION)
	transition_remaining = TRANSITION_TIME
	_set_teacher_mode(GHOST, null)
	_set_status("Guru mengamuk. Bersiap...")
	_update_objective()


func _start_hunt() -> void:
	_set_phase(PHASE_HUNT)
	berserking_end()
	calm_remaining = 0.0

	hunt_remaining = _initial_hunt_duration()
	_set_teacher_mode(GHOST, null)
	_set_status("Cari Kunci Kelas, Kertas Soal, dan Kapur.")
	_update_objective()


func _initial_hunt_duration() -> float:
	var duration_by_correct := 180.0 + float(min(initial_exam_correct, 4)) * 30.0
	return min(duration_by_correct, 300.0)


func begin_board_question(player: Node, board: Node3D) -> Dictionary:
	if phase != PHASE_HUNT and phase != PHASE_ESCAPE_READY:
		return {}

	if solved_papers >= TOTAL_PAPERS_TO_ESCAPE:
		return {}

	var inventory := player.get_node_or_null("ItemInventory")
	if inventory == null:
		return {}

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
	if inventory == null:
		return false

	var expected := String(current_question.get("answer", "")).strip_edges()
	var supplied := answer_text.strip_edges()

	_consume_used_board_items(inventory)

	if supplied == expected and not supplied.is_empty():
		score += 10
		solved_papers += 1
		active_paper_count = max(0, active_paper_count - 1)

		_set_status("Jawaban benar. Soal berikutnya akan muncul di lokasi baru.")
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
	berserk_remaining = BERSERK_TIME

	_set_phase(PHASE_HUNT)
	_set_teacher_mode(BERSERK, player)
	_set_status("SALAH. Guru masuk mode BERSEK selama 15 detik.")
	paper_respawn_requested.emit()
	_update_objective()
	return false


func _consume_used_board_items(inventory: Node) -> void:
	if inventory.has_method("consume_item_type"):
		inventory.consume_item_type("paper")
		inventory.consume_item_type("chalk")


func _board_timeout() -> void:
	if phase != PHASE_BOARD_SOLVING:
		return

	var player := board_player
	var inventory := player.get_node_or_null("ItemInventory") if player != null else null
	if inventory != null:
		_consume_used_board_items(inventory)

	active_paper_count = max(0, active_paper_count - 1)
	score -= 5
	paper_respawn_requested.emit()

	berserk_target = player
	_set_phase(PHASE_HUNT)
	_set_teacher_mode(GHOST, null)
	_set_status("Waktu habis. Guru mengejarmu lagi.")
	_update_objective()


func _start_calm_phase() -> void:
	_set_phase(PHASE_HUNT)
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
	_set_status("10 soal selesai. Guru kembali normal. Gerbang sekolah terbuka.")
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
	if player == null:
		return

	if phase == PHASE_FINISHED:
		return

	penalty_player = player
	berserk_target = null
	board_player = null
	board_node = null
	_set_phase(PHASE_PENALTY_EXAM)
	_set_teacher_mode(TEACHER, null)
	penalty_question_index = 0
	_prepare_next_penalty_question()
	_set_status("Tertangkap. Jawab 5 soal untuk keluar dari ruangan hukuman.")


func _exit_penalty_and_knockout() -> void:
	if penalty_player != null and is_instance_valid(penalty_player):
		_set_player_knocked_out(penalty_player)
	elif board_player != null and is_instance_valid(board_player):
		_set_player_knocked_out(board_player)
	else:
		var fallback_player := get_node_or_null("../Player/CharacterBody3D")
		if fallback_player != null:
			_set_player_knocked_out(fallback_player)

	_set_phase(PHASE_KO)
	_set_status("Kamu keluar dalam kondisi KO. Teman harus memakai Medkit.")
	_update_objective()


func _set_player_knocked_out(player: Node) -> void:
	if player == null:
		return

	player.set_meta("knocked_out", true)
	if not knockout_players.has(player):
		knockout_players.append(player)

	player_knocked_out.emit(player)

	var players := get_tree().get_nodes_in_group("players")
	if not players.is_empty():
		var all_knocked_out := true
		for candidate in players:
			if not bool(candidate.get_meta("knocked_out", false)):
				all_knocked_out = false
				break
		if all_knocked_out:
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
	knockout_players.erase(target)
	score -= 2
	player_revived.emit(target)

	if knockout_players.is_empty():
		_set_phase(PHASE_HUNT)
		_set_teacher_mode(GHOST, null)
		_set_status("Medkit berhasil digunakan. Kamu bisa berdiri lagi.")
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

	_intro_paper_canvas = canvas
	_intro_paper_canvas.visible = false

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.02, 0.018, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(overlay)

	_intro_paper_panel = PanelContainer.new()
	_intro_paper_panel.set_anchors_preset(Control.PRESET_CENTER)
	_intro_paper_panel.offset_left = -360.0
	_intro_paper_panel.offset_top = -285.0
	_intro_paper_panel.offset_right = 360.0
	_intro_paper_panel.offset_bottom = 285.0
	canvas.add_child(_intro_paper_panel)

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
	submit.text = "SELESAI MENGERJAKAN"
	submit.custom_minimum_size = Vector2(0, 46)
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

	_phase_label.text = "FASE: " + phase + " | SKOR: " + str(score)
	_objective_label.text = "SOAL SELESAI: " + str(solved_papers) + "/" + str(TOTAL_PAPERS_TO_ESCAPE) + " | KERTAS AKTIF: " + str(active_paper_count) + "/" + str(MAX_ACTIVE_PAPERS)

	var active_timer := 0.0
	if phase == PHASE_INTRO_EXAM:
		active_timer = max(0.0, intro_remaining)
	elif phase == PHASE_TRANSITION:
		active_timer = max(0.0, transition_remaining)
	elif phase == PHASE_HUNT:
		active_timer = max(calm_remaining, hunt_remaining, berserk_remaining)
	elif phase == PHASE_BOARD_SOLVING:
		active_timer = max(0.0, board_remaining)

	_timer_label.text = "WAKTU: " + _format_time(active_timer)

	if phase == PHASE_INTRO_EXAM:
		_quiz_label.text = ""
		_answer_label.text = ""
		_refresh_intro_paper_ui()
	elif phase == PHASE_PENALTY_EXAM:
		for edit in _intro_answer_edits:
			edit.visible = false
		_quiz_label.position = Vector2(-380, -145)
		_quiz_label.size = Vector2(760, 180)
		_quiz_label.text = "SOAL HUKUMAN  " + str(penalty_question_index + 1) + "/" + str(PENALTY_QUESTIONS) + "\n" + String(current_question.get("question", ""))
	else:
		for edit in _intro_answer_edits:
			edit.visible = false
		_quiz_label.position = Vector2(-380, -145)
		_quiz_label.size = Vector2(760, 180)
		_quiz_label.text = ""


func _set_status(text_value: String) -> void:
	if _status_label != null:
		_status_label.text = text_value


func _format_time(seconds_value: float) -> String:
	var total_seconds := maxi(0, int(ceil(seconds_value)))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
