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


func get_board_question(question_number: int, level: String = "") -> Dictionary:
	var difficulty := 3
	if question_number >= 3 and question_number <= 4:
		difficulty = 4
	elif question_number >= 5:
		difficulty = 5

	var candidates: Array = []
	if level != "":
		var level_questions := _filter_questions(level, 5, true)
		if level_questions.is_empty():
			level_questions = _filter_questions(level, 5, false)
		if level_questions.is_empty():
			push_warning("Tidak ada soal untuk mode room: " + level)
			return {}

		var min_difficulty := 1
		var max_difficulty := 5
		match level:
			"SD":
				min_difficulty = 1
				max_difficulty = 2
			"SMP":
				min_difficulty = 2
				max_difficulty = 3
			"SMA":
				min_difficulty = 3
				max_difficulty = 5
			"Dasar":
				min_difficulty = 4
				max_difficulty = 5
		var target_difficulty := clampi(difficulty, min_difficulty, max_difficulty)
		for value in level_questions:
			if int(value.get("difficulty", 1)) == target_difficulty:
				candidates.append(value)
		if candidates.is_empty():
			for value in level_questions:
				if int(value.get("difficulty", 1)) >= min_difficulty and int(value.get("difficulty", 1)) <= max_difficulty:
					candidates.append(value)
		if candidates.is_empty():
			candidates = level_questions
	else:
		candidates = _filter_questions_by_difficulty(difficulty, true)
		if candidates.is_empty():
			candidates = _filter_questions_by_difficulty(difficulty, false)

	var question := _pick_from_candidates(candidates, candidates)
	if not question.is_empty():
		session_stats["board_used"] += 1
	return question


func get_penalty_question(index: int, level: String = "SD") -> Dictionary:
	var max_difficulty := 2
	match level:
		"SMP":
			max_difficulty = 3
		"SMA", "Dasar":
			max_difficulty = 5
		"SD":
			max_difficulty = 2
	var candidates := _filter_questions(level, max_difficulty, true)
	if candidates.is_empty():
		candidates = _filter_questions(level, max_difficulty, false)

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

	var result: Dictionary = selected.duplicate(true)
	_localize_question_content(result)
	return result


