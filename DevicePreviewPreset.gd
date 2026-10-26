@tool
extends Node
## Editor-only helper: pilih preset perangkat di Inspector lalu tekan Apply.

@export_enum(
	"Desktop (1152 x 648)",
	"Android Portrait (720 x 1280)",
	"Android Tall (720 x 1600)",
	"Android Compact (360 x 800)",
	"Android Landscape (1280 x 720)",
	"Tablet Portrait (1200 x 1920)"
)
var device_preset: int = 0

@export_tool_button("Terapkan Ukuran untuk F5")
var apply_preview_size: Callable = _apply_preview_size


func _apply_preview_size() -> void:
	if not Engine.is_editor_hint():
		return

	var sizes: Array[Vector2i] = [
		Vector2i(1152, 648),
		Vector2i(720, 1280),
		Vector2i(720, 1600),
		Vector2i(360, 800),
		Vector2i(1280, 720),
		Vector2i(1200, 1920),
	]
	var size: Vector2i = sizes[clampi(device_preset, 0, sizes.size() - 1)]

	ProjectSettings.set_setting("display/window/size/viewport_width", size.x)
	ProjectSettings.set_setting("display/window/size/viewport_height", size.y)
	ProjectSettings.set_setting("display/window/size/window_width_override", size.x)
	ProjectSettings.set_setting("display/window/size/window_height_override", size.y)

	var error: Error = ProjectSettings.save()
	if error != OK:
		push_error("DevicePreviewPreset: gagal menyimpan Project Settings (kode %d)." % error)
		return

	print("DevicePreviewPreset: ukuran F5 diterapkan: %d x %d." % [size.x, size.y])
