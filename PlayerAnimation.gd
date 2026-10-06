extends Node

@export var walk_cycle_speed: float = 8.0
@export var run_cycle_speed: float = 13.0
@export var swing_degrees: float = 28.0
@export var body_bob_height: float = 0.035

@export var crouch_visual_drop: float = 0.42
@export var crouch_visual_scale: float = 0.78
@export var crouch_torso_angle: float = 12.0
@export var crouch_leg_angle: float = 18.0

@export var jump_leg_angle: float = 24.0
@export var jump_arm_angle: float = 18.0
@export var jump_torso_angle: float = 6.0
@export var jump_bounce_height: float = 0.04

@export var viewmodel_bob_height: float = 0.035
@export var viewmodel_bob_side: float = 0.022
@export var viewmodel_swing_degrees: float = 2.8

var time_value := 0.0

var body: CharacterBody3D
var visual: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var torso: Node3D

var view_model: Node3D
var view_forearm: Node3D
var view_hand: Node3D
var view_held: Node3D

var leg_l_base := Vector3.ZERO
var leg_r_base := Vector3.ZERO
var arm_l_base := Vector3.ZERO
var arm_r_base := Vector3.ZERO
var torso_base_rotation := Vector3.ZERO
var torso_base_position := Vector3.ZERO
var visual_base_position := Vector3.ZERO
var visual_base_scale := Vector3.ONE

var view_model_base_position := Vector3.ZERO
var view_model_base_rotation := Vector3.ZERO
var view_forearm_base_rotation := Vector3.ZERO
var view_hand_base_rotation := Vector3.ZERO
var view_held_base_rotation := Vector3.ZERO

var ready_for_animation := false


func _ready() -> void:
    body = get_parent() as CharacterBody3D
    if body == null:
        push_warning("PlayerAnimation: parent CharacterBody3D tidak ditemukan.")
        return

    visual = body.get_node_or_null("PlayerCharacter/world") as Node3D
    if visual == null:
        push_warning("PlayerAnimation: PlayerCharacter/world tidak ditemukan.")

    leg_l = visual.get_node_or_null("Leg_L") as Node3D if visual != null else null
    leg_r = visual.get_node_or_null("Leg_R") as Node3D if visual != null else null
    arm_l = visual.get_node_or_null("Arm_L") as Node3D if visual != null else null
    arm_r = visual.get_node_or_null("Arm_R") as Node3D if visual != null else null
    torso = visual.get_node_or_null("Torso") as Node3D if visual != null else null

    if leg_l:
        leg_l_base = leg_l.rotation
    if leg_r:
        leg_r_base = leg_r.rotation
    if arm_l:
        arm_l_base = arm_l.rotation
    if arm_r:
        arm_r_base = arm_r.rotation
    if torso:
        torso_base_rotation = torso.rotation
        torso_base_position = torso.position

    if visual != null:
        visual_base_position = visual.position
        visual_base_scale = visual.scale

    view_model = body.get_node_or_null(
        "Camera3D/FirstPersonViewModel"
    ) as Node3D
    if view_model != null:
        view_forearm = view_model.get_node_or_null("Forearm") as Node3D
        view_hand = view_model.get_node_or_null("Hand") as Node3D
        view_held = view_model.get_node_or_null("HeldItem") as Node3D
        view_model_base_position = view_model.position
        view_model_base_rotation = view_model.rotation
        if view_forearm:
            view_forearm_base_rotation = view_forearm.rotation
        if view_hand:
            view_hand_base_rotation = view_hand.rotation
        if view_held:
            view_held_base_rotation = view_held.rotation

    ready_for_animation = visual != null or view_model != null


func _process(delta: float) -> void:
    if not ready_for_animation or body == null:
        return

    if bool(body.get_meta("intro_sitting", false)):
        _animate_sitting(delta)
        return

    var crouching := Input.is_key_pressed(KEY_CTRL)
    var airborne := not body.is_on_floor()
    if airborne:
        _animate_jump(delta)
    elif crouching:
        _animate_crouch(delta)
    else:
        _animate_ground_movement(delta)


func _animate_sitting(delta: float) -> void:
    if visual != null:
        var sitting_position := visual_base_position + Vector3(0.0, -0.50, 0.0)
        _smooth_visual_transform(sitting_position, visual_base_scale, 10.0, delta)

    var torso_angle := deg_to_rad(-8.0)
    var leg_angle := deg_to_rad(-78.0)
    if torso:
        torso.rotation = torso.rotation.lerp(
            torso_base_rotation + Vector3(torso_angle, 0.0, 0.0),
            min(delta * 10.0, 1.0)
        )
    if leg_l:
        leg_l.rotation = leg_l.rotation.lerp(
            leg_l_base + Vector3(leg_angle, 0.0, 0.0),
            min(delta * 10.0, 1.0)
        )
    if leg_r:
        leg_r.rotation = leg_r.rotation.lerp(
            leg_r_base + Vector3(leg_angle, 0.0, 0.0),
            min(delta * 10.0, 1.0)
        )
    if arm_l:
        arm_l.rotation = arm_l.rotation.lerp(arm_l_base, min(delta * 10.0, 1.0))
    if arm_r:
        arm_r.rotation = arm_r.rotation.lerp(arm_r_base, min(delta * 10.0, 1.0))
    if view_model:
        _animate_viewmodel_idle(delta)


