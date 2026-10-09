extends CanvasLayer

## HUD dinamis Map58. Display-only: tidak mengubah aturan gameplay.

var _game: Node
var _player: Node
var _teacher: Node

var objective_label: Label
var phase_label: Label
var timer_label: Label
var score_label: Label
var stamina_bar: ProgressBar
var stamina_label: Label
var inventory_label: Label
var status_label: Label
var proximity_label: Label
var board_panel: PanelContainer
var board_question_label: Label
var board_answer_hint: Label
var results_panel: PanelContainer
var results_label: Label


func _ready() -> void:
    _game = get_node_or_null("../GameManager")
    _player = get_node_or_null("../Player")
    _teacher = get_node_or_null("../Teacher")
    _build_hud()

    if _game != null:
        if _game.has_signal("phase_changed"):
            _game.phase_changed.connect(_on_phase_changed)
        if _game.has_signal("objective_changed"):
            _game.objective_changed.connect(_on_objective_changed)
        if _game.has_signal("game_finished"):
            _game.game_finished.connect(_on_game_finished)

    if _player != null:
        if _player.has_signal("stamina_changed"):
            _player.stamina_changed.connect(_on_stamina_changed)
        var inventory := _player.get_node_or_null("ItemInventory")
        if inventory != null and inventory.has_signal("inventory_changed"):
            inventory.inventory_changed.connect(_on_inventory_changed)

    _refresh_all()


const REFRESH_INTERVAL := 0.1
var _refresh_remaining := 0.0


func _process(delta: float) -> void:
    _refresh_remaining -= delta
    if _refresh_remaining > 0.0:
        return
    _refresh_remaining = REFRESH_INTERVAL
    _refresh_all()


func _build_hud() -> void:
    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    objective_label = _make_label(root, Vector2(24, 18), 20)
    phase_label = _make_label(root, Vector2(24, 46), 15)
    timer_label = _make_label(root, Vector2(24, 70), 20)
    score_label = _make_label(root, Vector2(0, 18), 20)
    score_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    score_label.offset_left = -220
    score_label.offset_right = -24

    stamina_label = _make_label(root, Vector2(0, 48), 15)
    stamina_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    stamina_label.offset_left = -220
    stamina_label.offset_right = -24

    stamina_bar = ProgressBar.new()
    stamina_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    stamina_bar.offset_left = -220
    stamina_bar.offset_top = 72
    stamina_bar.offset_right = -24
    stamina_bar.offset_bottom = 92
    stamina_bar.show_percentage = false
    root.add_child(stamina_bar)

    inventory_label = _make_label(root, Vector2(24, 0), 16)
    inventory_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    inventory_label.offset_top = -125
    inventory_label.offset_right = 360
    inventory_label.offset_bottom = -35

    proximity_label = _make_label(root, Vector2(0, 0), 16)
    proximity_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    proximity_label.offset_left = -180
    proximity_label.offset_top = -105
    proximity_label.offset_right = 180
    proximity_label.offset_bottom = -72
    proximity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    status_label = _make_label(root, Vector2(0, 0), 24)
    status_label.set_anchors_preset(Control.PRESET_CENTER)
    status_label.offset_left = -400
    status_label.offset_top = 170
    status_label.offset_right = 400
    status_label.offset_bottom = 220
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    board_panel = PanelContainer.new()
    board_panel.set_anchors_preset(Control.PRESET_CENTER)
    board_panel.offset_left = -360
    board_panel.offset_top = -230
    board_panel.offset_right = 360
    board_panel.offset_bottom = 130
    board_panel.visible = false
    add_child(board_panel)

    var board_box := VBoxContainer.new()
    board_panel.add_child(board_box)
    board_question_label = _make_label(board_box, Vector2.ZERO, 22)
    board_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    board_question_label.custom_minimum_size = Vector2(680, 190)
    board_question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    board_answer_hint = _make_label(board_box, Vector2.ZERO, 15)
    board_answer_hint.text = "Masukkan jawaban melalui kontrol papan."

    results_panel = PanelContainer.new()
    results_panel.set_anchors_preset(Control.PRESET_CENTER)
    results_panel.offset_left = -320
    results_panel.offset_top = -220
    results_panel.offset_right = 320
    results_panel.offset_bottom = 220
    results_panel.visible = false
    add_child(results_panel)
    results_label = _make_label(results_panel, Vector2.ZERO, 24)
    results_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    results_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _make_label(parent: Node, position: Vector2, size: int) -> Label:
    var label := Label.new()
    label.position = position
    label.add_theme_font_size_override("font_size", size)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    return label


