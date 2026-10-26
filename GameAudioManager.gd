extends Node

## Penghubung event gameplay -> AudioManager.
## Tidak mengharuskan asset audio tersedia; manager akan diam jika file belum ada.

var _game: Node
var _player: Node
var _teacher: Node
var _audio: Node
var _teacher_voice_active := false
var _ending_played := false


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

    # Jalankan setelah seluruh node dan audio library selesai _ready/import.
    call_deferred("_start_gameplay_room_tone")


func _start_gameplay_room_tone() -> void:
    if _audio == null or not is_instance_valid(_audio):
        push_warning("GameAudioManager: AudioManager tidak ditemukan; ambience tidak dapat dimulai.")
        return
    if not _audio.has_method("set_ambience"):
        push_warning("GameAudioManager: AudioManager tidak memiliki set_ambience().")
        return
    if not _audio.has_method("has_sound") or _audio.has_sound("ambience_room_small_night"):
        _audio.set_ambience("ambience_room_small_night")
    else:
        push_warning("GameAudioManager: ambience_room_small_night tidak termuat. Periksa import aset audio.")


func _process(_delta: float) -> void:
    if _game == null or _teacher == null or _audio == null:
        return

    if Engine.get_process_frames() % 45 != 0:
        return

    var phase := String(_game.get("phase"))
    if phase != "HUNT" and phase != "BOARD_SOLVING":
        return

    var distance := INF
    if _player is Node3D and _teacher is Node3D:
        distance = (_player as Node3D).global_position.distance_to(
            (_teacher as Node3D).global_position
        )

    if distance < 8.0 and not _teacher_voice_active:
        # Bisikan hanya dipicu sekali ketika guru mendekat, bukan berulang setiap beberapa frame.
        _audio.play_sfx("ghost_whisper")
        _teacher_voice_active = true
    elif distance > 11.0:
        _teacher_voice_active = false


## API proxy untuk TeacherAI_New agar semua efek melewati AudioManager.
func play_sfx(sound_name: String, world_position: Vector3 = Vector3.ZERO) -> void:
    if _audio != null and _audio.has_method("play_sfx"):
        _audio.play_sfx(sound_name, world_position)


func play_loop(sound_name: String, volume_db: float = 0.0) -> void:
    if _audio != null and _audio.has_method("play_loop"):
        _audio.play_loop(sound_name, volume_db)


func stop_loop(sound_name: String) -> void:
    if _audio != null and _audio.has_method("stop_loop"):
        _audio.stop_loop(sound_name)


func play_footstep(volume_db: float = -7.0, pitch: float = 1.0) -> void:
    if _audio != null and _audio.has_method("play_footstep"):
        _audio.play_footstep(volume_db, pitch)


func play_teacher_footstep(volume_db: float = -2.5, pitch: float = 0.86, teacher_position: Vector3 = Vector3.ZERO) -> void:
    if _audio != null and _audio.has_method("play_teacher_footstep"):
        _audio.play_teacher_footstep(volume_db, pitch, teacher_position)


func _on_phase_changed(phase: String) -> void:
    if _audio == null:
        return

    # Jangan memainkan ending dari phase_changed: game_finished adalah satu-satunya pemicu.
    if phase == "FINISHED":
        return
    if _audio.has_method("set_ambience"):
        _audio.set_ambience("ambience_room_small_night")


func _on_teacher_mode_changed(_mode: String, _target: Node) -> void:
    # Room tone tetap sama saat mode guru berubah; langkah dan SFX tetap terdengar.
    pass


func _on_inventory_changed(_items: Array) -> void:
    if _audio != null:
        _audio.play_ui_sound("item_pickup")


func _on_player_revived(_player: Node) -> void:
    if _audio != null:
        _audio.play_ui_sound("item_pickup")


func _on_game_finished() -> void:
    if _audio == null or _ending_played:
        return
    _ending_played = true

    var result := String(_game.get("game_result")) if _game != null else "WIN"
    if result == "LOSE":
        if _audio.has_method("play_ending_sound"):
            _audio.play_ending_sound("defeat_fanfare", -12.0)
        else:
            _audio.play_ui_sound("defeat_fanfare")
    else:
        if _audio.has_method("play_ending_sound"):
            _audio.play_ending_sound("escape_success_fanfare", -12.0)
        else:
            _audio.play_ui_sound("escape_success_fanfare")
