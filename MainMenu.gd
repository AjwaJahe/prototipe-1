extends Control

## Main menu HUD Compass.
## Menu utama, pilihan karakter, undangan room teman, dan profil lokal.
## Pengaturan menyimpan volume dan layar penuh.

const GAME_SCENE_PATH := "res://main.tscn"
const SETTINGS_PATH := "user://menu_settings.cfg"
const PROFILE_PATH := "user://player_profile.cfg"
const INFO_DEFAULT := "Fitur ini belum tersedia di prototipe."

var _profile_name_input: LineEdit
var _profile_edit_mode := false

@onready var start_button: Button = %MulaiButton
@onready var character_button: Button = %KarakterButton
@onready var friend_button: Button = %TemanButton
@onready var account_button: Button = %AkunButton
@onready var settings_button: Button = %PengaturanButton
@onready var quit_button: Button = %KeluarButton
@onready var credits_button: Button = %KreditButton

@onready var settings_overlay: Control = %SettingsOverlay
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var language_option: OptionButton = %LanguageOption
@onready var settings_back_button: Button = %KembaliButton

@onready var info_overlay: Control = %InfoOverlay
@onready var info_title: Label = %InfoTitle
@onready var info_body: Label = %InfoBody
@onready var info_ok_button: Button = %InfoOkButton
@onready var margin_container: MarginContainer = $Margin
@onready var columns: HBoxContainer = $Margin/Columns
@onready var left_column: VBoxContainer = $Margin/Columns/Left
@onready var right_column: Control = $Margin/Columns/Right
@onready var title_label: Label = $Margin/Columns/Left/TitleBox/Title
@onready var subtitle_label: Label = $Margin/Columns/Left/TitleBox/Subtitle
@onready var room_flow: Control = $RoomFlow
@onready var character_select: Control = $CharacterSelect

