extends Control
## Character selection overlay with four distinct stylized student previews.
## Selection is saved locally and exposed as SceneTree metadata for game integration.

const SAVE_PATH := "user://character_selection.cfg"
const CHARACTER_NAMES := ["Raka", "Bima", "Naya", "Dito"]
const CHARACTER_DESCRIPTIONS := [
	"Siswa atletis • jaket gelap",
	"Siswa tinggi • hoodie longgar",
	"Siswi • rambut panjang dikuncir",
	"Siswa pendek • seragam rapi"
]
const SHIRT_COLORS := [
	Color("#3e596e"),
	Color("#6b5146"),
	Color("#7b526b"),
	Color("#65734e")
]
const HAIR_COLORS := [
	Color("#201b1b"),
	Color("#30231d"),
	Color("#241b19"),
	Color("#302820")
]

var _selected := 0
var _cards: Array[Button] = []
var _status_label: Label
var _content: VBoxContainer


class CharacterPreview extends Control:
	var character_index := 0
	var selected := false

	func _draw() -> void:
		var center_x := size.x * 0.5
		var base_y := size.y - 16.0
		var scale_factor := minf(size.x / 150.0, size.y / 190.0)
		var skin := Color("#b98262")
		var shirt: Color = [
			Color("#3e596e"), Color("#6b5146"), Color("#7b526b"), Color("#65734e")
		][character_index]
		var hair: Color = [
			Color("#201b1b"), Color("#30231d"), Color("#241b19"), Color("#302820")
		][character_index]
		var head_w: float = [25.0, 29.0, 24.0, 21.0][character_index] * scale_factor
		var head_h: float = [30.0, 31.0, 29.0, 25.0][character_index] * scale_factor
		var torso_w: float = [48.0, 58.0, 43.0, 39.0][character_index] * scale_factor
		var torso_h: float = [58.0, 53.0, 50.0, 48.0][character_index] * scale_factor
		var leg_w: float = [13.0, 16.0, 12.0, 11.0][character_index] * scale_factor
		var head_y: float = base_y - (torso_h + head_h + 18.0 * scale_factor)

		# Shoes and legs
		draw_rect(Rect2(center_x - leg_w - 3.0 * scale_factor, base_y - 32.0 * scale_factor, leg_w, 32.0 * scale_factor), Color("#25262b"))
		draw_rect(Rect2(center_x + 3.0 * scale_factor, base_y - 32.0 * scale_factor, leg_w, 32.0 * scale_factor), Color("#25262b"))
		draw_rect(Rect2(center_x - leg_w - 6.0 * scale_factor, base_y - 5.0 * scale_factor, leg_w + 7.0 * scale_factor, 5.0 * scale_factor), Color("#111216"))
		draw_rect(Rect2(center_x + 1.0 * scale_factor, base_y - 5.0 * scale_factor, leg_w + 7.0 * scale_factor, 5.0 * scale_factor), Color("#111216"))

		# Distinct torso silhouette; Naya wears a skirt.
		if character_index == 2:
			var skirt := PackedVector2Array([
				Vector2(center_x - torso_w * 0.48, base_y - 43.0 * scale_factor),
				Vector2(center_x + torso_w * 0.48, base_y - 43.0 * scale_factor),
				Vector2(center_x + torso_w * 0.66, base_y - 25.0 * scale_factor),
				Vector2(center_x - torso_w * 0.66, base_y - 25.0 * scale_factor)
			])
			draw_colored_polygon(skirt, Color("#4c3b50"))
		draw_rect(Rect2(center_x - torso_w * 0.5, base_y - 32.0 * scale_factor - torso_h, torso_w, torso_h), shirt)
		draw_rect(Rect2(center_x - torso_w * 0.5, base_y - 32.0 * scale_factor - torso_h, torso_w, 7.0 * scale_factor), shirt.lightened(0.2))

		# Arms vary in width and angle to distinguish body shapes.
		var arm_w: float = [11.0, 14.0, 9.0, 8.0][character_index] * scale_factor
		draw_rect(Rect2(center_x - torso_w * 0.5 - arm_w, base_y - 32.0 * scale_factor - torso_h + 5.0 * scale_factor, arm_w, torso_h * 0.72), shirt.darkened(0.08))
		draw_rect(Rect2(center_x + torso_w * 0.5, base_y - 32.0 * scale_factor - torso_h + 5.0 * scale_factor, arm_w, torso_h * 0.72), shirt.darkened(0.08))

		# Neck and head
		draw_rect(Rect2(center_x - 6.0 * scale_factor, head_y + head_h - 2.0 * scale_factor, 12.0 * scale_factor, 12.0 * scale_factor), skin)
		draw_circle(Vector2(center_x, head_y + head_h * 0.5), head_w * 0.5, skin)
		draw_rect(Rect2(center_x - head_w * 0.52, head_y + head_h * 0.22, head_w * 1.04, head_h * 0.26), hair)

		# Hair styles: Naya's long ponytail clearly distinguishes the female character.
		if character_index == 2:
			draw_circle(Vector2(center_x + head_w * 0.55, head_y + head_h * 0.70), head_w * 0.27, hair)
			draw_rect(Rect2(center_x + head_w * 0.50, head_y + head_h * 0.65, 7.0 * scale_factor, 25.0 * scale_factor), hair)
			draw_circle(Vector2(center_x - head_w * 0.12, head_y + head_h * 0.10), head_w * 0.33, hair)
		elif character_index == 1:
			draw_rect(Rect2(center_x - head_w * 0.62, head_y + head_h * 0.10, head_w * 1.24, head_h * 0.24), hair)
		elif character_index == 3:
			draw_circle(Vector2(center_x, head_y + head_h * 0.12), head_w * 0.39, hair)
		else:
			draw_circle(Vector2(center_x - head_w * 0.20, head_y + head_h * 0.10), head_w * 0.31, hair)

		# Eyes and collar detail
		draw_circle(Vector2(center_x - head_w * 0.18, head_y + head_h * 0.53), 1.7 * scale_factor, Color("#211a18"))
		draw_circle(Vector2(center_x + head_w * 0.18, head_y + head_h * 0.53), 1.7 * scale_factor, Color("#211a18"))
		draw_line(Vector2(center_x, base_y - 32.0 * scale_factor - torso_h + 2.0 * scale_factor), Vector2(center_x, base_y - 32.0 * scale_factor - torso_h + 17.0 * scale_factor), Color("#d7d0c5"), 2.0 * scale_factor)

		if selected:
			draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("#df343b"), false, 3.0)


