extends RefCounted

## Database soal lokal Map58.
## questions.json menjadi sumber data; script ini menangani pemilihan,
## anti-pengulangan, scaling kesulitan, dan validasi jawaban.

const DATABASE_PATH: String = "res://questions.json"

var data: Dictionary = {}
var questions: Array = []
var used_ids: Dictionary = {}
var session_stats := {
    "intro_used": 0,
    "board_used": 0,
    "penalty_used": 0
}
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

    var parsed: Variant = JSON.parse_string(file.get_as_text())
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


func reset_session() -> void:
    used_ids.clear()
    session_stats = {
        "intro_used": 0,
        "board_used": 0,
        "penalty_used": 0
    }


func get_question_count(level: String = "") -> int:
    return _filter_questions(level, 5, false).size()


func get_question_count_by_level(level: int) -> int:
    return _filter_questions_by_difficulty(level).size()


func get_intro_question(index: int) -> Dictionary:
    var question := _pick_from_candidates(
        _filter_questions("SD", 2, true),
        _filter_questions("SD", 2, false)
    )
    if question.is_empty():
        question = get_random_question("SD", 2)
    if not question.is_empty():
        session_stats["intro_used"] += 1
    return question


func get_board_question(question_number: int) -> Dictionary:
    var difficulty := 3
    if question_number >= 3 and question_number <= 4:
        difficulty = 4
    elif question_number >= 5:
        difficulty = 5

    var candidates := _filter_questions_by_difficulty(
        difficulty,
        true
    )
    if candidates.is_empty():
        candidates = _filter_questions_by_difficulty(
            difficulty,
            false
        )

    var question := _pick_from_candidates(candidates, candidates)
    if not question.is_empty():
        session_stats["board_used"] += 1
    return question


func get_penalty_question(index: int) -> Dictionary:
    var candidates := _filter_questions("SD", 2, true)
    if candidates.is_empty():
        candidates = _filter_questions("SD", 2, false)

    var question := _pick_from_candidates(candidates, candidates)
    if not question.is_empty():
        session_stats["penalty_used"] += 1
    return question


func get_random_question(level: String, max_difficulty: int = 5) -> Dictionary:
    var candidates := _filter_questions(level, max_difficulty, true)
    if candidates.is_empty():
        candidates = _filter_questions(level, max_difficulty, false)
    return _pick_from_candidates(candidates, candidates)


func check_answer(answer: float, correct_answer: Variant) -> bool:
    var expected := float(correct_answer)
    return absf(answer - expected) <= 0.01


func check_answer_multiple(answer: float, correct_answers: Array) -> bool:
    for value in correct_answers:
        if check_answer(answer, value):
            return true
    return false


func validate_answer_text(answer_text: String, question: Dictionary) -> bool:
    var supplied := answer_text.strip_edges()
    if supplied.is_empty():
        return false

    var multiple: Variant = question.get("answers", null)
    if multiple is Array:
        return check_answer_multiple(float(supplied), multiple)

    return check_answer(float(supplied), question.get("answer", 0))
    

func get_statistics() -> Dictionary:
    return session_stats.duplicate(true)


func _filter_questions(
    level: String,
    max_difficulty: int,
    exclude_used: bool
) -> Array:
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


func _filter_questions_by_difficulty(
    difficulty: int,
    exclude_used: bool = false
) -> Array:
    var result: Array = []

    for value in questions:
        if not value is Dictionary:
            continue

        var question: Dictionary = value
        if int(question.get("difficulty", 1)) != difficulty:
            continue

        var id := String(question.get("id", ""))
        if exclude_used and not id.is_empty() and used_ids.has(id):
            continue

        result.append(question)

    return result


func _pick_from_candidates(
    primary: Array,
    fallback: Array
) -> Dictionary:
    var candidates := primary if not primary.is_empty() else fallback
    if candidates.is_empty():
        return {}

    var selected: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
    var id := String(selected.get("id", ""))
    if not id.is_empty():
        used_ids[id] = true

    return selected.duplicate(true)
