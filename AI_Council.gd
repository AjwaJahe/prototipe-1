extends Control

const BUS_PATH := "user://kelas_malam_ai_council.json"
const TASKS_PATH := "res://AI_TASKS.json"
const RESULTS_PATH := "res://AI_RESULTS.json"
const MAX_MESSAGES := 80

const AGENTS := {
	"susanto": {"name": "SUSANTO", "role": "Koordinator / implementasi"},
	"yanto": {"name": "YANTO", "role": "Verifikasi / audit"},
	"tono": {"name": "TONO", "role": "Risiko / keamanan perubahan"}
}

var messages: Array = []
var tasks: Array = []
var results: Array = []
var message_box: VBoxContainer
var task_box: VBoxContainer
var result_box: VBoxContainer
var status_label: Label
var input_edit: LineEdit
var task_edit: LineEdit
var agent_option: OptionButton
var last_bus_mtime := 0
var last_tasks_mtime := 0
var last_results_mtime := 0

func _ready() -> void:
	_build_ui()
	_load_bus()
	_load_tasks()
	_load_results()
	_ensure_seed()
	_refresh_all()
	set_process(true)

func _process(_delta: float) -> void:
	_reload_if_changed()

func _reload_if_changed() -> void:
	if FileAccess.file_exists(BUS_PATH):
		var mtime := FileAccess.get_modified_time(BUS_PATH)
		if mtime != last_bus_mtime:
			_load_bus()
			_refresh_messages()
	if FileAccess.file_exists(TASKS_PATH):
		var task_mtime := FileAccess.get_modified_time(TASKS_PATH)
		if task_mtime != last_tasks_mtime:
			_load_tasks()
			_refresh_tasks()
	if FileAccess.file_exists(RESULTS_PATH):
		var result_mtime := FileAccess.get_modified_time(RESULTS_PATH)
		if result_mtime != last_results_mtime:
			_load_results()
			_refresh_results()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#10131a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title := Label.new()
	title.text = "KELAS MALAM — AI COUNCIL ORCHESTRATOR"
	title.add_theme_font_size_override("font_size", 28)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Satu perintah → task bersama → verifikasi → hasil → implementasi"
	subtitle.add_theme_font_size_override("font_size", 15)
	root.add_child(subtitle)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	root.add_child(cards)
	for id in ["susanto", "yanto", "tono"]:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := Label.new()
		label.text = AGENTS[id]["name"] + "\n" + AGENTS[id]["role"]
		label.add_theme_font_size_override("font_size", 15)
		card.add_child(label)
		cards.add_child(card)

	var command_row := HBoxContainer.new()
	command_row.add_theme_constant_override("separation", 8)
	root.add_child(command_row)

	task_edit = LineEdit.new()
	task_edit.placeholder_text = "Perintah tim, contoh: Audit dan selesaikan sistem pintu guru"
	task_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_edit.text_submitted.connect(_create_team_task)
	command_row.add_child(task_edit)

	var dispatch := Button.new()
	dispatch.text = "BAGIKAN KE TIM"
	dispatch.pressed.connect(func(): _create_team_task(task_edit.text))
	command_row.add_child(dispatch)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 12)
	root.add_child(split)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	split.add_child(left)

	var task_title := Label.new()
	task_title.text = "TASK QUEUE"
	task_title.add_theme_font_size_override("font_size", 19)
	left.add_child(task_title)

	var task_scroll := ScrollContainer.new()
	task_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(task_scroll)
	task_box = VBoxContainer.new()
	task_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_scroll.add_child(task_box)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	split.add_child(right)

	var result_title := Label.new()
	result_title.text = "RESULTS / HANDOFF"
	result_title.add_theme_font_size_override("font_size", 19)
	right.add_child(result_title)

	var result_scroll := ScrollContainer.new()
	result_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(result_scroll)
	result_box = VBoxContainer.new()
	result_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_scroll.add_child(result_box)

	var council_title := Label.new()
	council_title.text = "SHARED COUNCIL MESSAGES"
	council_title.add_theme_font_size_override("font_size", 19)
	root.add_child(council_title)

	var council_scroll := ScrollContainer.new()
	council_scroll.custom_minimum_size.y = 170
	root.add_child(council_scroll)
	message_box = VBoxContainer.new()
	message_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	council_scroll.add_child(message_box)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	root.add_child(controls)

	agent_option = OptionButton.new()
	agent_option.add_item("Susanto", 0)
	agent_option.add_item("Yanto", 1)
	agent_option.add_item("Tono", 2)
	controls.add_child(agent_option)

	input_edit = LineEdit.new()
	input_edit.placeholder_text = "Pesan ke council..."
	input_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_edit.text_submitted.connect(_on_submit)
	controls.add_child(input_edit)

	var send := Button.new()
	send.text = "KIRIM"
	send.pressed.connect(func(): _on_submit(input_edit.text))
	controls.add_child(send)

	var reload := Button.new()
	reload.text = "MUAT ULANG"
	reload.pressed.connect(_reload_all)
	controls.add_child(reload)

	status_label = Label.new()
	status_label.text = "Orchestrator siap."
	root.add_child(status_label)