func _localize_question_content(question: Dictionary) -> void:
	var localization: Variant = Engine.get_main_loop().root.get_node_or_null("Localization") if Engine.get_main_loop() is SceneTree else null
	if localization == null or not localization.has_method("get_language"):
		return
	if String(localization.call("get_language")) != "en":
		return

	var category_translations := {
		"Penjumlahan": "Addition", "Pengurangan": "Subtraction", "Perkalian": "Multiplication",
		"Pembagian": "Division", "Pecahan": "Fractions", "Geometri": "Geometry",
		"Waktu": "Time", "Uang": "Money", "Pola": "Patterns", "Satuan": "Units",
		"Operasi hitung": "Order of Operations", "Aljabar": "Algebra", "Persentase": "Percentages",
		"Perbandingan": "Ratios", "Pythagoras": "Pythagorean Theorem", "Bangun ruang": "Solid Geometry",
		"Statistika": "Statistics", "Pangkat": "Powers", "Akar": "Roots", "Persamaan": "Equations",
		"Koordinat": "Coordinates", "Sudut": "Angles", "KPK": "Least Common Multiple",
		"FPB": "Greatest Common Divisor", "Persamaan kuadrat": "Quadratic Equations",
		"Fungsi kuadrat": "Quadratic Functions", "Turunan": "Derivatives", "Integral": "Integrals",
		"Logaritma": "Logarithms", "Barisan aritmetika": "Arithmetic Sequences",
		"Barisan geometri": "Geometric Sequences", "Determinan": "Determinants",
		"Sistem persamaan": "Systems of Equations", "Kombinatorika": "Combinatorics",
		"Eksponen": "Exponents", "Fungsi linear": "Linear Functions", "Matriks": "Matrices",
		"Barisan": "Sequences", "Limit": "Limits", "Deret geometri": "Geometric Series",
		"Deret": "Series", "Permutasi": "Permutations", "Rekursi": "Recursion",
		"Eigenvalue": "Eigenvalues", "Deret kubik": "Cubic Series",
		"Barisan Fibonacci": "Fibonacci Sequence", "Bilangan kompleks": "Complex Numbers",
		"Vektor": "Vectors", "Persamaan diferensial": "Differential Equations",
		"Aljabar dan Logika": "Algebra and Logic", "Matematika Lanjutan": "Advanced Mathematics"
	}
	var category := String(question.get("category", ""))
	if category_translations.has(category):
		question["category"] = category_translations[category]

	var text := String(question.get("question", ""))
	var replacements := [
		["Sebuah persegi panjang berukuran", "A rectangle measures"],
		["Sebuah persegi memiliki sisi", "A square has a side length of"],
		["Berapa kelilingnya dalam cm?", "What is its perimeter in cm?"],
		["Berapa luasnya dalam cm²?", "What is its area in cm²?"],
		["Pukul ", "At "], [" ditambah ", " plus "], [" menit menjadi pukul berapa?", " minutes, what time will it be?"],
		["Tulis jamnya dalam format 24 jam tanpa tanda titik.", "Write the time in 24-hour format without punctuation."],
		[" dikurangi ", " minus "], [" sama dengan berapa rupiah?", " how many rupiah is that?"],
		["Ada ", "There are "], [" kantong. Setiap kantong berisi ", " bags. Each bag contains "],
		[" kelereng. Berapa kelereng semuanya?", " marbles. How many marbles are there in total?"],
		["Bilangan berikut: ", "The sequence is: "], [" Bilangan berikutnya adalah ...", " What is the next number?"],
		[" kotak masing-masing berisi ", " boxes each contain "], [" pensil. Berapa jumlah pensil seluruhnya?", " pencils. How many pencils are there in total?"],
		[" sama dengan berapa gram?", " how many grams?"], [" sama dengan berapa mililiter?", " how many milliliters?"],
		[" permen dibagikan sama rata kepada ", " candies are shared equally among "],
		[" anak. Setiap anak mendapat ... permen.", " children. How many candies does each child get?"],
		["Luas sebuah persegi adalah ", "The area of a square is "], [". Panjang sisinya adalah ... cm.", ". What is the length of its side in cm?"],
		["Setengah dari ", "Half of "], [" adalah ...", " is ..."],
		["Tiga perempat dari ", "Three quarters of "], ["Seperempat dari ", "One quarter of "],
		["Nilai x adalah ...", "The value of x is ..."], ["nilai x adalah ...", "the value of x is ..."],
		[" dari ", " of "], [" adalah ... cm².", " is ... cm²."],
		["Perbandingan A:B = ", "The ratio A:B is "], [". Jika A + B = ", ". If A + B = "],
		[", nilai A adalah ...", ", what is A?"],
		["Segitiga siku-siku memiliki sisi tegak ", "A right triangle has a vertical side of "],
		[" cm dan alas ", " cm and a base of "], [". Sisi miringnya adalah ... cm.", ". What is the hypotenuse in cm?"],
		["Luas segitiga dengan alas ", "The area of a triangle with base "], [" dan tinggi ", " and height "],
		[" adalah ... cm³.", " is ... cm³."], ["Balok berukuran ", "A rectangular prism measures "],
		[". Volumenya adalah ...", ". What is its volume?"],
		["Rata-rata dari ", "The average of "], [", dan ", ", and "], [" adalah ...", " is ..."],
		["Barisan ", "The sequence "], [". Suku ke-", ". What is the "],
		[" adalah ...", " is ..."], ["Sebuah barang berharga Rp", "An item costs Rp"],
		[" mendapat diskon ", " and has a "], ["%. Harga setelah diskon adalah ... rupiah.", "% discount. What is the price after the discount in rupiah?"],
		["Persegi panjang memiliki panjang ", "A rectangle has a length of "], [" dan lebar ", " and a width of "],
		[". Kelilingnya adalah ... cm.", ". What is its perimeter in cm?"],
		["Jarak vertikal dari titik ", "The vertical distance from point "], [" ke titik ", " to point "],
		[" adalah ... satuan.", " is ... units."], ["Dalam sebuah segitiga, dua sudutnya ", "In a triangle, two angles are "],
		["°. Sudut ketiga adalah ...°.", "°. What is the third angle?"],
		["Bunga sederhana ", "Simple interest of "], [" adalah ... rupiah.", " is ... rupiah."],
		["KPK dari ", "The least common multiple of "], [" dan ", " and "], ["FPB dari ", "The greatest common divisor of "],
		["Akar-akar ", "The roots of "], [" adalah 2 dan 3. Akar yang lebih kecil adalah ...", " are 2 and 3. What is the smaller root?"],
		["Untuk y = ", "For y = "], [", nilai x pada titik puncak adalah ...", ", what is the x-coordinate of the vertex?"],
		["Turunan f(x) = ", "The derivative of f(x) = "], [" pada x = ", " at x = "], [" bernilai ...", " is ..."],
		[" hingga ", " from 0 to "], [" dari ", " of "], ["Barisan dimulai ", "The sequence starts with "],
		["Jumlah ", "The sum of "], [" suku pertama adalah ...", " terms is ..."],
		["Banyak cara memilih ", "The number of ways to choose "], [" benda dari ", " objects from "],
		[" benda berbeda adalah ...", " distinct objects is ..."],
		["Bilangan ", "The number "], [" diduakalikan ", " is doubled "], [" kali berturut-turut. Hasil akhirnya adalah ...", " times in a row. What is the result?"],
		["Jika x = ", "If x = "], [", nilai y adalah ...", ", what is y?"],
		["Jejak (trace) matriks ", "The trace of matrix "], [" adalah ...", " is ..."],
		["Jumlah n bilangan ganjil pertama adalah ", "The sum of the first n odd numbers is "],
		["Jika f(x) = ", "If f(x) = "], [" maka f'(2) = ...", " then f'(2) = ..."],
		["lim x→", "lim x→"], ["Matriks diagonal ", "The diagonal matrix "], [" memiliki nilai eigen terbesar ...", " has the largest eigenvalue ..."],
		["Diberikan ", "Given "], ["Nilai a₃ adalah ...", "What is a₃?"],
		["Untuk matriks ", "For matrix "], [" elemen baris pertama kolom kedua setelah dikalikan dengan matriks itu sendiri sebanyak ", " what is the first-row, second-column element after multiplying the matrix by itself "],
		[" kali adalah ...", " times?"],
		["Sebuah lingkaran berjari-jari ", "A circle with radius "], [" memiliki luas ", " has an area of "],
		["Koefisien π adalah ...", "What is the coefficient of π?"],
		["Dengan F₁ = 1 dan F₂ = 1, nilai F₈ adalah ...", "Given F₁ = 1 and F₂ = 1, what is F₈?"],
		["Modulus dari ", "The modulus of "], ["Panjang vektor ", "The length of vector "],
		["Diketahui dy/dx = ", "Given dy/dx = "], [" dan y(0) = ", " and y(0) = "], ["Nilai y(2) adalah ...", "What is y(2)?"],
		["Jika 3 buku berharga ", "If 3 books cost "], [", harga 5 buku = ?", ", how much do 5 books cost?"],
		["Perbandingan ", "The ratio "], [". Jika bagian pertama ", ". If the first part is "], [", bagian kedua = ?", ", what is the second part?"],
		["Luas persegi panjang ", "The area of a rectangle is "], [" dan panjang ", " and its length is "], [". Lebar = ?", ". What is its width?"],
		["Rata-rata ", "The average of "], [" adalah 9. x = ?", " is 9. What is x?"],
		["x = ?", "x = ?"]
	]
	for pair in replacements:
		text = text.replace(String(pair[0]), String(pair[1]))
	question["question"] = text
