extends Node

## Animasi prosedural guru Map58.
## TeacherModel adalah model sederhana tanpa skeleton, jadi gerakan dibuat
## langsung pada mesh bagian tubuh.

@export var walk_cycle_speed: float = 7.0
@export var chase_cycle_speed: float = 11.0
@export var swing_degrees: float = 30.0
@export var limb_position_swing: float = 0.10
@export var body_bob_height: float = 0.045
@export var head_bob_degrees: float = 2.5
@export var ruler_swing_degrees: float = 12.0

var time_value := 0.0

var body: CharacterBody3D
var visual: Node3D

var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
var torso: Node3D
var head: Node3D
var left_shoe: Node3D
var right_shoe: Node3D
var ruler: Node3D

var leg_l_base_rotation := Vector3.ZERO
var leg_r_base_rotation := Vector3.ZERO
var arm_l_base_rotation := Vector3.ZERO
var arm_r_base_rotation := Vector3.ZERO
var hand_l_base_rotation := Vector3.ZERO
var hand_r_base_rotation := Vector3.ZERO
var head_base_rotation := Vector3.ZERO
var ruler_base_rotation := Vector3.ZERO

var leg_l_base_position := Vector3.ZERO
var leg_r_base_position := Vector3.ZERO
var arm_l_base_position := Vector3.ZERO
var arm_r_base_position := Vector3.ZERO
var hand_l_base_position := Vector3.ZERO
var hand_r_base_position := Vector3.ZERO
var torso_base_position := Vector3.ZERO
var head_base_position := Vector3.ZERO
var left_shoe_base_position := Vector3.ZERO
var right_shoe_base_position := Vector3.ZERO

var ready_for_animation := false
var intro_floating := false
var visual_base_position := Vector3.ZERO


func set_intro_floating(active: bool) -> void:
    intro_floating = active
    if not active:
        if visual != null:
            visual.position = visual_base_position


func _ready() -> void:
    body = get_parent() as CharacterBody3D

    if body == null:
        push_warning(
            "TeacherAnimation: parent CharacterBody3D tidak ditemukan."
        )
        return

    visual = body.get_node_or_null(
        "TeacherModel/Visual"
    ) as Node3D

    if visual == null:
        push_warning(
            "TeacherAnimation: TeacherModel/Visual tidak ditemukan."
        )
        return

    leg_l = visual.get_node_or_null("LeftLeg") as Node3D
    leg_r = visual.get_node_or_null("RightLeg") as Node3D
    arm_l = visual.get_node_or_null("LeftArm") as Node3D
    arm_r = visual.get_node_or_null("RightArm") as Node3D
    hand_l = visual.get_node_or_null("LeftHand") as Node3D
    hand_r = visual.get_node_or_null("RightHand") as Node3D
    torso = visual.get_node_or_null("Torso") as Node3D
    head = visual.get_node_or_null("Head") as Node3D
    left_shoe = visual.get_node_or_null("LeftShoe") as Node3D
    right_shoe = visual.get_node_or_null("RightShoe") as Node3D
    ruler = visual.get_node_or_null("Ruler") as Node3D

    if leg_l:
        leg_l_base_rotation = leg_l.rotation
        leg_l_base_position = leg_l.position

    if leg_r:
        leg_r_base_rotation = leg_r.rotation
        leg_r_base_position = leg_r.position

    if arm_l:
        arm_l_base_rotation = arm_l.rotation
        arm_l_base_position = arm_l.position

    if arm_r:
        arm_r_base_rotation = arm_r.rotation
        arm_r_base_position = arm_r.position

    if hand_l:
        hand_l_base_rotation = hand_l.rotation
        hand_l_base_position = hand_l.position

    if hand_r:
        hand_r_base_rotation = hand_r.rotation
        hand_r_base_position = hand_r.position

    if torso:
        torso_base_position = torso.position

    if head:
        head_base_rotation = head.rotation
        head_base_position = head.position

    if left_shoe:
        left_shoe_base_position = left_shoe.position

    if right_shoe:
        right_shoe_base_position = right_shoe.position

    if ruler:
        ruler_base_rotation = ruler.rotation

    visual_base_position = visual.position
    ready_for_animation = true