func _refresh_all() -> void:
    if _game == null:
        return

    var phase := String(_game.get("phase"))
    phase_label.text = "FASE: " + _pretty_phase(phase)
    score_label.text = "SKOR: " + str(int(_game.get("score")))

    var solved := int(_game.get("solved_papers"))
    objective_label.text = "SOAL: %d/10" % solved

    var timer := 0.0
    if phase == "INTRO_EXAM":
        timer = float(_game.get("intro_remaining"))
    elif phase == "TRANSITION":
        timer = float(_game.get("transition_remaining"))
    elif phase == "HUNT":
        timer = maxf(
            float(_game.get("hunt_remaining")),
            maxf(float(_game.get("calm_remaining")), float(_game.get("berserk_remaining")))
        )
    elif phase == "BOARD_SOLVING":
        timer = float(_game.get("board_remaining"))
    timer_label.text = "WAKTU: " + _format_time(timer)

    if _player != null:
        var stamina := float(_player.get("run_stamina"))
        var max_stamina := maxf(float(_player.get("max_run_stamina")), 0.001)
        stamina_bar.value = stamina
        stamina_bar.max_value = max_stamina
        stamina_label.text = "STAMINA: %d%%" % roundi(stamina / max_stamina * 100.0)

        var inventory := _player.get_node_or_null("ItemInventory")
        if inventory != null:
            var items: Array = inventory.get_inventory() if inventory.has_method("get_inventory") else []
            inventory_label.text = "INVENTORI [%d/5]:
%s" % [
                items.size(),
                ", ".join(items)
            ]

    if _teacher != null and _player is Node3D and _teacher is Node3D:
        var distance := (_player as Node3D).global_position.distance_to(
            (_teacher as Node3D).global_position
        )
        if distance < 10.0:
            proximity_label.text = "⚠ GURU DEKAT — %0.1f m" % distance
        elif distance < 15.0:
            proximity_label.text = "GURU TERDETEKSI — %0.1f m" % distance
        else:
            proximity_label.text = ""


    board_panel.visible = phase == "BOARD_SOLVING"
    if board_panel.visible:
        var question: Dictionary = _game.get("current_question")
        board_question_label.text = "SOAL KE %d/10
%s

WAKTU: %s" % [
            solved + 1,
            String(question.get("question", "")),
            _format_time(timer)
        ]

    if phase == "FINISHED":
        results_panel.visible = true


func _on_phase_changed(_phase: String) -> void:
    _refresh_all()


func _on_objective_changed(_solved: int, _target: int) -> void:
    _refresh_all()


func _on_stamina_changed(_current: float, _maximum: float) -> void:
    _refresh_all()


func _on_inventory_changed(_items: Array) -> void:
    _refresh_all()


func _on_game_finished() -> void:
    if _game == null:
        return
    var result := String(_game.get("game_result"))
    var title := "KALAH!" if result == "LOSE" else "SELESAI!"
    results_label.text = "%s

NILAI AKHIR: %s
SKOR TOTAL: %d
SOAL TERJAWAB: %d/10" % [
        title,
        String(_game.get_final_grade()),
        int(_game.get("score")),
        int(_game.get("solved_papers"))
    ]
    results_panel.visible = true


func _format_time(seconds_value: float) -> String:
    var total := maxi(0, int(ceil(seconds_value)))
    return "%02d:%02d" % [total / 60, total % 60]


func _pretty_phase(value: String) -> String:
    return value.replace("_", " ").capitalize()
