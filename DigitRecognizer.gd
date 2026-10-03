extends RefCounted


const GRID_WIDTH: int = 24
const GRID_HEIGHT: int = 32

const MIN_POINTS: int = 4
const MAX_DIGITS: int = 6

const MIN_CONFIDENCE: float = 0.32
const MIN_MARGIN: float = 0.004

const MAX_HORIZONTAL_GAP_RATIO: float = 0.30


var templates: Dictionary = {}


func _init() -> void:
	_build_templates()


func recognize_strokes(
	strokes: Array
) -> Dictionary:

	var usable: Array = []


	for value in strokes:

		if not value is PackedVector2Array:
			continue


		var stroke: PackedVector2Array = (
			value
		)


		if stroke.size() >= 2:
			usable.append(
				stroke
			)


	if usable.is_empty():

		return {
			"ok": false,
			"text": "",
			"score": 0.0
		}


	var groups: Array = (
		_group_strokes(
			usable
		)
	)


	if groups.is_empty():
		return {
			"ok": false,
			"text": "",
			"score": 0.0
		}


	if groups.size() > MAX_DIGITS:
		return {
			"ok": false,
			"text": "",
			"score": 0.0
		}


	var text_result: String = ""
	var total_score: float = 0.0


	for group_value in groups:

		if not group_value is Array:
			continue


		var group: Array = (
			group_value
		)


		var points: PackedVector2Array = (
			PackedVector2Array()
		)


		for index_value in group:

			var index: int = int(
				index_value
			)


			if (
				index < 0
				or
				index >= usable.size()
			):
				continue


			var stroke: PackedVector2Array = (
				usable[index]
			)


			for point in stroke:

				points.append(
					point
				)


		if points.size() < MIN_POINTS:

			return {
				"ok": false,
				"text": text_result,
				"score": 0.0
			}


		var digit_result: Dictionary = (
			_recognize_digit(
				points,
				group.size()
			)
		)


		if not bool(
			digit_result.get(
				"ok",
				false
			)
		):

			return {
				"ok": false,
				"text": text_result,
				"score": total_score
			}


		text_result += String(
			digit_result.get(
				"digit",
				""
			)
		)


		total_score += float(
			digit_result.get(
				"confidence",
				0.0
			)
		)


	var average_score: float = (
		total_score
		/
		float(
			maxi(
				1,
				groups.size()
			)
		)
	)


	return {
		"ok": text_result.length() > 0,
		"text": text_result,
		"score": average_score
	}


func _group_strokes(
	strokes: Array
) -> Array:

	var rects: Array = []
	var order: Array = []


	for i in range(
		strokes.size()
	):

		var stroke: PackedVector2Array = (
			strokes[i]
		)


		rects.append(
			_bounds(stroke)
		)


		order.append(i)


	# Sort berdasarkan X.
	for i in range(
		order.size()
	):

		for j in range(
			i + 1,
			order.size()
		):

			var left_index: int = (
				int(order[i])
			)


			var right_index: int = (
				int(order[j])
			)


			var left_rect: Rect2 = (
				rects[left_index]
			)


			var right_rect: Rect2 = (
				rects[right_index]
			)


			if (
				right_rect.position.x
				<
				left_rect.position.x
			):

				var temp: int = (
					order[i]
				)


				order[i] = (
					order[j]
				)


				order[j] = temp


	var groups: Array = []


	for index_value in order:

		var index: int = (
			int(index_value)
		)


		var current_rect: Rect2 = (
			rects[index]
		)


		var attached: bool = false


		if not groups.is_empty():

			var last_group: Array = (
				groups[
					groups.size() - 1
				]
			)


			var group_right: float = -INF
			var group_top: float = INF
			var group_bottom: float = -INF


			for member_value in last_group:

				var member: int = (
					int(member_value)
				)


				var rect: Rect2 = (
					rects[member]
				)


				group_right = maxf(
					group_right,
					rect.end.x
				)


				group_top = minf(
					group_top,
					rect.position.y
				)


				group_bottom = maxf(
					group_bottom,
					rect.end.y
				)


			var group_height: float = maxf(
				1.0,
				group_bottom - group_top
			)


			var gap: float = (
				current_rect.position.x
				-
				group_right
			)


			var vertical_overlap: float = (
				minf(
					current_rect.end.y,
					group_bottom
				)
				-
				maxf(
					current_rect.position.y,
					group_top
				)
			)


			var overlap_ratio: float = (
				vertical_overlap
				/
				maxf(
					1.0,
					minf(
						current_rect.size.y,
						group_height
					)
				)
			)


			if (
				gap
				<=
				group_height
				*
				MAX_HORIZONTAL_GAP_RATIO
				and
				overlap_ratio >= 0.25
			):

				last_group.append(
					index
				)


				groups[
					groups.size() - 1
				] = last_group


				attached = true


		if not attached:

			groups.append(
				[index]
			)


	return groups