func _process(delta: float) -> void:
    if not ready_for_animation or body == null or visual == null:
        return

    if intro_floating:
        # Pose melayang: hentikan siklus kaki/tangan dan beri gerak hover halus.
        visual.position = visual_base_position + Vector3(0.0, 0.045 + sin(Time.get_ticks_msec() * 0.0018) * 0.035, 0.0)
        return

    var horizontal_speed := Vector2(
        body.velocity.x,
        body.velocity.z
    ).length()

    var moving := horizontal_speed > 0.15

    if moving:
        var chasing := horizontal_speed >= 8.0
        var cycle_speed := (
            chase_cycle_speed
            if chasing
            else walk_cycle_speed
        )

        time_value += delta

        var phase := time_value * cycle_speed
        var swing := sin(phase) * deg_to_rad(swing_degrees)
        var arm_swing := -swing

        if leg_l:
            leg_l.rotation = (
                leg_l_base_rotation
                + Vector3(swing, 0.0, 0.0)
            )
            leg_l.position = (
                leg_l_base_position
                + Vector3(
                    0.0,
                    abs(sin(phase)) * 0.025,
                    sin(phase) * limb_position_swing
                )
            )

        if leg_r:
            leg_r.rotation = (
                leg_r_base_rotation
                + Vector3(-swing, 0.0, 0.0)
            )
            leg_r.position = (
                leg_r_base_position
                + Vector3(
                    0.0,
                    abs(sin(phase + PI)) * 0.025,
                    sin(phase + PI) * limb_position_swing
                )
            )

        if arm_l:
            arm_l.rotation = (
                arm_l_base_rotation
                + Vector3(arm_swing, 0.0, 0.0)
            )
            arm_l.position = (
                arm_l_base_position
                + Vector3(
                    0.0,
                    abs(sin(phase + PI)) * 0.018,
                    sin(phase + PI) * limb_position_swing * 0.75
                )
            )

        if arm_r:
            arm_r.rotation = (
                arm_r_base_rotation
                + Vector3(-arm_swing, 0.0, 0.0)
            )
            arm_r.position = (
                arm_r_base_position
                + Vector3(
                    0.0,
                    abs(sin(phase)) * 0.018,
                    sin(phase) * limb_position_swing * 0.75
                )
            )

        if hand_l:
            hand_l.rotation = (
                hand_l_base_rotation
                + Vector3(arm_swing, 0.0, 0.0)
            )
            hand_l.position = (
                hand_l_base_position
                + Vector3(
                    0.0,
                    abs(sin(phase + PI)) * 0.016,
                    sin(phase + PI) * limb_position_swing * 0.65
                )
            )

        if hand_r:
            hand_r.rotation = (
                hand_r_base_rotation
                + Vector3(-arm_swing, 0.0, 0.0)
            )
            hand_r.position = (
                hand_r_base_position
                + Vector3(
                    0.0,
                    abs(sin(phase)) * 0.016,
                    sin(phase) * limb_position_swing * 0.65
                )
            )

        if torso:
            torso.position = (
                torso_base_position
                + Vector3(
                    0.0,
                    sin(phase * 2.0) * body_bob_height,
                    0.0
                )
            )

        if head:
            head.position = (
                head_base_position
                + Vector3(
                    0.0,
                    sin(phase * 2.0) * body_bob_height * 0.6,
                    0.0
                )
            )
            head.rotation = (
                head_base_rotation
                + Vector3(
                    0.0,
                    0.0,
                    sin(phase) * deg_to_rad(head_bob_degrees)
                )
            )

        if left_shoe:
            left_shoe.position = (
                left_shoe_base_position
                + Vector3(
                    0.0,
                    abs(sin(phase)) * 0.025,
                    sin(phase) * limb_position_swing
                )
            )

        if right_shoe:
            right_shoe.position = (
                right_shoe_base_position
                + Vector3(
                    0.0,
                    abs(sin(phase + PI)) * 0.025,
                    sin(phase + PI) * limb_position_swing
                )
            )

        if ruler:
            ruler.rotation = (
                ruler_base_rotation
                + Vector3(
                    0.0,
                    0.0,
                    sin(phase)
                    * deg_to_rad(ruler_swing_degrees)
                )
            )

    else:
        var settle := exp(-delta * 10.0)

        if leg_l:
            leg_l.rotation = leg_l.rotation.lerp(
                leg_l_base_rotation,
                settle
            )
            leg_l.position = leg_l.position.lerp(
                leg_l_base_position,
                settle
            )

        if leg_r:
            leg_r.rotation = leg_r.rotation.lerp(
                leg_r_base_rotation,
                settle
            )
            leg_r.position = leg_r.position.lerp(
                leg_r_base_position,
                settle
            )

        if arm_l:
            arm_l.rotation = arm_l.rotation.lerp(
                arm_l_base_rotation,
                settle
            )
            arm_l.position = arm_l.position.lerp(
                arm_l_base_position,
                settle
            )

        if arm_r:
            arm_r.rotation = arm_r.rotation.lerp(
                arm_r_base_rotation,
                settle
            )
            arm_r.position = arm_r.position.lerp(
                arm_r_base_position,
                settle
            )

        if hand_l:
            hand_l.rotation = hand_l.rotation.lerp(
                hand_l_base_rotation,
                settle
            )
            hand_l.position = hand_l.position.lerp(
                hand_l_base_position,
                settle
            )

        if hand_r:
            hand_r.rotation = hand_r.rotation.lerp(
                hand_r_base_rotation,
                settle
            )
            hand_r.position = hand_r.position.lerp(
                hand_r_base_position,
                settle
            )

        if torso:
            torso.position = torso.position.lerp(
                torso_base_position,
                settle
            )

        if head:
            head.position = head.position.lerp(
                head_base_position,
                settle
            )
            head.rotation = head.rotation.lerp(
                head_base_rotation,
                settle
            )

        if left_shoe:
            left_shoe.position = left_shoe.position.lerp(
                left_shoe_base_position,
                settle
            )

        if right_shoe:
            right_shoe.position = right_shoe.position.lerp(
                right_shoe_base_position,
                settle
            )

        if ruler:
            ruler.rotation = ruler.rotation.lerp(
                ruler_base_rotation,
                settle
            )

        time_value = 0.0
