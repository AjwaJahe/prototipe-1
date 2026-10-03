extends RefCounted

const DATABASE_PATH: String = "res://questions.json"

var data: Dictionary = {}
var questions: Array = []
var used_ids: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()
	_load()


func _load() -> bool:
	if not FileAccess.file_exists(DATABASE_PATH):
		push_error("Question database tidak ditemukan: " + DATABASE_PATH)
		return false

	var file := FileAccess.open(DATABASE_PATH, FileAccess.READ)
	if file == null:
		push_error("Tidak dapat membuka question database.")
		return false

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if not parsed is Dictionary:
		push_error("questions.json tidak berisi JSON object yang valid.")
		return false

	data = parsed
	var question_value: Variant = data.get("questions", [])
	if not question_value is Array:
		push_error("Field 'questions' pada questions.json tidak valid.")
		return false

	questions = question_value
	return true


func get_question_count(level: String = "") -> int:
	return _filter_questions(level, 5, false).size()


func get_random_question(level: String, max_difficulty: int = 5) -> Dictionary:
	var candidates: Array = _filter_questions(level, max_difficulty, true)

	if candidates.is_empty():
		candidates = _filter_questions(level, max_difficulty, false)

	if candidates.is_empty():
		return {}

	var index := rng.randi_range(0, candidates.size() - 1)
	var selected: Dictionary = candidates[index]
	used_ids[String(selected.get("id", ""))] = true
	return selected.duplicate(true)


func reset_used_questions() -> void:
	used_ids.clear()


func _filter_questions(level: String, max_difficulty: int, exclude_used: bool) -> Array:
	var result: Array = []

	for value in questions:
		if not value is Dictionary:
			continue

		var question: Dictionary = value
		if level != "" and String(question.get("level", "")) != level:
			continue

		var difficulty := int(question.get("difficulty", 1))
		if difficulty > max_difficulty:
			continue

		var id := String(question.get("id", ""))
		if exclude_used and not id.is_empty() and used_ids.has(id):
			continue

		result.append(question)

	return result