func recognize_against_answer(
	strokes: Array,
	expected_answer: String
) -> Dictionary:

	var usable: Array = []

	for value in strokes:
		if not value is PackedVector2Array:
			continue

		var stroke: PackedVector2Array = value as PackedVector2Array

		if stroke.size() >= 2:
			usable.append(stroke)

	var expected: String = expected_answer.strip_edges()

	if usable.is_empty() or expected.is_empty():
		return {
			"ok": false,
			"text": "",
			"score": 0.0
		}

	# Soal sudah mengetahui jawaban yang benar.
	# Untuk jawaban angka, kita ukur kemiripan tulisan dengan digit yang
	# memang diharapkan, bukan memaksa classifier menebak semua 0-9.
	for character in expected:
		if not "0123456789".contains(character):
			return recognize_strokes(strokes)

	var expected_digits: int = expected.length()
	var sorted_indices: Array = []

	for i in range(usable.size()):
		sorted_indices.append(i)

	# Urutkan stroke dari kiri ke kanan.
	for i in range(sorted_indices.size()):
		for j in range(i + 1, sorted_indices.size()):
			var left_index: int = int(sorted_indices[i])
			var right_index: int = int(sorted_indices[j])

			var left_rect: Rect2 = _bounds(usable[left_index])
			var right_rect: Rect2 = _bounds(usable[right_index])

			if right_rect.position.x < left_rect.position.x:
				var swap_value: int = left_index
				sorted_indices[i] = right_index
				sorted_indices[j] = swap_value

	if usable.size() < expected_digits:
		return {
			"ok": false,
			"text": "",
			"score": 0.0
		}

	# Dynamic programming mencoba pembagian stroke yang berurutan.
	# Ini lebih stabil daripada satu aturan jarak/gap tetap.
	var neg_inf: float = -INF
	var dp: Array = []
	var parent: Array = []

	for d in range(expected_digits + 1):
		var row: Array = []
		var parent_row: Array = []

		for s in range(usable.size() + 1):
			row.append(neg_inf)
			parent_row.append(-1)

		dp.append(row)
		parent.append(parent_row)

	dp[0][0] = 0.0

	for d in range(1, expected_digits + 1):
		var remaining_digits: int = expected_digits - d

		for end_index in range(d, usable.size() - remaining_digits + 1):
			var best_value: float = neg_inf

			for start_index in range(d - 1, end_index):
				var previous: float = float(dp[d - 1][start_index])

				if previous <= neg_inf * 0.5:
					continue

				var points: PackedVector2Array = PackedVector2Array()

				for k in range(start_index, end_index):
					var source_index: int = int(sorted_indices[k])

					for point in usable[source_index]:
						points.append(point)

				if points.size() < MIN_POINTS:
					continue

				var digit: String = expected.substr(d - 1, 1)
				var local_score: float = _expected_digit_similarity(
					points,
					digit
				)

				var segment_score: float = previous + local_score

				if segment_score > best_value:
					best_value = segment_score

				dp[d][end_index] = best_value

	if float(dp[expected_digits][usable.size()]) <= neg_inf * 0.5:
		return {
			"ok": false,
			"text": "",
			"score": 0.0
		}

	var average_score: float = (
		float(dp[expected_digits][usable.size()])
		/
		float(expected_digits)
	)

	# Jangan menerima hanya karena bentuk umum terlihat mirip.
	# Kita kombinasikan dua pemeriksaan:
	# 1) recognizer umum harus mengenali jawaban yang sama, ATAU
	# 2) kemiripan langsung terhadap jawaban benar harus sangat tinggi.
	# Ini menjaga toleransi tulisan tangan tanpa membuat hampir semua bentuk
	# dianggap benar.
	var generic_result: Dictionary = recognize_strokes(strokes)
	var generic_ok: bool = bool(generic_result.get("ok", false))
	var generic_text: String = String(generic_result.get("text", ""))
	var generic_score: float = float(generic_result.get("score", 0.0))

	if generic_ok and generic_text == expected:
		return {
			"ok": true,
			"text": expected,
			"score": maxf(average_score, generic_score)
		}

	# Untuk tulisan yang recognizer umum gagal kenali tetapi bentuknya
	# sangat dekat dengan jawaban yang benar, izinkan sebagai tulisan tangan.
	if average_score >= 0.90:
		return {
			"ok": true,
			"text": expected,
			"score": average_score
		}

	# Bila recognizer umum mengenali digit lain, kembalikan digit tersebut
	# agar soal dinilai SALAH, bukan BENAR atau "tidak terbaca".
	if generic_ok and not generic_text.is_empty():
		return {
			"ok": false,
			"text": generic_text,
			"score": generic_score
		}

	return {
		"ok": false,
		"text": "",
		"score": average_score
	}