func _animate_ground_movement(delta: float) -> void:
    if visual != null:
        _smooth_visual_transform(
            visual_base_position,
            visual_base_scale,
            12.0,
            delta
        )

    var horizontal_speed := Vector2(body.velocity.x, body.velocity.z).length()
    var moving := horizontal_speed > 0.15
    var running := Input.is_key_pressed(KEY_SHIFT) and moving

    if moving:
        var cycle_speed := run_cycle_speed if running else walk_cycle_speed
        var swing := sin(time_value * cycle_speed) * deg_to_rad(swing_degrees)
        var arm_swing := -swing

        if leg_l:
            leg_l.rotation = leg_l_base + Vector3(swing, 0.0, 0.0)
        if leg_r:
            leg_r.rotation = leg_r_base + Vector3(-swing, 0.0, 0.0)
        if arm_l:
            arm_l.rotation = arm_l_base + Vector3(arm_swing, 0.0, 0.0)
        if arm_r:
            arm_r.rotation = arm_r_base + Vector3(-arm_swing, 0.0, 0.0)
        if torso:
            torso.rotation = torso_base_rotation
            torso.position = torso_base_position + Vector3(
                0.0,
                sin(time_value * cycle_speed * 2.0) * body_bob_height,
                0.0
            )

        _animate_viewmodel(delta, cycle_speed, running)
        time_value += delta
    else:
        _return_parts_to_base(delta)
        _animate_viewmodel_idle(delta)
        time_value = 0.0


func _animate_crouch(delta: float) -> void:
    if visual != null:
        var crouch_position := visual_base_position + Vector3(0.0, -crouch_visual_drop, 0.0)
        var crouch_scale := Vector3(
            visual_base_scale.x,
            visual_base_scale.y * crouch_visual_scale,
            visual_base_scale.z
        )
        _smooth_visual_transform(crouch_position, crouch_scale, 14.0, delta)

    var torso_angle := deg_to_rad(crouch_torso_angle)
    var leg_angle := deg_to_rad(crouch_leg_angle)

    if torso:
        torso.rotation = torso.rotation.lerp(
            torso_base_rotation + Vector3(torso_angle, 0.0, 0.0),
            min(delta * 14.0, 1.0)
        )
        torso.position = torso.position.lerp(
            torso_base_position + Vector3(0.0, -0.05, 0.0),
            min(delta * 14.0, 1.0)
        )

    if leg_l:
        leg_l.rotation = leg_l.rotation.lerp(
            leg_l_base + Vector3(-leg_angle, 0.0, 0.0),
            min(delta * 14.0, 1.0)
        )
    if leg_r:
        leg_r.rotation = leg_r.rotation.lerp(
            leg_r_base + Vector3(leg_angle, 0.0, 0.0),
            min(delta * 14.0, 1.0)
        )

    if arm_l:
        arm_l.rotation = arm_l.rotation.lerp(
            arm_l_base + Vector3(-deg_to_rad(8.0), 0.0, 0.0),
            min(delta * 14.0, 1.0)
        )
    if arm_r:
        arm_r.rotation = arm_r.rotation.lerp(
            arm_r_base + Vector3(-deg_to_rad(8.0), 0.0, 0.0),
            min(delta * 14.0, 1.0)
        )

    _animate_viewmodel_crouch(delta)
    time_value = 0.0


func _animate_jump(delta: float) -> void:
    if visual != null:
        _smooth_visual_transform(
            visual_base_position,
            visual_base_scale,
            10.0,
            delta
        )

        var lift: float = clampf(abs(body.velocity.y) / 4.5, 0.0, 1.0)
        var pulse: float = sin(time_value * 12.0) * jump_bounce_height * lift
        visual.position.y = lerp(
            visual.position.y,
            visual_base_position.y + pulse,
            min(delta * 10.0, 1.0)
        )

        var leg_angle: float = deg_to_rad(jump_leg_angle) * lift
        var arm_angle: float = deg_to_rad(jump_arm_angle) * lift
        var torso_angle: float = deg_to_rad(jump_torso_angle) * lift

        if leg_l:
            leg_l.rotation = leg_l.rotation.lerp(
                leg_l_base + Vector3(-leg_angle, 0.0, 0.0),
                min(delta * 12.0, 1.0)
            )
        if leg_r:
            leg_r.rotation = leg_r.rotation.lerp(
                leg_r_base + Vector3(-leg_angle, 0.0, 0.0),
                min(delta * 12.0, 1.0)
            )
        if arm_l:
            arm_l.rotation = arm_l.rotation.lerp(
                arm_l_base + Vector3(arm_angle, 0.0, 0.0),
                min(delta * 12.0, 1.0)
            )
        if arm_r:
            arm_r.rotation = arm_r.rotation.lerp(
                arm_r_base + Vector3(arm_angle, 0.0, 0.0),
                min(delta * 12.0, 1.0)
            )
        if torso:
            torso.rotation = torso.rotation.lerp(
                torso_base_rotation + Vector3(-torso_angle, 0.0, 0.0),
                min(delta * 12.0, 1.0)
            )

    _animate_viewmodel_jump(delta)
    time_value += delta


