extends Node

## Audio pool runtime Map58.
## Semua asset audio bersifat opsional: jika belum tersedia, game tetap berjalan.
## Tempatkan asset di res://assets/audio/... sesuai nama yang digunakan.

@export var master_volume_db: float = 0.0
@export var effects_volume_db: float = 0.0
@export var ambience_volume_db: float = -28.0

var _pools: Dictionary = {}
var _library: Dictionary = {}
var _current_ambience: AudioStreamPlayer
var _current_ambience_name := ""
var _ending_player: AudioStreamPlayer
var _ending_in_progress := false
var _loops: Dictionary = {}


func _ready() -> void:
    add_to_group("audio_manager")
    _create_pool("player_footsteps", 1, false)
    _create_pool("teacher_footsteps", 1, true)
    _create_pool("door_sounds", 2, true)
    _create_pool("furniture_sounds", 3, true)
    _create_pool("ui_sounds", 3, false)
    _load_sound_library()


func _create_pool(pool_name: String, size: int, spatial: bool) -> void:
    var pool: Array[Node] = []
    for i in range(size):
        var player: Node
        if spatial:
            player = AudioStreamPlayer3D.new()
        else:
            player = AudioStreamPlayer.new()
        player.name = pool_name + "_" + str(i + 1)
        if player is AudioStreamPlayer3D:
            (player as AudioStreamPlayer3D).bus = _valid_bus("Effects", "Master")
        else:
            (player as AudioStreamPlayer).bus = _valid_bus("Effects", "Master")
        add_child(player)
        pool.append(player)
    _pools[pool_name] = pool


func _valid_bus(preferred: String, fallback: String) -> StringName:
    return StringName(preferred) if AudioServer.get_bus_index(preferred) >= 0 else StringName(fallback)


func _load_sound_library() -> void:
    var candidates := {
        "player_footstep": [
            "res://assets/audio/footsteps/footstep_walk.ogg"
        ],
        "player_run": [
            "res://assets/audio/footsteps/footstep_walk.ogg"
        ],
        "player_crouch": [
            "res://assets/audio/footsteps/footstep_walk.ogg"
        ],
        "teacher_footstep": [
            "res://assets/audio/footsteps/footstep_walk.ogg"
        ],
        "ghost_whisper": [
            "res://assets/audio/teacher/ghost_whisper.ogg"
        ],
        "fuzzy_jumpscare": [
            "res://assets/audio/teacher/fuzzy_jumpscare.ogg"
        ],
        "teacher_alert": [
            "res://assets/audio/teacher/ghost_whisper.ogg"
        ],
        "teacher_detection_alarm": [
            "res://assets/audio/teacher/ghost_whisper.ogg"
        ],
        "door_open": [
            "res://assets/audio/doors/door_open_creaky.ogg"
        ],
        "door_close": [
            "res://assets/audio/doors/door_handle.ogg"
        ],
        "door_locked": [
            "res://assets/audio/doors/door_handle.ogg"
        ],
        "key_unlock": [
            "res://assets/audio/doors/key_unlock.ogg"
        ],
        "drawer_open_close": [
            "res://assets/audio/furniture/drawer_open_close.ogg"
        ],
        "cabinet_slide": [
            "res://assets/audio/furniture/cabinet_slide.ogg"
        ],
        "item_pickup": [
            "res://assets/audio/ui/item_pickup.ogg"
        ],
        "answer_correct_ding": [
            "res://assets/audio/ui/answer_correct_ding.ogg"
        ],
        "answer_wrong_buzzer": [
            "res://assets/audio/ui/answer_wrong_buzzer.ogg"
        ],
        "phase_transition_stinger": [
            "res://assets/audio/ui/phase_transition_stinger.ogg"
        ],
        "teacher_berserk_alarm": [
            "res://assets/audio/ui/teacher_berserk_alarm.ogg"
        ],
        "ambience_room_small_night": [
            "res://assets/audio/ambience/room_small_night.mp3"
        ],
        "escape_success_fanfare": [
            "res://assets/audio/ui/small_bell_ding.mp3"
        ],
        "defeat_fanfare": [
            "res://assets/audio/ui/horror_sting.mp3"
        ],
        "ambience_school_normal": [
            "res://assets/audio/ambience/school_normal.ogg"
        ],
        "ambience_school_hunt": [
            "res://assets/audio/ambience/school_hunt.ogg"
        ],
        "ambience_school_supernatural": [
            "res://assets/audio/ambience/school_supernatural.ogg"
        ],
        "ambience_board_solving": [
            "res://assets/audio/ambience/board_solving.ogg"
        ]
    }

    for key in candidates:
        for path in candidates[key]:
            if ResourceLoader.exists(path):
                var stream := load(path) as AudioStream
                if stream != null:
                    _library[key] = stream
                    break


func _get_source(pool_name: String) -> Node:
    var pool: Array = _pools.get(pool_name, [])
    if pool.is_empty():
        return null

    for source in pool:
        if source != null and not source.playing:
            return source

    return pool[0]