func _expected_digit_similarity(
	points: PackedVector2Array,
	digit: String
) -> float:

	if not templates.has(digit):
		return 0.0

	if points.size() < MIN_POINTS:
		return 0.0

	var candidate: PackedByteArray = _rasterize(points)

	var candidate_features: Dictionary = _features(
		points,
		candidate,
		1
	)

	var best_score: float = 0.0
	var variants: Array = templates[digit]

	for variant_value in variants:
		if not variant_value is Dictionary:
			continue

		var variant: Dictionary = variant_value

		var shape_score: float = _shape_similarity(
			candidate,
			PackedByteArray(variant["mask"])
		)

		var feature_score: float = _feature_similarity(
			candidate_features,
			variant
		)

		var total: float = (
			shape_score * 0.72
			+
			feature_score * 0.28
		)

		best_score = maxf(best_score, total)

	return clampf(best_score, 0.0, 1.0)


func _recognize_digit(
	points: PackedVector2Array,
	stroke_count: int
) -> Dictionary:

	var candidate: PackedByteArray = (
		_rasterize(
			points
		)
	)


	var candidate_features: Dictionary = (
		_features(
			points,
			candidate,
			stroke_count
		)
	)


	var best_digit: String = ""
	var best_score: float = -INF
	var second_score: float = -INF


	for digit in templates.keys():

		var variants: Array = (
			templates[digit]
		)


		for variant_value in variants:

			if not variant_value is Dictionary:
				continue


			var variant: Dictionary = (
				variant_value
			)


			var shape_score: float = (
				_shape_similarity(
					candidate,
					PackedByteArray(
						variant["mask"]
					)
				)
			)


			var feature_score: float = (
				_feature_similarity(
					candidate_features,
					variant
				)
			)


			var total: float = (
				shape_score * 0.68
				+
				feature_score * 0.32
			)


			if total > best_score:

				second_score = best_score
				best_score = total
				best_digit = str(
					digit
				)

			elif total > second_score:

				second_score = total


	var margin: float = (
		best_score
		-
		second_score
	)


	var confidence: float = clampf(
		best_score,
		0.0,
		1.0
	)


	var accepted: bool = (
		confidence >= MIN_CONFIDENCE
		and
		margin >= MIN_MARGIN
	)


	return {
		"ok": accepted,
		"digit": best_digit,
		"confidence": confidence,
		"margin": margin
	}


