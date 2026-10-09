extends Node

## Penghubung event gameplay -> AudioManager.
## Tidak mengharuskan asset audio tersedia; manager akan diam jika file belum ada.

var _game: Node
var _player: Node
var _teacher: Node
var _audio: Node


func _ready() -> void:
    add_to_group("game_audio")
    _game = get_node_or_null("../GameManager")
    _player = get_node_or_null("../Player/CharacterBody3D")
    if _player == null:
        _player = get_node_or_null("../Player")
    _teacher = get_node_or_null("../Teacher")
    _audio = get_node_or_null("../AudioManager")

    if _game != null:
        if _game.has_signal("phase_changed"):
            _game.phase_changed.connect(_on_phase_changed)
        if _game.has_signal("teacher_mode_changed"):
            _game.teacher_mode_changed.connect(_on_teacher_mode_changed)
        if _game.has_signal("player_revived"):
            _game.player_revived.connect(_on_player_revived)
        if _game.has_signal("game_finished"):
            _game.game_finished.connect(_on_game_finished)

    if _player != null:
        var inventory := _player.get_node_or_null("ItemInventory")
        if inventory != null and inventory.has_signal("inventory_changed"):
            inventory.inventory_changed.connect(_on_inventory_changed)


func _process(_delta: float) -> void:
    if _game == null or _teacher == null or _audio == null:
        return

    var phase := String(_game.get("phase"))
    if phase != "HUNT" and phase != "BOARD_SOLVING":
        return

    var distance := INF
    if _player is Node3D and _teacher is Node3D:
        distance = (_player as Node3D).global_position.distance_to(
            (_teacher as Node3D).global_position
        )

    if distance < 10.0:
        # Proximity audio hanya dimainkan lewat HUD/audio layer bila asset tersedia.
        # Tidak diputar setiap frame agar tidak menumpuk.
        if Engine.get_process_frames() % 45 == 0:
            _audio.play_ui_sound("teacher_detection_alarm")


func _on_phase_changed(phase: String) -> void:
    if _audio == null:
        return

    match phase:
        "INTRO_EXAM":
            _audio.set_ambience("ambience_school_normal")
        "TRANSITION":
            _audio.play_ui_sound("phase_transition_stinger")
            _audio.set_ambience("ambience_school_supernatural")
        "HUNT":
            _audio.set_ambience("ambience_school_hunt")
        "BOARD_SOLVING":
            _audio.set_ambience("ambience_board_solving")
        "ESCAPE_READY":
            _audio.set_ambience("ambience_school_hunt")
        "FINISHED":
            _audio.play_ui_sound("escape_success_fanfare")


func _on_teacher_mode_changed(mode: String, _target: Node) -> void:
    if _audio == null:
        return

    if mode == "ghost" or mode == "berserk":
        _audio.set_ambience("ambience_school_supernatural")
    elif mode == "teacher":
        _audio.set_ambience("ambience_school_hunt")


func _on_inventory_changed(_items: Array) -> void:
    if _audio != null:
        _audio.play_ui_sound("item_pickup")


func _on_player_revived(_player: Node) -> void:
    if _audio != null:
        _audio.play_ui_sound("item_pickup")


func _on_game_finished() -> void:
    if _audio == null:
        return
    if _game != null and String(_game.get("game_result")) == "LOSE":
        _audio.play_ui_sound("defeat_fanfare")
    else:
        _audio.play_ui_sound("escape_success_fanfare")
