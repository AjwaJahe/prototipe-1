extends Node3D
## Menambahkan coretan cerita/petunjuk pada 11 papan kelas.
## Papan XII D sengaja dikecualikan karena dipakai untuk mekanik soal.

const BOARD_MESSAGES: Array[Dictionary] = [
	{"room": "Kelas_10_A_Furniture", "text": "DUNIA INI TIDAK NYATA...\nSelesaikan 10 soal untuk kabur!\nJangan percaya semua yang kamu lihat."},
	{"room": "Kelas_10_B_Furniture", "text": "GURU MENDENGAR LANGKAHMU\n...DAN JUGA SUARAMU.\nJangan berisik saat bersembunyi."},
	{"room": "Kelas_10_C_Furniture", "text": "PETUNJUK: Cari soal di papan XII D.\nTulis jawaban dengan kapur.\nPastikan bentuk angkanya jelas."},
	{"room": "Kelas_10_D_Furniture", "text": "JANGAN LARI TERUS!\nLari memang cepat, tapi langkahmu\nlebih mudah terdengar."},
	{"room": "Kelas_11_A_Furniture", "text": "Kalau guru mendekat, SEMBUNYI.\nPeti bisa melindungimu...\nasal kamu tidak membuat suara."},
	{"room": "Kelas_11_B_Furniture", "text": "10 JAWABAN BENAR = JALAN KELUAR\nSelesaikan semuanya, lalu cari\npintu gerbang sekolah."},
	{"room": "Kelas_11_C_Furniture", "text": "KAPUR + PAPAN = JAWABAN\nDekati papan XII D, tahan klik kiri\ndan gambar angkanya."},
	{"room": "Kelas_11_D_Furniture", "text": "JANGAN BIARKAN DIA MELIHATMU.\nPutuskan pandangan guru dan\nsegera cari tempat berlindung."},
	{"room": "Kelas_12_A_Furniture", "text": "Apa sekolah ini pernah nyata?\nJam terus berjalan, tapi lorong\nselalu terasa sama..." },
	{"room": "Kelas_12_B_Furniture", "text": "DENGARKAN SEKITARMU.\nSuara bisa membocorkan posisimu.\nBerjalanlah dengan hati-hati."},
	{"room": "Kelas_12_C_Furniture", "text": "JANGAN MENYERAH.\nSelesaikan soal satu demi satu.\nGerbang adalah satu-satunya jalan keluar."}
]

func _ready() -> void:
	call_deferred("_apply_board_writing")

func _apply_board_writing() -> void:
	var main_scene := get_parent()
	if main_scene == null:
		push_warning("BoardScribbles: parent scene tidak ditemukan.")
		return
	var furniture := main_scene.get_node_or_null("Furniture")
	if furniture == null:
		push_warning("BoardScribbles: node Furniture tidak ditemukan.")
		return

	for entry in BOARD_MESSAGES:
		var board := furniture.get_node_or_null(NodePath(str(entry["room"]) + "/FurnitureRoot/Whiteboard")) as Node3D
		if board == null:
			push_warning("BoardScribbles: papan tidak ditemukan: " + str(entry["room"]))
			continue
		if board.get_node_or_null("StoryScribbles") != null:
			continue

		var writing := Label3D.new()
		writing.name = "StoryScribbles"
		# Localization menerjemahkan Label3D dan tetap menyimpan teks asli untuk pergantian bahasa.
		writing.text = str(entry["text"])
		writing.position = Vector3(-0.081, -0.04, 0.0)
		writing.rotation = Vector3(0.0, -PI / 2.0, 0.0)
		writing.pixel_size = 0.005
		writing.font_size = 54
		writing.line_spacing = 0.82
		writing.modulate = Color(0.92, 0.89, 0.76, 0.96)
		writing.outline_size = 0
		writing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		writing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		writing.no_depth_test = false
		writing.shaded = false
		writing.double_sided = true
		board.add_child(writing)