func _build_templates() -> void:

	_add_digit_template(
		"0",
		[
			[
				Vector2(0.50, 0.03),
				Vector2(0.72, 0.10),
				Vector2(0.86, 0.28),
				Vector2(0.88, 0.52),
				Vector2(0.80, 0.76),
				Vector2(0.62, 0.92),
				Vector2(0.38, 0.92),
				Vector2(0.20, 0.80),
				Vector2(0.12, 0.56),
				Vector2(0.13, 0.30),
				Vector2(0.28, 0.10),
				Vector2(0.50, 0.03)
			]
		]
	)


	_add_digit_template(
		"1",
		[
			[
				Vector2(0.35, 0.22),
				Vector2(0.53, 0.06),
				Vector2(0.56, 0.93)
			],
			[
				Vector2(0.38, 0.93),
				Vector2(0.69, 0.93)
			]
		]
	)


	_add_digit_template(
		"2",
		[
			[
				Vector2(0.13, 0.21),
				Vector2(0.25, 0.09),
				Vector2(0.50, 0.05),
				Vector2(0.74, 0.12),
				Vector2(0.86, 0.28),
				Vector2(0.79, 0.43),
				Vector2(0.58, 0.55),
				Vector2(0.34, 0.70),
				Vector2(0.12, 0.93),
				Vector2(0.88, 0.93)
			]
		]
	)


	_add_digit_template(
		"3",
		[
			[
				Vector2(0.15, 0.10),
				Vector2(0.43, 0.05),
				Vector2(0.68, 0.09),
				Vector2(0.82, 0.23),
				Vector2(0.74, 0.39),
				Vector2(0.54, 0.47),
				Vector2(0.74, 0.54),
				Vector2(0.83, 0.70),
				Vector2(0.75, 0.86),
				Vector2(0.53, 0.94),
				Vector2(0.26, 0.91),
				Vector2(0.13, 0.80)
			]
		]
	)


	_add_digit_template(
		"4",
		[
			[
				Vector2(0.68, 0.05),
				Vector2(0.12, 0.64),
				Vector2(0.89, 0.64)
			],
			[
				Vector2(0.68, 0.05),
				Vector2(0.68, 0.94)
			]
		]
	)


	_add_digit_template(
		"4",
		[
			[
				Vector2(0.66, 0.06),
				Vector2(0.14, 0.65),
				Vector2(0.87, 0.65),
				Vector2(0.67, 0.06),
				Vector2(0.67, 0.94)
			]
		]
	)


	_add_digit_template(
		"5",
		[
			[
				Vector2(0.86, 0.08),
				Vector2(0.18, 0.08),
				Vector2(0.13, 0.44),
				Vector2(0.45, 0.42),
				Vector2(0.71, 0.48),
				Vector2(0.83, 0.64),
				Vector2(0.77, 0.83),
				Vector2(0.58, 0.94),
				Vector2(0.33, 0.94),
				Vector2(0.14, 0.82)
			]
		]
	)


	_add_digit_template(
		"6",
		[
			[
				Vector2(0.77, 0.08),
				Vector2(0.51, 0.05),
				Vector2(0.30, 0.18),
				Vector2(0.16, 0.40),
				Vector2(0.15, 0.68),
				Vector2(0.29, 0.87),
				Vector2(0.54, 0.94),
				Vector2(0.77, 0.83),
				Vector2(0.80, 0.65),
				Vector2(0.65, 0.54),
				Vector2(0.43, 0.51),
				Vector2(0.17, 0.61)
			]
		]
	)


	_add_digit_template(
		"7",
		[
			[
				Vector2(0.10, 0.08),
				Vector2(0.88, 0.08),
				Vector2(0.70, 0.28),
				Vector2(0.57, 0.54),
				Vector2(0.43, 0.94)
			]
		]
	)


	_add_digit_template(
		"8",
		[
			[
				Vector2(0.50, 0.05),
				Vector2(0.72, 0.10),
				Vector2(0.81, 0.25),
				Vector2(0.72, 0.42),
				Vector2(0.50, 0.49),
				Vector2(0.28, 0.42),
				Vector2(0.19, 0.25),
				Vector2(0.28, 0.10),
				Vector2(0.50, 0.05),
				Vector2(0.72, 0.56),
				Vector2(0.82, 0.73),
				Vector2(0.72, 0.89),
				Vector2(0.50, 0.95),
				Vector2(0.28, 0.89),
				Vector2(0.18, 0.73),
				Vector2(0.28, 0.56),
				Vector2(0.50, 0.49)
			]
		]
	)


	_add_digit_template(
		"9",
		[
			[
				Vector2(0.23, 0.48),
				Vector2(0.18, 0.31),
				Vector2(0.23, 0.14),
				Vector2(0.43, 0.05),
				Vector2(0.67, 0.10),
				Vector2(0.80, 0.28),
				Vector2(0.80, 0.54),
				Vector2(0.68, 0.77),
				Vector2(0.50, 0.92),
				Vector2(0.29, 0.89)
			]
		]
	)


	# Sedikit variasi bentuk.
	_add_digit_template(
		"2",
		[
			[
				Vector2(0.10, 0.18),
				Vector2(0.30, 0.07),
				Vector2(0.58, 0.08),
				Vector2(0.81, 0.22),
				Vector2(0.79, 0.40),
				Vector2(0.59, 0.55),
				Vector2(0.35, 0.71),
				Vector2(0.12, 0.93),
				Vector2(0.90, 0.93)
			]
		]
	)


	_add_digit_template(
		"7",
		[
			[
				Vector2(0.10, 0.09),
				Vector2(0.87, 0.09),
				Vector2(0.63, 0.39),
				Vector2(0.48, 0.67),
				Vector2(0.38, 0.94)
			]
		]
	)


