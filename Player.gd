extends CharacterBody3D

@export var speed := 10.0
@export var run_speed := 15.0
@export var crouch_speed := 2.5
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.003

@export var max_run_stamina: float = 5.0
@export var stamina_recovery_speed: float = 1.0

var gravity := 9.8
var is_crouching := false
var run_stamina: float = 5.0
var run_exhausted := false
var is_running := false
var _footstep_timer := 0.0

@onready var camera := $Camera3D
@onready var collision_shape := $CollisionShape3D
@onready var mobile_controls: Node = get_node_or_null("MobileControls")

var standing_height := 1.65
var crouching_height := 0.9

signal stamina_changed(current: float, maximum: float)

var _stamina_bar: ProgressBar
var _stamina_text: Label


func _ready() -> void:
    # Perangkat layar sentuh perlu cursor terlihat agar tombol HUD dapat ditekan.
    var touch_controls: bool = mobile_controls != null and mobile_controls.has_method("is_mobile") and mobile_controls.call("is_mobile") == true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if touch_controls else Input.MOUSE_MODE_CAPTURED
    add_to_group("players")
    run_stamina = max_run_stamina
    _hide_world_body_from_local_camera()
    _build_stamina_ui()
    _update_stamina_ui()


func _hide_world_body_from_local_camera() -> void:
    # Seluruh model tubuh pemain masuk Visual Layer 2, yang sudah dikecualikan
    # oleh FirstPersonLocalHeadCulling.gd. Kamera POV tidak lagi menembus tubuh
    # saat jongkok/KO, sementara kamera pemain lain tetap melihat model normal.
    var world_body := get_node_or_null("PlayerCharacter/world")
    if world_body == null:
        return
    var pending: Array[Node] = [world_body]
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        if node is VisualInstance3D:
            (node as VisualInstance3D).layers = 2
        for child in node.get_children():
            pending.append(child)


var _last_emitted_stamina := -1.0


func _process(_delta: float) -> void:
    if is_equal_approx(run_stamina, _last_emitted_stamina):
        return
    _last_emitted_stamina = run_stamina
    _update_stamina_ui()
    stamina_changed.emit(run_stamina, max_run_stamina)


func _unhandled_input(event: InputEvent) -> void:
    # Chat multiplayer bersifat modal: keyboard dan mouse tidak mengendalikan pemain.
    if bool(get_meta("communication_ui_open", false)):
        return
    # Mode papan tulis mengambil alih POV dan membekukan kontrol gerak/lihat.
    if bool(get_meta("whiteboard_mode", false)):
        return
    # Kamera dikunci ke celah peti selama bersembunyi.
    if bool(get_meta("is_hidden", false)):
        return
    # Jumpscare tetap mengunci POV, tetapi saat tubuh diseret guru pemain boleh
    # menoleh untuk melihat lingkungan. Gerak badan tetap dikunci oleh _physics_process.
    if bool(get_meta("capture_animation", false)):
        return
    var is_being_dragged := bool(get_meta("capture_dragging", false))
    if bool(get_meta("intro_locked", false)) and bool(get_meta("intro_pov_locked", true)) and not bool(get_meta("knocked_out", false)) and not is_being_dragged:
        return

    if event is InputEventMouseMotion:
        # Saat HUD sentuh aktif dan cursor terlihat, klik/tap UI tidak boleh memutar kamera.
        # Di mobile, semua MouseMotion diabaikan; POV hanya dari area sentuh khusus.
        if mobile_controls != null and mobile_controls.has_method("is_mobile") and mobile_controls.call("is_mobile") == true:
            return
        rotate_y(-event.relative.x * mouse_sensitivity)
        camera.rotate_x(-event.relative.y * mouse_sensitivity)
        camera.rotation.x = clamp(camera.rotation.x, -1.4, 1.4)



