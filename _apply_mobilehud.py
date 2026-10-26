from pathlib import Path
root=Path(r'C:\Users\LENOVO\Documents\prototipe-1')
p=root/'MobileControls.gd'
s=p.read_text(encoding='utf-8-sig')
repls={
'''if not DisplayServer.is_touchscreen_available():
		set_process_unhandled_input(false)
		set_process(false)
		return''':'''# F5/editor debug builds show a visual preview; exported desktop builds remain unchanged.
	if not DisplayServer.is_touchscreen_available() and not OS.has_feature("debug"):
		set_process_unhandled_input(false)
		set_process(false)
		return''',
'''var jump_button := _make_button(root, "LOMPAT", Vector2(-118, -220), Vector2(100, 72))''':'''var jump_button := _make_round_action(root, "↑", Vector2(-116, -224), Vector2(70, 70), "Lompat")''',
'''var interact_button := _make_button(root, "AKSI", Vector2(-226, -132), Vector2(96, 66))''':'''var interact_button := _make_round_action(root, "✋", Vector2(-222, -148), Vector2(64, 64), "Aksi")''',
'''var hide_button := _make_button(root, "SEMBUNYI", Vector2(-118, -132), Vector2(100, 66))''':'''var hide_button := _make_round_action(root, "⌂", Vector2(-142, -148), Vector2(64, 64), "Sembunyi")''',
'''var heal_button := _make_button(root, "TOLONG", Vector2(-226, -58), Vector2(96, 54))''':'''var heal_button := _make_round_action(root, "+", Vector2(-222, -76), Vector2(58, 58), "Tolong")''',
'''_run_button = _make_button(root, "LARI: OFF", Vector2(-118, -58), Vector2(100, 54))''':'''_run_button = _make_round_action(root, "🏃", Vector2(-142, -76), Vector2(64, 64), "LARI: OFF")''',
'''_crouch_button = _make_button(root, "JONGKOK", Vector2(-334, -58), Vector2(96, 54))''':'''_crouch_button = _make_round_action(root, "▾", Vector2(-292, -76), Vector2(58, 58), "JONGKOK")''',
'''_menu_button.pressed.connect(_toggle_proposal_menu)''':'''_menu_button.pressed.connect(_open_real_menu)''',
}
for old,new in repls.items():
 if old not in s: raise RuntimeError('Missing expected snippet: '+old[:70])
 s=s.replace(old,new,1)
# Replace placeholder menu overlay block with a bridge to the real UI manager.
start=s.find('\t_menu_overlay = ColorRect.new()')
end=s.find('\n\nfunc _make_round_button',start)
if start<0 or end<0: raise RuntimeError('Menu overlay block not found')
bridge='''

func _open_real_menu() -> void:
	var ui := get_tree().get_first_node_in_group("game_ui_manager")
	if ui != null and ui.has_method("open_menu_from_mobile"):
		ui.call("open_menu_from_mobile")

func _toggle_proposal_menu() -> void:
	_open_real_menu()'''
s=s[:start]+bridge+s[end:]
marker='func _circle_style(bg: Color) -> StyleBoxFlat:'
helper='''func _make_round_action(root: Control, caption: String, offset: Vector2, button_size: Vector2, hint: String) -> Button:
	var button := Button.new()
	button.name = hint.replace(" ", "") + "Button"
	button.text = caption
	button.tooltip_text = hint
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = offset.x
	button.offset_top = offset.y
	button.offset_right = offset.x + button_size.x
	button.offset_bottom = offset.y + button_size.y
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	button.add_theme_stylebox_override("normal", _circle_style(Color(0.07, 0.10, 0.14, 0.72)))
	button.add_theme_stylebox_override("hover", _circle_style(Color(0.12, 0.20, 0.27, 0.9)))
	button.add_theme_stylebox_override("pressed", _circle_style(Color(0.05, 0.38, 0.34, 0.92)))
	root.add_child(button)
	return button

'''
if marker not in s: raise RuntimeError('Circle style marker missing')
s=s.replace(marker,helper+marker,1)
p.write_text(s,encoding='utf-8')
print('MobileControls updated:',len(s.splitlines()),'lines')