func _add_digit_template(
	digit: String,
	stroke_data: Array
) -> void:

	var mask: PackedByteArray = (
		_rasterize_template(
			stroke_data
		)
	)


	var all_points: PackedVector2Array = (
		PackedVector2Array()
	)


	for stroke_value in stroke_data:

		if not stroke_value is Array:
			continue


		var stroke_points: Array = (
			stroke_value
		)


		for point_value in stroke_points:

			if point_value is Vector2:

				all_points.append(
					point_value
				)


	var features: Dictionary = (
		_features(
			all_points,
			mask,
			stroke_data.size()
		)
	)


	if not templates.has(digit):
		templates[digit] = []


	var digit_variants: Array = (
		templates[digit]
	)


	var variant: Dictionary = features

	variant["mask"] = mask
	variant["stroke_count"] = stroke_data.size()

	digit_variants.append(
		variant
	)


	templates[digit] = (
		digit_variants
	)


func _rasterize_template(
	stroke_data: Array
) -> PackedByteArray:

	var result: PackedByteArray = (
		_empty_mask()
	)


	for stroke_value in stroke_data:

		if not stroke_value is Array:
			continue


		var stroke: Array = (
			stroke_value
		)


		for i in range(
			stroke.size() - 1
		):

			var a_value: Variant = (
				stroke[i]
			)


			var b_value: Variant = (
				stroke[i + 1]
			)


			if (
				not a_value is Vector2
				or
				not b_value is Vector2
			):
				continue


			var a: Vector2 = (
				a_value as Vector2
			)


			var b: Vector2 = (
				b_value as Vector2
			)


			var pa: Vector2 = Vector2(
				a.x
				*
				float(GRID_WIDTH - 1),
				a.y
				*
				float(GRID_HEIGHT - 1)
			)


			var pb: Vector2 = Vector2(
				b.x
				*
				float(GRID_WIDTH - 1),
				b.y
				*
				float(GRID_HEIGHT - 1)
			)


			_draw_segment(
				result,
				pa,
				pb
			)


	return result


func _rasterize(
	points: PackedVector2Array
) -> PackedByteArray:

	var result: PackedByteArray = (
		_empty_mask()
	)


	var bounds: Rect2 = (
		_bounds(
			points
		)
	)


	if (
		bounds.size.x <= 0.001
		or
		bounds.size.y <= 0.001
	):
		return result


	var scale_value: float = (
		1.0
		/
		maxf(
			bounds.size.x,
			bounds.size.y
		)
	)


	var center: Vector2 = (
		bounds.position
		+
		bounds.size * 0.5
	)


	var normalized: PackedVector2Array = (
		PackedVector2Array()
	)


	for point in points:

		var local: Vector2 = (
			(point - center)
			*
			scale_value
		)


		local += Vector2(
			0.5,
			0.5
		)


		normalized.append(
			local
		)


	for i in range(
		normalized.size() - 1
	):

		_draw_segment(
			result,
			Vector2(
				normalized[i].x
				*
				float(GRID_WIDTH - 1),
				normalized[i].y
				*
				float(GRID_HEIGHT - 1)
			),
			Vector2(
				normalized[i + 1].x
				*
				float(GRID_WIDTH - 1),
				normalized[i + 1].y
				*
				float(GRID_HEIGHT - 1)
			)
		)


	return result