func play_footstep(volume_db: float = -7.0, pitch: float = 1.0, world_position: Vector3 = Vector3.ZERO) -> void:
    var key := "player_footstep"
    if volume_db <= -8.5:
        key = "player_crouch"
    elif pitch > 1.01:
        key = "player_run"
    _play_pooled(key, "player_footsteps", volume_db, pitch, world_position)


func play_player_footstep(volume_db: float = -7.0, pitch: float = 1.0) -> void:
    play_footstep(volume_db, pitch)


func stop_player_footsteps() -> void:
    # Putuskan suara langkah yang masih berjalan ketika pemain berhenti.
    var pool: Array = _pools.get("player_footsteps", [])
    for source in pool:
        if source is AudioStreamPlayer and is_instance_valid(source):
            (source as AudioStreamPlayer).stop()


func play_teacher_footstep(volume_db: float = -2.5, pitch: float = 0.86, teacher_position: Vector3 = Vector3.ZERO) -> void:
    _play_pooled("teacher_footstep", "teacher_footsteps", volume_db, pitch, teacher_position)


func play_sfx(sound_name: String, world_position: Vector3 = Vector3.ZERO) -> void:
    var pool_name := "ui_sounds"
    if sound_name.begins_with("door") or sound_name.begins_with("key"):
        pool_name = "door_sounds"
    elif sound_name in ["drawer_open_close", "cabinet_slide"]:
        pool_name = "furniture_sounds"
    var volume_db := -5.0 if sound_name == "fuzzy_jumpscare" else (-8.0 if sound_name == "ghost_whisper" else 0.0)
    _play_pooled(sound_name, pool_name, volume_db, 1.0, world_position)


func play_sfx_for_duration(sound_name: String, duration: float, world_position: Vector3 = Vector3.ZERO) -> void:
    # Atur playback agar durasi audio sesuai durasi animasi yang memicunya.
    var stream: AudioStream = _library.get(sound_name)
    if stream == null:
        return
    var safe_duration := maxf(duration, 0.05)
    var stream_duration := stream.get_length()
    if stream_duration <= 0.0:
        _play_pooled(sound_name, _get_sfx_pool_name(sound_name), 0.0, 1.0, world_position)
        return
    # AudioStreamPlayer memakai pitch_scale: panjang putar = panjang asli / pitch.
    # Jangan batasi rasio di sini, supaya durasinya benar-benar mengikuti animasi.
    var pitch := stream_duration / safe_duration
    _play_pooled(sound_name, _get_sfx_pool_name(sound_name), 0.0, pitch, world_position)


func _get_sfx_pool_name(sound_name: String) -> String:
    if sound_name.begins_with("door") or sound_name.begins_with("key"):
        return "door_sounds"
    if sound_name in ["drawer_open_close", "cabinet_slide"]:
        return "furniture_sounds"
    return "ui_sounds"


func play_ui_sound(sound_name: String) -> void:
    _play_pooled(sound_name, "ui_sounds", 0.0, 1.0, Vector3.ZERO)


func play_loop(sound_name: String, volume_db: float = 0.0) -> void:
    var stream: AudioStream = _library.get(sound_name)
    if stream == null:
        return

    var source: AudioStreamPlayer = _loops.get(sound_name)
    if source != null and is_instance_valid(source):
        source.volume_db = master_volume_db + effects_volume_db + volume_db
        if not source.playing:
            source.play()
        return

    source = AudioStreamPlayer.new()
    source.name = "Loop_" + sound_name
    source.stream = stream
    source.volume_db = master_volume_db + effects_volume_db + volume_db
    source.bus = _valid_bus("Effects", "Master")
    source.autoplay = false
    source.set_meta("loop_sound", true)
    if stream is AudioStreamOggVorbis:
        (stream as AudioStreamOggVorbis).loop = true
    add_child(source)
    _loops[sound_name] = source
    source.play()


func stop_loop(sound_name: String) -> void:
    var source: AudioStreamPlayer = _loops.get(sound_name)
    if source == null or not is_instance_valid(source):
        _loops.erase(sound_name)
        return
    source.stop()
    source.queue_free()
    _loops.erase(sound_name)


func _play_pooled(
    sound_name: String,
    pool_name: String,
    volume_db: float,
    pitch: float,
    world_position: Vector3
) -> void:
    var stream: AudioStream = _library.get(sound_name)
    if stream == null:
        return

    var source := _get_source(pool_name)
    if source == null:
        return

    if source is AudioStreamPlayer3D:
        var spatial := source as AudioStreamPlayer3D
        spatial.stream = stream
        spatial.volume_db = master_volume_db + effects_volume_db + volume_db
        spatial.pitch_scale = pitch
        spatial.global_position = world_position
        spatial.play()
    elif source is AudioStreamPlayer:
        var flat := source as AudioStreamPlayer
        flat.stream = stream
        flat.volume_db = master_volume_db + effects_volume_db + volume_db
        flat.pitch_scale = pitch
        flat.play()

    # Langkah kaki hanya memakai bagian awal klip agar tidak bertumpuk selama 3 detik.
    # Token mencegah timer lama menghentikan suara baru saat player pool dipakai ulang.
    # Batas durasi efek pendek. Efek naratif (bisikan, jumpscare, alarm, fanfare)
    # dan ambience dibiarkan selesai alami agar tidak terpotong.
    var cutoff := _get_sound_cutoff(sound_name)
    if cutoff > 0.0:
        _schedule_pooled_cutoff(source, cutoff)