func _ensure_seed() -> void:
	if messages.is_empty():
		messages = [
			{"agent": "susanto", "text": "Orchestrator aktif. Aku menjadi koordinator task."},
			{"agent": "yanto", "text": "Aku menangani verifikasi dan audit file aktual."},
			{"agent": "tono", "text": "Aku menangani risiko, dependency, dan keamanan perubahan."}
		]
		_save_bus()

func _create_team_task(text_value: String) -> void:
	var clean := text_value.strip_edges()
	if clean.is_empty():
		return
	var id := "task_" + str(Time.get_unix_time_from_system())
	var task := {
		"id": id,
		"command": clean,
		"status": "queued",
		"created_by": "user",
		"created_at": Time.get_datetime_string_from_system(true),
		"assignments": {
			"susanto": "Koordinasi, desain implementasi, dan perubahan yang diperlukan.",
			"yanto": "Audit file aktual, dependency, konflik, dan verifikasi hasil.",
			"tono": "Review risiko, dampak, rollback, dan validasi keamanan perubahan."
		}
	}
	tasks.append(task)
	_save_tasks()
	messages.append({"agent": "susanto", "text": "TASK TIM BARU: " + clean})
	_save_bus()
	task_edit.clear()
	_refresh_all()

func _on_submit(text_value: String) -> void:
	var clean := text_value.strip_edges()
	if clean.is_empty():
		return
	var id := ["susanto", "yanto", "tono"][agent_option.selected]
	messages.append({"agent": id, "text": clean})
	if messages.size() > MAX_MESSAGES:
		messages = messages.slice(messages.size() - MAX_MESSAGES, messages.size())
	_save_bus()
	input_edit.clear()
	_refresh_messages()

func _load_bus() -> void:
	if not FileAccess.file_exists(BUS_PATH):
		return
	var file := FileAccess.open(BUS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		messages = parsed
	last_bus_mtime = FileAccess.get_modified_time(BUS_PATH)

func _save_bus() -> void:
	var file := FileAccess.open(BUS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(messages, "\t"))
	file.close()
	last_bus_mtime = FileAccess.get_modified_time(BUS_PATH)

func _load_tasks() -> void:
	if not FileAccess.file_exists(TASKS_PATH):
		tasks = []
		return
	var file := FileAccess.open(TASKS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		tasks = parsed
	last_tasks_mtime = FileAccess.get_modified_time(TASKS_PATH)

func _save_tasks() -> void:
	var file := FileAccess.open(TASKS_PATH, FileAccess.WRITE)
	if file == null:
		status_label.text = "Gagal menulis AI_TASKS.json"
		return
	file.store_string(JSON.stringify(tasks, "\t"))
	file.close()
	last_tasks_mtime = FileAccess.get_modified_time(TASKS_PATH)

func _load_results() -> void:
	if not FileAccess.file_exists(RESULTS_PATH):
		results = []
		return
	var file := FileAccess.open(RESULTS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		results = parsed
	last_results_mtime = FileAccess.get_modified_time(RESULTS_PATH)

func _refresh_all() -> void:
	_refresh_tasks()
	_refresh_results()
	_refresh_messages()
	status_label.text = "Orchestrator aktif | Task: " + str(tasks.size()) + " | Result: " + str(results.size())

func _refresh_tasks() -> void:
	if task_box == null:
		return
	for child in task_box.get_children():
		child.queue_free()
	for task in tasks:
		if not task is Dictionary:
			continue
		var panel := PanelContainer.new()
		var label := Label.new()
		label.text = "[" + String(task.get("status", "queued")).to_upper() + "] " + String(task.get("id", "")) + "\n" + String(task.get("command", ""))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 15)
		panel.add_child(label)
		task_box.add_child(panel)

func _refresh_results() -> void:
	if result_box == null:
		return
	for child in result_box.get_children():
		child.queue_free()
	for result in results:
		if not result is Dictionary:
			continue
		var panel := PanelContainer.new()
		var label := Label.new()
		label.text = String(result.get("agent", "unknown")).to_upper() + " | " + String(result.get("task_id", "")) + "\n" + String(result.get("summary", ""))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 14)
		panel.add_child(label)
		result_box.add_child(panel)

func _refresh_messages() -> void:
	if message_box == null:
		return
	for child in message_box.get_children():
		child.queue_free()
	for msg in messages:
		if not msg is Dictionary:
			continue
		var id := String(msg.get("agent", "susanto"))
		var data = AGENTS.get(id, {"name": id})
		var panel := PanelContainer.new()
		var label := Label.new()
		label.text = String(data["name"]) + ": " + String(msg.get("text", ""))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 14)
		panel.add_child(label)
		message_box.add_child(panel)

func _reload_all() -> void:
	_load_bus()
	_load_tasks()
	_load_results()
	_refresh_all()
