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

var time_value := 0.0

var body: CharacterBody3D
var visual: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var torso: Node3D

var leg_l_base := Vector3.ZERO
var leg_r_base := Vector3.ZERO
var arm_l_base := Vector3.ZERO
var arm_r_base := Vector3.ZERO
var torso_base_rotation := Vector3.ZERO
var torso_base_position := Vector3.ZERO
var visual_base_position := Vector3.ZERO
var visual_base_scale := Vector3.ONE

var ready_for_animation := false

func _ready() -> void:
	body = get_parent() as CharacterBody3D
	if body == null:
		push_warning("PlayerAnimation: parent CharacterBody3D tidak ditemukan.")
		return

	visual = body.get_node_or_null("PlayerCharacter/world") as Node3D
	if visual == null:
		push_warning("PlayerAnimation: PlayerCharacter/world tidak ditemukan.")
		return

	leg_l = visual.get_node_or_null("Leg_L") as Node3D
	leg_r = visual.get_node_or_null("Leg_R") as Node3D
	arm_l = visual.get_node_or_null("Arm_L") as Node3D
	arm_r = visual.get_node_or_null("Arm_R") as Node3D
	torso = visual.get_node_or_null("Torso") as Node3D

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

	visual_base_position = visual.position
	visual_base_scale = visual.scale
	ready_for_animation = true

func _process(delta: float) -> void:
	if not ready_for_animation or body == null or visual == null:
		return

	var crouching := Input.is_key_pressed(KEY_CTRL)
	var airborne := not body.is_on_floor()

	if airborne:
		_animate_jump(delta)
	elif crouching:
		_animate_crouch(delta)
	else:
		_animate_ground_movement(delta)

func _animate_ground_movement(delta: float) -> void:
	_smooth_visual_transform(
		visual_base_position,
		visual_base_scale,
		12.0,
		delta
	)

	var horizontal_speed := Vector2(body.velocity.x, body.velocity.z).length()
	var moving := horizontal_speed > 0.15
	var running := Input.is_key_pressed(KEY_SHIFT)

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

		time_value += delta
	else:
		_return_parts_to_base(delta)
		time_value = 0.0

func _animate_crouch(delta: float) -> void:
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

	time_value = 0.0

func _animate_jump(delta: float) -> void:
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

func _smooth_visual_transform(
	target_position: Vector3,
	target_scale: Vector3,
	speed_value: float,
	delta: float
) -> void:
	var weight: float = minf(delta * speed_value, 1.0)
	visual.position = visual.position.lerp(target_position, weight)
	visual.scale = visual.scale.lerp(target_scale, weight)
