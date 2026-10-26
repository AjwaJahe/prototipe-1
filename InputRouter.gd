extends Node
## Pusat keputusan mode input. Tidak menangani/mengonsumsi event GUI;
## hanya menyatakan jalur input yang aktif agar kontrol tidak saling mengambil alih.

enum Mode { AUTO, DESKTOP, MOBILE }

var mode: int = Mode.AUTO
var preview_override := false
var touch_seen := false

func configure(selected_mode: int, preview_active: bool = false) -> void:
	mode = clampi(selected_mode, Mode.AUTO, Mode.MOBILE)
	preview_override = preview_active
	# Setiap pergantian mode membuang deteksi sentuhan lama; mode aktif yang baru
	# menjadi satu-satunya sumber keputusan sampai ada sentuhan baru pada AUTO.
	touch_seen = false

func register_touch() -> void:
	# Sentuhan pada laptop/PC tidak boleh mengubah mode AUTO menjadi HP.
	# Perangkat desktop tetap Desktop; mode HP otomatis hanya pada Android/iOS.
	if mode == Mode.MOBILE or preview_override:
		touch_seen = true
	elif mode == Mode.AUTO:
		var platform := OS.get_name()
		if platform == "Android" or platform == "iOS":
			touch_seen = true

func is_mobile_mode() -> bool:
	if mode == Mode.DESKTOP:
		return false
	if mode == Mode.MOBILE or preview_override or touch_seen:
		return true
	# AUTO memilih berdasarkan platform. Laptop layar sentuh tetap dapat memilih
	# Komputer secara eksplisit tanpa langsung dipaksa ke kontrol HP.
	var platform := OS.get_name()
	return platform == "Android" or platform == "iOS"

func accepts_mouse_as_mobile_input() -> bool:
	return is_mobile_mode() and not (OS.get_name() == "Android" or OS.get_name() == "iOS")