var _starting := false
var _transitioning := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	settings_overlay.visible = false
	info_overlay.visible = false


	# Pulihkan seluruh aksi menu secara eksplisit; koneksi scene lama pernah terhapus.
	if not start_button.pressed.is_connected(_on_start_pressed): start_button.pressed.connect(_on_start_pressed)
	if not character_button.pressed.is_connected(_open_character_select): character_button.pressed.connect(_open_character_select)
	if not friend_button.pressed.is_connected(_open_friends): friend_button.pressed.connect(_open_friends)
	if not account_button.pressed.is_connected(_open_account): account_button.pressed.connect(_open_account)
	if not settings_button.pressed.is_connected(_open_settings): settings_button.pressed.connect(_open_settings)
	if not quit_button.pressed.is_connected(_on_quit_pressed): quit_button.pressed.connect(_on_quit_pressed)
	if not credits_button.pressed.is_connected(_open_credits): credits_button.pressed.connect(_open_credits)
	if not settings_back_button.pressed.is_connected(_close_settings): settings_back_button.pressed.connect(_close_settings)
	if not info_ok_button.pressed.is_connected(_close_info): info_ok_button.pressed.connect(_close_info)
	if not fullscreen_check.toggled.is_connected(_apply_fullscreen): fullscreen_check.toggled.connect(_apply_fullscreen)
	if not volume_slider.value_changed.is_connected(_on_volume_changed): volume_slider.value_changed.connect(_on_volume_changed)
	if not language_option.item_selected.is_connected(_on_language_selected): language_option.item_selected.connect(_on_language_selected)
	_setup_language_options()

	_load_settings()
	_load_profile()
	_setup_button_motion()
	get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()
	modulate.a = 0.0
	var intro := create_tween()
	intro.tween_property(self, "modulate:a", 1.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	start_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if settings_overlay.visible:
		_close_settings()
		get_viewport().set_input_as_handled()
	elif info_overlay.visible:
		if _profile_edit_mode:
			_profile_edit_mode = false
			info_ok_button.text = "OKE"
			info_overlay.visible = false
			start_button.grab_focus()
		else:
			_close_info()
		get_viewport().set_input_as_handled()


func _on_start_pressed() -> void:
	# Mulai Game membuka alur room terlebih dahulu; permainan dimulai dari lobi host.
	room_flow.open()


func _open_character_select() -> void:
	character_select.open()


func _open_credits() -> void:
	_show_info("KREDIT & SUMBER AUDIO", "Tekstur, karakter, furnitur, item, dan aset visual dibuat sendiri untuk Kelas Malam.\n\nAudio eksternal (CC0):\n• Langkah kaki, suara laci — FOSSarts\n• Pintu berderit — dleverett\n• Pintu lemari geser — Rudmer_Rotteveel\n• Handle pintu — XavizardKnight\n• Jumpscare & kunci — qubodup\n• Bisikan hantu — brktkrgll\n• Ambience malam — Yuval\n• Bunyi kemenangan — SFXMint\n• Efek horor — shelbyshark\n")
func _on_quit_pressed() -> void:
	get_tree().quit()


func _open_friends() -> void:
	# Fitur Teman menggunakan alur room agar pemain dapat mengundang teman lewat Room ID.
	room_flow.open()


func _open_account() -> void:
	_profile_edit_mode = true
	info_title.text = "PROFIL PEMAIN"
	info_body.text = "Nama profil disimpan di perangkat ini. Ini bukan akun online."
	if _profile_name_input == null:
		_profile_name_input = LineEdit.new()
		_profile_name_input.name = "ProfileNameInput"
		_profile_name_input.placeholder_text = "Masukkan nama pemain"
		_profile_name_input.max_length = 24
		_profile_name_input.custom_minimum_size.y = 42
		var box := info_body.get_parent()
		box.add_child(_profile_name_input)
		box.move_child(_profile_name_input, info_body.get_index() + 1)
	var cfg := ConfigFile.new()
	var saved_name := ""
	if cfg.load(PROFILE_PATH) == OK:
		saved_name = String(cfg.get_value("profile", "display_name", ""))
	_profile_name_input.text = saved_name
	_profile_name_input.visible = true
	info_ok_button.text = "SIMPAN"
	info_overlay.visible = true
	_profile_name_input.grab_focus()


func _show_info(title: String, body: String = INFO_DEFAULT) -> void:
	_profile_edit_mode = false
	if _profile_name_input != null:
		_profile_name_input.visible = false
	info_ok_button.text = "OKE"
	info_title.text = title
	info_body.text = body
	info_overlay.visible = true
	info_body.get_parent().get_parent().get_parent().custom_minimum_size.y = minf(get_viewport_rect().size.y - 64.0, 620.0)
	info_ok_button.grab_focus()


func _close_info() -> void:
	if _profile_edit_mode:
		var display_name := _profile_name_input.text.strip_edges() if _profile_name_input != null else ""
		if display_name.is_empty():
			info_body.text = "Nama tidak boleh kosong. Masukkan nama profil terlebih dahulu."
			if _profile_name_input != null:
				_profile_name_input.grab_focus()
			return
		var cfg := ConfigFile.new()
		cfg.set_value("profile", "display_name", display_name)
		var save_error := cfg.save(PROFILE_PATH)
		if save_error != OK:
			info_body.text = "Profil gagal disimpan (kode %d)." % save_error
			return
		get_tree().set_meta("kelas_malam_player_name", display_name)
		_profile_edit_mode = false
		info_ok_button.text = "OKE"
	info_overlay.visible = false
	start_button.grab_focus()


# ---------- Pengaturan ----------

func _open_settings() -> void:
	settings_overlay.visible = true
	volume_slider.grab_focus()


func _close_settings() -> void:
	settings_overlay.visible = false
	_save_settings()
	settings_button.grab_focus()


func _on_volume_changed(value: float) -> void:
	_apply_volume(value)


func _apply_volume(value: float) -> void:
	volume_value.text = "%d%%" % roundi(value * 100.0)
	AudioServer.set_bus_mute(0, value <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.001)))