func _get_sound_cutoff(sound_name: String) -> float:
    match sound_name:
        "player_footstep", "player_run", "player_crouch":
            return 0.30
        "teacher_footstep":
            return 0.35
        "door_open":
            return 0.60
        "door_close", "door_locked":
            return 0.70
        "key_unlock", "drawer_open_close", "cabinet_slide", "item_pickup":
            return 0.30
        "answer_correct_ding":
            return 0.10
        "answer_wrong_buzzer":
            return 0.30
        _:
            return 0.0


func _schedule_pooled_cutoff(source: Node, duration: float) -> void:
    var token := int(source.get_meta("audio_cutoff_token", 0)) + 1
    source.set_meta("audio_cutoff_token", token)
    _stop_pooled_after(source, duration, token)


func _stop_pooled_after(source: Node, duration: float, token: int) -> void:
    await get_tree().create_timer(duration).timeout
    if not is_instance_valid(source):
        return
    if int(source.get_meta("audio_cutoff_token", 0)) != token:
        return
    if source is AudioStreamPlayer3D:
        (source as AudioStreamPlayer3D).stop()
    elif source is AudioStreamPlayer:
        (source as AudioStreamPlayer).stop()


func has_sound(sound_name: String) -> bool:
    return _library.has(sound_name) and _library[sound_name] != null


func set_ambience(ambience_type: String) -> void:
    var stream: AudioStream = _library.get(ambience_type)
    if stream == null:
        push_warning("AudioManager: sound asset missing or not imported: " + ambience_type)
        return
    if stream == null or _ending_in_progress:
        return

    # Jangan memulai ulang room tone saat fase gameplay berubah.
    if _current_ambience != null and is_instance_valid(_current_ambience):
        if _current_ambience_name == ambience_type and _current_ambience.playing:
            return
        _current_ambience.stop()
        _current_ambience.queue_free()

    _current_ambience = AudioStreamPlayer.new()
    _current_ambience.name = "GameplayRoomTone"
    _current_ambience.stream = stream
    _current_ambience.volume_db = master_volume_db + ambience_volume_db
    _current_ambience.bus = _valid_bus("Ambience", "Master")
    if stream is AudioStreamOggVorbis:
        (stream as AudioStreamOggVorbis).loop = true
    elif stream is AudioStreamMP3:
        (stream as AudioStreamMP3).loop = true
    add_child(_current_ambience)
    _current_ambience_name = ambience_type
    _current_ambience.play()


func play_ending_sound(sound_name: String, volume_db: float = -9.0) -> void:
    if _ending_in_progress:
        return
    var stream: AudioStream = _library.get(sound_name)
    if stream == null:
        push_warning("AudioManager: ending sound not loaded: " + sound_name)
        return

    _ending_in_progress = true
    if _current_ambience != null and is_instance_valid(_current_ambience):
        var old_ambience := _current_ambience
        var fade := create_tween()
        fade.tween_property(old_ambience, "volume_db", -60.0, 0.8)
        await fade.finished
        if is_instance_valid(old_ambience):
            old_ambience.stop()
            old_ambience.queue_free()
    _current_ambience = null
    _current_ambience_name = ""

    _ending_player = AudioStreamPlayer.new()
    _ending_player.name = "EndingSound"
    _ending_player.stream = stream
    _ending_player.volume_db = master_volume_db + effects_volume_db + volume_db
    _ending_player.bus = _valid_bus("Effects", "Master")
    add_child(_ending_player)
    _ending_player.finished.connect(func() -> void:
        if is_instance_valid(_ending_player):
            _ending_player.queue_free()
        _ending_player = null
    )
    _ending_player.play()

    # HorrorSting sumber berdurasi panjang; gunakan hanya cue awal agar ending tetap singkat.
    if sound_name == "defeat_fanfare":
        var defeat_player := _ending_player
        var defeat_fade := create_tween()
        defeat_fade.tween_interval(2.5)
        defeat_fade.tween_property(defeat_player, "volume_db", -60.0, 0.8)
        defeat_fade.tween_callback(func() -> void:
            if is_instance_valid(defeat_player):
                defeat_player.stop()
                defeat_player.queue_free()
            if _ending_player == defeat_player:
                _ending_player = null)


func stop_ambience() -> void:
    if _current_ambience != null and is_instance_valid(_current_ambience):
        _current_ambience.stop()
        _current_ambience.queue_free()
    _current_ambience = null
    _current_ambience_name = ""