func _physics_process(delta: float) -> void:
    if bool(get_meta("communication_ui_open", false)):
        velocity = Vector3.ZERO
        return
    if bool(get_meta("whiteboard_mode", false)):
        velocity = Vector3.ZERO
        return
    if bool(get_meta("knocked_out", false)):
        # Saat KO, pemain tetap rebah tetapi boleh merangkak pelan dengan WASD.
        # Hanya animasi/drag tangkapan yang tetap mengambil alih gerakan.
        if bool(get_meta("capture_animation", false)) or bool(get_meta("capture_dragging", false)):
            velocity = Vector3.ZERO
            return

        if not is_on_floor():
            velocity.y -= gravity * delta
        else:
            velocity.y = 0.0

        # Turunkan POV mendekati lantai selama KO; setelah revive, kamera pulih
        # otomatis lewat pengaturan tinggi kamera pada jalur gerak normal.
        camera.position.y = lerp(camera.position.y, 0.48, delta * 5.0)

        var crawl_input := _read_movement_input()

        var crawl_direction := (transform.basis * Vector3(crawl_input.x, 0.0, crawl_input.y)).normalized()
        const KO_CRAWL_SPEED: float = 1.55
        if crawl_direction.length_squared() > 0.0:
            velocity.x = crawl_direction.x * KO_CRAWL_SPEED
            velocity.z = crawl_direction.z * KO_CRAWL_SPEED
        else:
            velocity.x = move_toward(velocity.x, 0.0, KO_CRAWL_SPEED * 2.5 * delta)
            velocity.z = move_toward(velocity.z, 0.0, KO_CRAWL_SPEED * 2.5 * delta)

        move_and_slide()
        return

    if bool(get_meta("intro_locked", false)):
        velocity = Vector3.ZERO
        return

    if not is_on_floor():
        velocity.y -= gravity * delta

    var mobile_mode := mobile_controls != null and mobile_controls.has_method("is_mobile") and bool(mobile_controls.call("is_mobile"))
    var mobile_crouch: bool = mobile_mode and mobile_controls.get("crouch_enabled") == true
    is_crouching = (not mobile_mode and Input.is_key_pressed(KEY_CTRL)) or mobile_crouch

    var mobile_jump := false
    if mobile_mode and mobile_controls.has_method("consume_jump_request"):
        mobile_jump = mobile_controls.call("consume_jump_request") == true
    var desktop_jump := not mobile_mode and Input.is_key_pressed(KEY_SPACE)
    if (desktop_jump or mobile_jump) and is_on_floor() and not is_crouching:
        velocity.y = jump_velocity

    var target_cam_y = crouching_height if is_crouching else standing_height
    camera.position.y = lerp(camera.position.y, target_cam_y, delta * 10.0)

    # _read_movement_input memilih satu sumber saja: keyboard desktop atau joystick HP.
    var input_dir := _read_movement_input()

    var direction := (
        transform.basis * Vector3(input_dir.x, 0, input_dir.y)
    ).normalized()

    var mobile_run: bool = mobile_mode and mobile_controls.get("run_enabled") == true
    var desktop_run: bool = not mobile_mode and Input.is_key_pressed(KEY_SHIFT)
    var wants_run: bool = (
        (desktop_run or mobile_run)
        and not is_crouching
        and direction.length_squared() > 0.0
    )
    var running: bool = wants_run and not run_exhausted and run_stamina > 0.0
    is_running = running
    _update_stamina_ui()

    var current_speed = speed
    if is_crouching:
        current_speed = crouch_speed
    elif running:
        current_speed = run_speed

    if running:
        run_stamina = maxf(0.0, run_stamina - delta)
        if is_zero_approx(run_stamina):
            run_stamina = 0.0
            run_exhausted = true
    else:
        run_stamina = minf(
            max_run_stamina,
            run_stamina + stamina_recovery_speed * delta
        )

    if run_exhausted and run_stamina >= max_run_stamina:
        run_exhausted = false

    if mobile_mode:
        # Joystick analog: kecepatan mengikuti seberapa jauh stik ditarik, dan gerak
        # mulai/berhenti dihaluskan dengan percepatan & pengereman (tidak langsung patah).
        var target_velocity: Vector3 = direction * current_speed * _move_strength
        var rate: float = mobile_acceleration if direction.length_squared() > 0.0 else mobile_deceleration
        velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
        velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)
    elif direction:
        velocity.x = direction.x * current_speed
        velocity.z = direction.z * current_speed
    else:
        velocity.x = move_toward(velocity.x, 0, current_speed)
        velocity.z = move_toward(velocity.z, 0, current_speed)

    move_and_slide()
    _update_footsteps(delta, direction, running)


## Percepatan/pengereman joystick HP (m/s per detik). Makin besar makin responsif.
@export var mobile_acceleration: float = 45.0
@export var mobile_deceleration: float = 55.0
## Tarikan stik di bawah nilai ini dianggap diam (mencegah gerak sendiri saat jari bergetar).
@export_range(0.0, 0.4) var mobile_deadzone: float = 0.12
var _move_strength := 1.0


