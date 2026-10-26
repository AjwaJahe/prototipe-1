extends Button
## Tombol aksi HUD: gambar dan hit-test berada pada Control/Button yang sama.

@export_enum("Jump", "Run", "Crouch") var action_kind: int = 0

var _feedback_down := false
var _hovered := false

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_entered.connect(func(): _hovered = true; queue_redraw())
	mouse_exited.connect(func(): _hovered = false; queue_redraw())
	mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, empty)
	add_theme_color_override("font_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	toggled.connect(func(_active: bool): queue_redraw())
	queue_redraw()

func _on_button_down() -> void:
	_feedback_down = true
	queue_redraw()

func _on_button_up() -> void:
	_feedback_down = false
	queue_redraw()

func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	var ink := Color(0.055, 0.06, 0.055, 1.0)
	var normal_fill := Color(0.68, 0.70, 0.68, 0.96)
	var active := _feedback_down or (action_kind != 0 and button_pressed)
	var fill := Color(0.96, 0.97, 0.96, 1.0) if (active or _hovered) else normal_fill
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.43
	var points := PackedVector2Array()
	for i in range(25):
		var angle := TAU * float(i) / 24.0
		var wobble := 1.0 + 0.025 * sin(float(i) * 2.7)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius * wobble)
	draw_colored_polygon(points, fill)
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], ink, 2.5, true)
	_draw_action_icon(center + Vector2(0, -7), ink)

func _draw_action_icon(p: Vector2, ink: Color) -> void:
	var scale_factor := clampf(minf(size.x, size.y) / 64.0, 0.55, 1.15)
	match action_kind:
		0:
			draw_line(p + Vector2(0, 15) * scale_factor, p + Vector2(0, -13) * scale_factor, ink, 3.2 * scale_factor, true)
			draw_line(p + Vector2(0, -13) * scale_factor, p + Vector2(-8, -5) * scale_factor, ink, 3.2 * scale_factor, true)
			draw_line(p + Vector2(0, -13) * scale_factor, p + Vector2(8, -5) * scale_factor, ink, 3.2 * scale_factor, true)
		1:
			draw_circle(p + Vector2(-4, -8) * scale_factor, 3.5 * scale_factor, ink)
			draw_line(p + Vector2(-3, -4) * scale_factor, p + Vector2(5, 1) * scale_factor, ink, 3.0 * scale_factor, true)
			draw_line(p + Vector2(1, -1) * scale_factor, p + Vector2(-6, 7) * scale_factor, ink, 3.0 * scale_factor, true)
			draw_line(p + Vector2(4, 1) * scale_factor, p + Vector2(10, 7) * scale_factor, ink, 3.0 * scale_factor, true)
		2:
			draw_circle(p + Vector2(-4, -7) * scale_factor, 3.5 * scale_factor, ink)
			draw_line(p + Vector2(-3, -3) * scale_factor, p + Vector2(5, 2) * scale_factor, ink, 3.0 * scale_factor, true)
			draw_line(p + Vector2(2, 0) * scale_factor, p + Vector2(-5, 7) * scale_factor, ink, 3.0 * scale_factor, true)
			draw_line(p + Vector2(5, 2) * scale_factor, p + Vector2(10, 7) * scale_factor, ink, 3.0 * scale_factor, true)