func _ready() -> void:
	_build_ui()
	_load_selection()
	visible = false


func open() -> void:
	visible = true
	_refresh_cards()
	_status_label.text = "Karakter terpilih: %s" % CHARACTER_NAMES[_selected]


func close() -> void:
	visible = false


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.012, 0.012, 0.02, 0.97)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(620.0, maxf(340.0, get_viewport_rect().size.y - 70.0)))
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)

	var title := Label.new()
	title.text = "PILIH KARAKTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#d8323b"))
	title.add_theme_font_size_override("font_size", 32)
	_content.add_child(title)

	var description := Label.new()
	description.text = "Pilih satu dari empat siswa. Pilihan disimpan di perangkat ini."
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(description)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_content.add_child(grid)

	for i in range(4):
		var card := Button.new()
		card.custom_minimum_size = Vector2(300, 210)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.text = ""
		var card_box := VBoxContainer.new()
		card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_box.add_theme_constant_override("separation", 3)
		card.add_child(card_box)

		var preview := CharacterPreview.new()
		preview.character_index = i
		preview.custom_minimum_size = Vector2(0, 135)
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.add_child(preview)

		var name_label := Label.new()
		name_label.text = CHARACTER_NAMES[i]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 21)
		card_box.add_child(name_label)

		var detail := Label.new()
		detail.text = CHARACTER_DESCRIPTIONS[i]
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_font_size_override("font_size", 13)
		card_box.add_child(detail)

		card.pressed.connect(_select_character.bind(i))
		_cards.append(card)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color("#e7c7a4"))
	_content.add_child(_status_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	_content.add_child(actions)

	var confirm := Button.new()
	confirm.text = "PILIH KARAKTER"
	confirm.custom_minimum_size.y = 48
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(confirm)

	var back := Button.new()
	back.text = "KEMBALI"
	back.custom_minimum_size.y = 48
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(back)
	confirm.pressed.connect(_confirm_selection)
	back.pressed.connect(close)


func _load_selection() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_selected = clampi(int(cfg.get_value("character", "selected_index", 0)), 0, 3)


func _select_character(index: int) -> void:
	_selected = clampi(index, 0, 3)
	_refresh_cards()
	_status_label.text = "Terpilih: %s — %s" % [CHARACTER_NAMES[_selected], CHARACTER_DESCRIPTIONS[_selected]]


func _refresh_cards() -> void:
	for i in range(_cards.size()):
		_cards[i].modulate = Color.WHITE if i == _selected else Color(0.72, 0.72, 0.76, 1)
		var preview := _cards[i].get_child(0).get_child(0) as CharacterPreview
		preview.selected = i == _selected
		preview.queue_redraw()


func _confirm_selection() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("character", "selected_index", _selected)
	cfg.set_value("character", "name", CHARACTER_NAMES[_selected])
	cfg.save(SAVE_PATH)
	get_tree().set_meta("kelas_malam_character_index", _selected)
	get_tree().set_meta("kelas_malam_character_name", CHARACTER_NAMES[_selected])
	_status_label.text = "Karakter %s tersimpan." % CHARACTER_NAMES[_selected]
	close()


func get_selected_character_index() -> int:
	return _selected