func _features(
	points: PackedVector2Array,
	mask: PackedByteArray,
	stroke_count: int
) -> Dictionary:

	var bounds: Rect2 = (
		_bounds(
			points
		)
	)


	var aspect: float = (
		bounds.size.x
		/
		maxf(
			bounds.size.y,
			0.001
		)
	)


	var closure: float = (
		_closure_ratio(
			points
		)
	)


	var top_ink: int = 0
	var middle_ink: int = 0
	var bottom_ink: int = 0

	var left_ink: int = 0
	var right_ink: int = 0

	var total_ink: int = 0


	for y in range(
		GRID_HEIGHT
	):

		for x in range(
			GRID_WIDTH
		):

			var index: int = (
				y
				*
				GRID_WIDTH
				+
				x
			)


			if mask[index] == 0:
				continue


			total_ink += 1


			if y < GRID_HEIGHT / 3:
				top_ink += 1

			elif y < (
				GRID_HEIGHT * 2 / 3
			):
				middle_ink += 1

			else:
				bottom_ink += 1


			if x < GRID_WIDTH / 2:
				left_ink += 1
			else:
				right_ink += 1


	var total_float: float = float(
		maxi(
			1,
			total_ink
		)
	)


	return {
		"aspect": aspect,
		"closure": closure,
		"top": float(top_ink) / total_float,
		"middle": float(middle_ink) / total_float,
		"bottom": float(bottom_ink) / total_float,
		"left": float(left_ink) / total_float,
		"right": float(right_ink) / total_float,
		"stroke_count": stroke_count
	}


func _feature_similarity(
	candidate: Dictionary,
	template: Dictionary
) -> float:

	var score: float = 0.0


	var candidate_aspect: float = float(
		candidate.get("aspect", 1.0)
	)


	var template_aspect: float = float(
		template.get("aspect", 1.0)
	)


	var aspect_difference: float = absf(
		log(
			maxf(candidate_aspect, 0.05)
			/
			maxf(template_aspect, 0.05)
		)
	)


	score += clampf(
		1.0 - aspect_difference,
		0.0,
		1.0
	) * 0.20


	var closure_difference: float = absf(
		float(candidate.get("closure", 1.0))
		-
		float(template.get("closure", 1.0))
	)


	score += clampf(
		1.0 - closure_difference,
		0.0,
		1.0
	) * 0.25


	score += _feature_difference(
		candidate,
		template,
		"top"
	) * 0.10


	score += _feature_difference(
		candidate,
		template,
		"middle"
	) * 0.10


	score += _feature_difference(
		candidate,
		template,
		"bottom"
	) * 0.10


	score += _feature_difference(
		candidate,
		template,
		"left"
	) * 0.075


	score += _feature_difference(
		candidate,
		template,
		"right"
	) * 0.075


	var candidate_strokes: int = int(
		candidate.get(
			"stroke_count",
			1
		)
	)


	var template_strokes: int = int(
		template.get(
			"stroke_count",
			1
		)
	)


	if candidate_strokes == template_strokes:
		score += 0.10
	else:
		score += 0.04


	return clampf(
		score / 0.995,
		0.0,
		1.0
	)


func _feature_difference(
	a: Dictionary,
	b: Dictionary,
	key: String
) -> float:

	var av: float = float(
		a.get(key, 0.0)
	)


	var bv: float = float(
		b.get(key, 0.0)
	)


	return clampf(
		1.0 - absf(av - bv),
		0.0,
		1.0
	)