func _apply_fullscreen(enabled: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var volume := 1.0
	var fullscreen := true
	if cfg.load(SETTINGS_PATH) == OK:
		volume = clampf(float(cfg.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
		fullscreen = bool(cfg.get_value("display", "fullscreen", true))
	volume_slider.set_value_no_signal(volume)
	_apply_volume(volume)
	fullscreen_check.set_pressed_no_signal(fullscreen)
	var language_code := String(cfg.get_value("language", "code", "id"))
	language_option.select(1 if language_code == "en" else 0)
	if has_node("/root/Localization"):
		get_node("/root/Localization").set_language(language_code)
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen != is_fullscreen:
		_apply_fullscreen(fullscreen)


func _load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return
	var display_name := String(cfg.get_value("profile", "display_name", "")).strip_edges()
	if not display_name.is_empty():
		get_tree().set_meta("kelas_malam_player_name", display_name)


func _on_language_selected(index: int) -> void:
	var language_code := "en" if index == 1 else "id"
	if has_node("/root/Localization"):
		get_node("/root/Localization").set_language(language_code)
	_save_settings()


func _setup_language_options() -> void:
	language_option.clear()
	language_option.add_item("Bahasa Indonesia", 0)
	language_option.add_item("English", 1)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "master_volume", volume_slider.value)
	cfg.set_value("display", "fullscreen", fullscreen_check.button_pressed)
	# Simpan bahasa dari pilihan menu juga, agar pengaturan tetap konsisten.
	cfg.set_value("language", "code", "en" if language_option.selected == 1 else "id")
	cfg.save(SETTINGS_PATH)


# ---------- Polesan visual dan responsivitas ----------

func _setup_button_motion() -> void:
	for button in [start_button, character_button, friend_button, account_button, settings_button, quit_button, settings_back_button, info_ok_button, credits_button]:
		button.pivot_offset = button.size * 0.5
		button.mouse_entered.connect(_animate_button.bind(button, true))
		button.mouse_exited.connect(_animate_button.bind(button, false))
		button.resized.connect(_center_button_pivot.bind(button))


func _center_button_pivot(button: Button) -> void:
	button.pivot_offset = button.size * 0.5


func _animate_button(button: Button, hovering: bool) -> void:
	if not is_instance_valid(button):
		return
	var target_scale := Vector2(1.025, 1.025) if hovering else Vector2.ONE
	var target_color := Color(1.0, 0.82, 0.82, 1.0) if hovering else Color.WHITE
	var tween := create_tween().set_parallel(true)
	tween.tween_property(button, "scale", target_scale, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", target_color, 0.12)


func _update_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.x < 920.0
	var narrow := viewport_size.x < 620.0
	right_column.visible = not compact
	left_column.custom_minimum_size.x = 0.0 if compact else 460.0
	margin_container.add_theme_constant_override("margin_left", 28 if compact else 72)
	margin_container.add_theme_constant_override("margin_right", 28 if compact else 72)
	margin_container.add_theme_constant_override("margin_top", 28 if viewport_size.y < 650.0 else 52)
	margin_container.add_theme_constant_override("margin_bottom", 24 if viewport_size.y < 650.0 else 42)
	left_column.add_theme_constant_override("separation", 16 if narrow else 24)
	title_label.add_theme_font_size_override("font_size", 38 if narrow else (52 if compact else 72))
	subtitle_label.add_theme_font_size_override("font_size", 14 if narrow else 18)
	for button in [start_button, character_button, friend_button, account_button, settings_button, quit_button]:
		button.custom_minimum_size.y = 46.0 if narrow else (52.0 if compact else 58.0)
	if viewport_size.y < 540.0:
		left_column.add_theme_constant_override("separation", 8)