func _read_movement_input() -> Vector2:
    _move_strength = 1.0
    if mobile_controls != null and mobile_controls.has_method("is_mobile") and bool(mobile_controls.call("is_mobile")):
        # Dalam mode HP, keyboard desktop tidak ikut menggerakkan pemain.
        var mobile_direction: Vector2 = mobile_controls.get("movement_vector")
        var magnitude := mobile_direction.length()
        if magnitude <= mobile_deadzone:
            _move_strength = 0.0
            return Vector2.ZERO
        # Kecepatan analog: 0 di tepi deadzone sampai 1 saat stik ditarik penuh.
        _move_strength = clampf((magnitude - mobile_deadzone) / (1.0 - mobile_deadzone), 0.0, 1.0)
        return mobile_direction / magnitude
    var input_dir := Vector2.ZERO
    if Input.is_key_pressed(KEY_W):
        input_dir.y -= 1.0
    if Input.is_key_pressed(KEY_S):
        input_dir.y += 1.0
    if Input.is_key_pressed(KEY_A):
        input_dir.x -= 1.0
    if Input.is_key_pressed(KEY_D):
        input_dir.x += 1.0
    return input_dir.normalized()


func _update_footsteps(delta: float, direction: Vector3, running: bool) -> void:
    # Langkah mengikuti perpindahan badan sebenarnya, bukan sekadar tombol ditekan.
    var horizontal_speed := Vector2(velocity.x, velocity.z).length()
    if not is_on_floor() or direction.length_squared() <= 0.0 or horizontal_speed < 0.35:
        _footstep_timer = 0.0
        var stopped_audio := get_tree().get_first_node_in_group("game_audio")
        if stopped_audio == null:
            stopped_audio = get_tree().get_first_node_in_group("audio_manager")
        if stopped_audio != null and stopped_audio.has_method("stop_player_footsteps"):
            stopped_audio.stop_player_footsteps()
        return

    _footstep_timer -= delta
    if _footstep_timer > 0.0:
        return

    var audio := get_tree().get_first_node_in_group("game_audio")
    if audio == null:
        audio = get_tree().get_first_node_in_group("audio_manager")
    if audio == null or not audio.has_method("play_footstep"):
        return

    var volume := -7.0
    var pitch := 1.0
    var base_interval := 0.43
    if is_crouching:
        volume = -9.0
        pitch = 0.94
        base_interval = 0.58
    elif running:
        volume = -5.0
        pitch = 1.04
        base_interval = 0.30

    # Joystick analog berjalan lebih pelan, jadi langkah ikut melambat secara proporsional.
    var reference_speed := crouch_speed if is_crouching else (run_speed if running else speed)
    var speed_ratio := clampf(horizontal_speed / maxf(reference_speed, 0.1), 0.45, 1.15)
    _footstep_timer = base_interval / speed_ratio
    audio.play_footstep(volume, pitch)


func heal(healer: Node = null) -> void:
    if healer == null:
        return

    var game := get_node_or_null("../../GameManager")
    if game != null and game.has_method("revive_player"):
        var revived := bool(game.revive_player(self, healer))
        if not revived:
            var inventory := healer.get_node_or_null("ItemInventory")
            if inventory != null and inventory.has_method("_set_status"):
                inventory.call(
                    "_set_status",
                    "Target belum bisa dihidupkan atau Medkit tidak tersedia."
                )


func is_knocked_out() -> bool:
    return bool(get_meta("knocked_out", false))


func get_run_stamina() -> float:
    return run_stamina


func _build_stamina_ui() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "StaminaUI"
    canvas.layer = 22
    add_child(canvas)

    var root := Control.new()
    root.name = "Root"
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(root)

    var label := Label.new()
    label.name = "StaminaText"
    label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    label.offset_left = -140.0
    label.offset_top = -157.0
    label.offset_right = 140.0
    label.offset_bottom = -137.0
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 13)
    label.text = "STAMINA"
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(label)
    _stamina_text = label

    var bar := ProgressBar.new()
    bar.name = "StaminaBar"
    bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    bar.offset_left = -140.0
    bar.offset_top = -133.0
    bar.offset_right = 140.0
    bar.offset_bottom = -111.0
    bar.min_value = 0.0
    bar.max_value = max_run_stamina
    bar.value = max_run_stamina
    bar.show_percentage = false
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(bar)
    _stamina_bar = bar


func _update_stamina_ui() -> void:
    if _stamina_bar == null:
        return

    _stamina_bar.visible = is_running and not bool(get_meta("knocked_out", false))
    _stamina_text.visible = _stamina_bar.visible
    _stamina_bar.max_value = max_run_stamina
    _stamina_bar.value = run_stamina

    if _stamina_text != null:
        var percent := roundi(
            (run_stamina / maxf(max_run_stamina, 0.001)) * 100.0
        )
        _stamina_text.text = "STAMINA  " + str(percent) + "%"
