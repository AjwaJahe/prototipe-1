extends Node

## Audio pool runtime Map58.
## Semua asset audio bersifat opsional: jika belum tersedia, game tetap berjalan.
## Tempatkan asset di res://assets/audio/... sesuai nama yang digunakan.

@export var master_volume_db: float = 0.0
@export var effects_volume_db: float = 0.0
@export var ambience_volume_db: float = -10.0

var _pools: Dictionary = {}
var _library: Dictionary = {}
var _current_ambience: AudioStreamPlayer


func _ready() -> void:
    add_to_group("audio_manager")
    _create_pool("player_footsteps", 1, false)
    _create_pool("teacher_footsteps", 1, true)
    _create_pool("door_sounds", 2, true)
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
            "res://assets/audio/footsteps/walk_1.ogg",
            "res://assets/audio/footsteps/walk_2.ogg"
        ],
        "player_run": [
            "res://assets/audio/footsteps/run_1.ogg"
        ],
        "player_crouch": [
            "res://assets/audio/footsteps/crouch_1.ogg"
        ],
        "teacher_footstep": [
            "res://assets/audio/teacher/walk_heavy_1.ogg"
        ],
        "door_open": [
            "res://assets/audio/doors/open_creaky.ogg"
        ],
        "door_close": [
            "res://assets/audio/doors/close_soft.ogg"
        ],
        "door_locked": [
            "res://assets/audio/doors/locked.ogg"
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
        "escape_success_fanfare": [
            "res://assets/audio/ui/escape_success_fanfare.ogg"
        ],
        "defeat_fanfare": [
            "res://assets/audio/ui/defeat_fanfare.ogg"
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


func play_teacher_footstep(volume_db: float = -2.5, pitch: float = 0.86, teacher_position: Vector3 = Vector3.ZERO) -> void:
    _play_pooled("teacher_footstep", "teacher_footsteps", volume_db, pitch, teacher_position)


func play_sfx(sound_name: String, world_position: Vector3 = Vector3.ZERO) -> void:
    var pool_name := "ui_sounds"
    if sound_name.begins_with("door"):
        pool_name = "door_sounds"
    _play_pooled(sound_name, pool_name, 0.0, 1.0, world_position)


func play_ui_sound(sound_name: String) -> void:
    _play_pooled(sound_name, "ui_sounds", 0.0, 1.0, Vector3.ZERO)


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

    source.stream = stream
    source.volume_db = master_volume_db + effects_volume_db + volume_db
    source.pitch_scale = pitch

    if source is AudioStreamPlayer3D:
        (source as AudioStreamPlayer3D).global_position = world_position

    source.play()


func set_ambience(ambience_type: String) -> void:
    var stream: AudioStream = _library.get(ambience_type)
    if stream == null:
        return

    if _current_ambience != null and is_instance_valid(_current_ambience):
        _current_ambience.stop()
        _current_ambience.queue_free()

    _current_ambience = AudioStreamPlayer.new()
    _current_ambience.stream = stream
    _current_ambience.volume_db = master_volume_db + ambience_volume_db
    _current_ambience.bus = _valid_bus("Ambience", "Master")
    add_child(_current_ambience)
    _current_ambience.play()


func stop_ambience() -> void:
    if _current_ambience != null and is_instance_valid(_current_ambience):
        _current_ambience.stop()
        _current_ambience.queue_free()
    _current_ambience = null