func _return_parts_to_base(delta: float) -> void:
    var weight: float = minf(delta * 12.0, 1.0)

    if leg_l:
        leg_l.rotation = leg_l.rotation.lerp(leg_l_base, weight)
    if leg_r:
        leg_r.rotation = leg_r.rotation.lerp(leg_r_base, weight)
    if arm_l:
        arm_l.rotation = arm_l.rotation.lerp(arm_l_base, weight)
    if arm_r:
        arm_r.rotation = arm_r.rotation.lerp(arm_r_base, weight)
    if torso:
        torso.rotation = torso.rotation.lerp(torso_base_rotation, weight)
        torso.position = torso.position.lerp(torso_base_position, weight)


func _animate_viewmodel(delta: float, cycle_speed: float, running: bool) -> void:
    if view_model == null:
        return

    var phase := time_value * cycle_speed
    var bob_scale: float = 1.25 if running else 1.0
    var bob_y: float = abs(sin(phase * 2.0)) * viewmodel_bob_height * bob_scale
    var bob_x := sin(phase) * viewmodel_bob_side * bob_scale
    var sway_z := sin(phase) * deg_to_rad(viewmodel_swing_degrees)
    var target_position := view_model_base_position + Vector3(bob_x, bob_y, 0.0)
    var target_rotation := view_model_base_rotation + Vector3(
        deg_to_rad(-1.0) * sin(phase * 2.0),
        0.0,
        sway_z
    )

    var weight := minf(delta * 12.0, 1.0)
    view_model.position = view_model.position.lerp(target_position, weight)
    view_model.rotation = view_model.rotation.lerp(target_rotation, weight)

    var arm_swing := sin(phase) * deg_to_rad(6.0)
    if view_forearm:
        view_forearm.rotation = view_forearm_base_rotation + Vector3(arm_swing, 0.0, 0.0)
    if view_hand:
        view_hand.rotation = view_hand_base_rotation + Vector3(-arm_swing * 0.7, 0.0, 0.0)
    if view_held:
        view_held.rotation = view_held_base_rotation + Vector3(0.0, arm_swing * 0.25, 0.0)


func _animate_viewmodel_idle(delta: float) -> void:
    if view_model == null:
        return

    var idle_phase := Time.get_ticks_msec() * 0.0012
    var target_position := view_model_base_position + Vector3(
        sin(idle_phase) * 0.004,
        sin(idle_phase * 1.4) * 0.004,
        0.0
    )
    var target_rotation := view_model_base_rotation + Vector3(
        sin(idle_phase * 0.9) * 0.008,
        0.0,
        sin(idle_phase) * 0.008
    )
    var weight := minf(delta * 5.0, 1.0)
    view_model.position = view_model.position.lerp(target_position, weight)
    view_model.rotation = view_model.rotation.lerp(target_rotation, weight)


func _animate_viewmodel_crouch(delta: float) -> void:
    if view_model == null:
        return

    var target_position := view_model_base_position + Vector3(0.0, -0.08, 0.0)
    var target_rotation := view_model_base_rotation + Vector3(
        deg_to_rad(-4.0), 0.0, deg_to_rad(2.0)
    )
    var weight := minf(delta * 12.0, 1.0)
    view_model.position = view_model.position.lerp(target_position, weight)
    view_model.rotation = view_model.rotation.lerp(target_rotation, weight)


func _animate_viewmodel_jump(delta: float) -> void:
    if view_model == null:
        return

    var lift := clampf(abs(body.velocity.y) / 4.5, 0.0, 1.0)
    var target_position := view_model_base_position + Vector3(
        0.0, -0.03 * lift, 0.0
    )
    var target_rotation := view_model_base_rotation + Vector3(
        deg_to_rad(-2.0) * lift, 0.0, 0.0
    )
    var weight := minf(delta * 10.0, 1.0)
    view_model.position = view_model.position.lerp(target_position, weight)
    view_model.rotation = view_model.rotation.lerp(target_rotation, weight)


func _smooth_visual_transform(
    target_position: Vector3,
    target_scale: Vector3,
    speed_value: float,
    delta: float
) -> void:
    if visual == null:
        return

    var weight: float = minf(delta * speed_value, 1.0)
    visual.position = visual.position.lerp(target_position, weight)
    visual.scale = visual.scale.lerp(target_scale, weight)