func _shape_similarity(
	a: PackedByteArray,
	b: PackedByteArray
) -> float:

	var a_count: int = 0
	var b_count: int = 0

	var a_near_b: int = 0
	var b_near_a: int = 0


	for y in range(
		GRID_HEIGHT
	):

		for x in range(
			GRID_WIDTH
		):

			var index: int = (
				y
				*
				GRID_WIDTH
				+
				x
			)


			if a[index] > 0:

				a_count += 1


				if _has_nearby_ink(
					b,
					x,
					y,
					2
				):
					a_near_b += 1


			if b[index] > 0:

				b_count += 1


				if _has_nearby_ink(
					a,
					x,
					y,
					2
				):
					b_near_a += 1


	var recall_a: float = (
		float(a_near_b)
		/
		float(
			maxi(
				1,
				a_count
			)
		)
	)


	var recall_b: float = (
		float(b_near_a)
		/
		float(
			maxi(
				1,
				b_count
			)
		)
	)


	return clampf(
		(recall_a + recall_b) * 0.5,
		0.0,
		1.0
	)


func _has_nearby_ink(
	mask: PackedByteArray,
	x: int,
	y: int,
	radius: int
) -> bool:

	for oy in range(
		-radius,
		radius + 1
	):

		for ox in range(
			-radius,
			radius + 1
		):

			if (
				ox * ox
				+
				oy * oy
				>
				radius * radius
			):
				continue


			var xx: int = (
				x
				+
				ox
			)


			var yy: int = (
				y
				+
				oy
			)


			if (
				xx < 0
				or
				xx >= GRID_WIDTH
				or
				yy < 0
				or
				yy >= GRID_HEIGHT
			):
				continue


			var index: int = (
				yy
				*
				GRID_WIDTH
				+
				xx
			)


			if mask[index] > 0:
				return true


	return false


func _draw_segment(
	mask: PackedByteArray,
	a: Vector2,
	b: Vector2
) -> void:

	var distance: float = (
		a.distance_to(b)
	)


	var steps: int = maxi(
		2,
		int(
			ceil(
				distance * 2.0
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
			a.lerp(
				b,
				t
			)
		)


		_draw_pixel(
			mask,
			point
		)


func _draw_pixel(
	mask: PackedByteArray,
	point: Vector2
) -> void:

	var x: int = int(
		round(point.x)
	)


	var y: int = int(
		round(point.y)
	)


	for oy in range(
		-1,
		2
	):

		for ox in range(
			-1,
			2
		):

			var xx: int = (
				x
				+
				ox
			)


			var yy: int = (
				y
				+
				oy
			)


			if (
				xx < 0
				or
				xx >= GRID_WIDTH
				or
				yy < 0
				or
				yy >= GRID_HEIGHT
			):
				continue


			mask[
				yy
				*
				GRID_WIDTH
				+
				xx
			] = 1


func _empty_mask() -> PackedByteArray:
	var mask: PackedByteArray = (
		PackedByteArray()
	)


	mask.resize(
		GRID_WIDTH
		*
		GRID_HEIGHT
	)


	mask.fill(0)


	return mask


func _bounds(
	points: PackedVector2Array
) -> Rect2:

	if points.is_empty():
		return Rect2()


	var min_x: float = INF
	var min_y: float = INF

	var max_x: float = -INF
	var max_y: float = -INF


	for point in points:

		min_x = minf(
			min_x,
			point.x
		)


		min_y = minf(
			min_y,
			point.y
		)


		max_x = maxf(
			max_x,
			point.x
		)


		max_y = maxf(
			max_y,
			point.y
		)


	return Rect2(
		Vector2(
			min_x,
			min_y
		),
		Vector2(
			max_x - min_x,
			max_y - min_y
		)
	)


func _closure_ratio(
	points: PackedVector2Array
) -> float:

	if points.size() < 2:
		return 1.0


	var total_length: float = 0.0


	for i in range(
		points.size() - 1
	):

		total_length += (
			points[i].distance_to(
				points[i + 1]
			)
		)


	if total_length <= 0.001:
		return 1.0


	var distance_between_ends: float = (
		points[0].distance_to(
			points[
				points.size() - 1
			]
		)
	)


	return clampf(
		distance_between_ends
		/
		total_length,
		0.0,
		1.0
	)
