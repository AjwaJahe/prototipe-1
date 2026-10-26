extends Control

var _flicker_time := 0.0
var _light_alpha := 0.8

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	_flicker_time += delta
	if _flicker_time > 0.13:
		_flicker_time = 0.0
		_light_alpha = randf_range(0.48, 0.88) if randf() < 0.13 else 0.78
		queue_redraw()

func _draw() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var vanishing := Vector2(s.x * 0.5, s.y * 0.39)
	# Dinding koridor menyempit ke titik hilang.
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x * 0.78, s.y), Vector2(s.x * 0.22, s.y)]), Color(0.035, 0.038, 0.05, 1))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), vanishing, Vector2(s.x * 0.22, s.y), Vector2(0, s.y)]), Color(0.075, 0.078, 0.09, 1))
	draw_colored_polygon(PackedVector2Array([Vector2(s.x, 0), vanishing, Vector2(s.x * 0.78, s.y), Vector2(s.x, s.y)]), Color(0.065, 0.055, 0.065, 1))
	# Garis perspektif dinding dan lantai.
	for i in range(5):
		var y := s.y * (0.48 + float(i) * 0.115)
		draw_line(Vector2(0, y), Vector2(s.x * 0.22, y), Color(0.19, 0.17, 0.18, 0.28), 1.0)
		draw_line(Vector2(s.x * 0.78, y), Vector2(s.x, y), Color(0.19, 0.17, 0.18, 0.28), 1.0)
	for side in [-1.0, 1.0]:
		for i in range(2):
			var t := 0.25 + float(i) * 0.37
			var cx := lerpf(s.x * 0.5, s.x if side > 0 else 0.0, t)
			var w := s.x * (0.055 + t * 0.045)
			var top := s.y * (0.22 + t * 0.1)
			var h := s.y * (0.19 + t * 0.12)
			draw_rect(Rect2(cx - w * 0.5, top, w, h), Color(0.025, 0.025, 0.032, 1), true)
			draw_rect(Rect2(cx - w * 0.5, top, w, h), Color(0.27, 0.12, 0.13, 0.55), false, 2.0)
	# Lampu langit-langit yang redup dan berkelip.
	for i in range(3):
		var t := float(i) / 3.0
		var w := s.x * (0.045 - t * 0.025)
		var x := s.x * 0.5 - w * 0.5
		var y := s.y * (0.06 + t * 0.12)
		draw_rect(Rect2(x, y, w, maxf(3.0, s.y * 0.012)), Color(0.68, 0.64, 0.54, _light_alpha * (1.0 - t * 0.45)), true)
	# Bayangan gelap di bagian bawah memberi kesan koridor panjang.
	draw_rect(Rect2(0, s.y * 0.82, s.x, s.y * 0.18), Color(0.015, 0.014, 0.022, 0.55), true)
