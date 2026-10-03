extends Node

@export var walk_cycle_speed: float = 6.5
@export var chase_cycle_speed: float = 10.0
@export var swing_degrees: float = 24.0
@export var body_bob_height: float = 0.03
@export var ruler_swing_degrees: float = 10.0

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
var ruler: Node3D

var leg_l_base := Vector3.ZERO
var leg_r_base := Vector3.ZERO
var arm_l_base := Vector3.ZERO
var arm_r_base := Vector3.ZERO
var hand_l_base := Vector3.ZERO
var hand_r_base := Vector3.ZERO
var torso_base_y := 0.0
var ruler_base := Vector3.ZERO
var ready_for_animation := false

func _ready() -> void:
	body = get_parent() as CharacterBody3D
	if body == null:
		push_warning("TeacherAnimation: parent CharacterBody3D tidak ditemukan.")
		return

	visual = body.get_node_or_null("TeacherModel/Visual") as Node3D
	if visual == null:
		push_warning("TeacherAnimation: TeacherModel/Visual tidak ditemukan.")
		return

	leg_l = visual.get_node_or_null("LeftLeg") as Node3D
	leg_r = visual.get_node_or_null("RightLeg") as Node3D
	arm_l = visual.get_node_or_null("LeftArm") as Node3D
	arm_r = visual.get_node_or_null("RightArm") as Node3D
	hand_l = visual.get_node_or_null("LeftHand") as Node3D
	hand_r = visual.get_node_or_null("RightHand") as Node3D
	torso = visual.get_node_or_null("Torso") as Node3D
	ruler = visual.get_node_or_null("Ruler") as Node3D

	if leg_l: leg_l_base = leg_l.rotation
	if leg_r: leg_r_base = leg_r.rotation
	if arm_l: arm_l_base = arm_l.rotation
	if arm_r: arm_r_base = arm_r.rotation
	if hand_l: hand_l_base = hand_l.rotation
	if hand_r: hand_r_base = hand_r.rotation
	if torso: torso_base_y = torso.position.y
	if ruler: ruler_base = ruler.rotation

	ready_for_animation = true

func _process(delta: float) -> void:
	if not ready_for_animation or body == null or visual == null:
		return

	var horizontal_speed := Vector2(body.velocity.x, body.velocity.z).length()
	var moving := horizontal_speed > 0.15 and body.is_on_floor()

	if moving:
		var chasing := horizontal_speed >= 8.0
		var cycle_speed := chase_cycle_speed if chasing else walk_cycle_speed
		var swing := sin(time_value * cycle_speed) * deg_to_rad(swing_degrees)
		var arm_swing := -swing

		if leg_l: leg_l.rotation = leg_l_base + Vector3(swing, 0.0, 0.0)
		if leg_r: leg_r.rotation = leg_r_base + Vector3(-swing, 0.0, 0.0)
		if arm_l: arm_l.rotation = arm_l_base + Vector3(arm_swing, 0.0, 0.0)
		if arm_r: arm_r.rotation = arm_r_base + Vector3(-arm_swing, 0.0, 0.0)
		if hand_l: hand_l.rotation = hand_l_base + Vector3(arm_swing, 0.0, 0.0)
		if hand_r: hand_r.rotation = hand_r_base + Vector3(-arm_swing, 0.0, 0.0)
		if torso:
			torso.position.y = torso_base_y + sin(time_value * cycle_speed * 2.0) * body_bob_height
		if ruler:
			ruler.rotation = ruler_base + Vector3(0.0, 0.0, sin(time_value * cycle_speed) * deg_to_rad(ruler_swing_degrees))

		time_value += delta
	else:
		var settle := exp(-delta * 9.0)
		if leg_l: leg_l.rotation = leg_l.rotation.lerp(leg_l_base, settle)
		if leg_r: leg_r.rotation = leg_r.rotation.lerp(leg_r_base, settle)
		if arm_l: arm_l.rotation = arm_l.rotation.lerp(arm_l_base, settle)
		if arm_r: arm_r.rotation = arm_r.rotation.lerp(arm_r_base, settle)
		if hand_l: hand_l.rotation = hand_l.rotation.lerp(hand_l_base, settle)
		if hand_r: hand_r.rotation = hand_r.rotation.lerp(hand_r_base, settle)
		if torso:
			torso.position.y = lerp(torso.position.y, torso_base_y, settle)
		if ruler:
			ruler.rotation = ruler.rotation.lerp(ruler_base, settle)
		time_value = 0.0
