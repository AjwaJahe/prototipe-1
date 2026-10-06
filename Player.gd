extends CharacterBody3D

@export var speed := 15.0
@export var run_speed := 10.0
@export var crouch_speed := 2.5
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.003

@export var max_run_stamina: float = 5.0
@export var stamina_recovery_speed: float = 1.0

var gravity := 9.8
var is_crouching := false
var run_stamina: float = 5.0
var run_exhausted := false
var _footstep_timer := 0.0

@onready var camera := $Camera3D
@onready var collision_shape := $CollisionShape3D

var standing_height := 1.6
var crouching_height := 0.9

var _stamina_bar: ProgressBar
var _stamina_text: Label


func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    add_to_group("players")
    run_stamina = max_run_stamina
    _build_stamina_ui()
    _update_stamina_ui()


func _process(_delta: float) -> void:
    _update_stamina_ui()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        rotate_y(-event.relative.x * mouse_sensitivity)
        camera.rotate_x(-event.relative.y * mouse_sensitivity)
        camera.rotation.x = clamp(camera.rotation.x, -1.4, 1.4)

    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
    if bool(get_meta("knocked_out", false)):
        velocity = Vector3.ZERO
        return

    if bool(get_meta("intro_locked", false)):
        velocity = Vector3.ZERO
        return

    if not is_on_floor():
        velocity.y -= gravity * delta

    is_crouching = Input.is_key_pressed(KEY_CTRL)

    if Input.is_key_pressed(KEY_SPACE) and is_on_floor() and not is_crouching:
        velocity.y = jump_velocity

    var target_cam_y = crouching_height if is_crouching else standing_height
    camera.position.y = lerp(camera.position.y, target_cam_y, delta * 10.0)

    var input_dir := Vector2.ZERO
    if Input.is_key_pressed(KEY_W):
        input_dir.y -= 1
    if Input.is_key_pressed(KEY_S):
        input_dir.y += 1
    if Input.is_key_pressed(KEY_A):
        input_dir.x -= 1
    if Input.is_key_pressed(KEY_D):
        input_dir.x += 1
    input_dir = input_dir.normalized()

    var direction := (
        transform.basis * Vector3(input_dir.x, 0, input_dir.y)
    ).normalized()

    var wants_run := (
        Input.is_key_pressed(KEY_SHIFT)
        and not is_crouching
        and direction.length_squared() > 0.0
    )
    var running := wants_run and not run_exhausted and run_stamina > 0.0

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

    if direction:
        velocity.x = direction.x * current_speed
        velocity.z = direction.z * current_speed
    else:
        velocity.x = move_toward(velocity.x, 0, current_speed)
        velocity.z = move_toward(velocity.z, 0, current_speed)

    move_and_slide()
    _update_footsteps(delta, direction, running)


func _update_footsteps(delta: float, direction: Vector3, running: bool) -> void:
    if not is_on_floor() or direction.length_squared() <= 0.0:
        _footstep_timer = 0.0
        return

    _footstep_timer -= delta
    if _footstep_timer > 0.0:
        return

    var audio := get_tree().get_first_node_in_group("game_audio")
    if audio != null and audio.has_method("play_footstep"):
        var volume := -7.0
        var pitch := 1.0
        if is_crouching:
            volume = -9.0
            pitch = 0.94
            _footstep_timer = 0.58
        elif running:
            volume = -5.0
            pitch = 1.04
            _footstep_timer = 0.30
        else:
            _footstep_timer = 0.43
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

    _stamina_bar.max_value = max_run_stamina
    _stamina_bar.value = run_stamina

    if _stamina_text != null:
        var percent := roundi(
            (run_stamina / maxf(max_run_stamina, 0.001)) * 100.0
        )
        _stamina_text.text = "STAMINA  " + str(percent) + "%"
