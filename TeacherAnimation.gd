extends Node

## Animasi prosedural guru Map58.
## TeacherModel adalah model sederhana tanpa skeleton, jadi gerakan dibuat
## langsung pada mesh bagian tubuh.

@export var walk_cycle_speed: float = 10.5
@export var chase_cycle_speed: float = 16.0
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
var torso_base_rotation := Vector3.ZERO
var ruler_base_rotation := Vector3.ZERO

var jump_animation_active := false

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
var float_blend := 0.0
var float_time := 0.0


func set_intro_floating(active: bool) -> void:
	# Transisi naik/turun dihaluskan di _update_float_blend(), jadi tidak ada snap posisi.
	intro_floating = active


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
		torso_base_rotation = torso.rotation

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


@export var float_hover_height: float = 0.35


func _update_float_blend(delta: float) -> void:
	# Naik pelan saat mulai melayang dan turun pelan saat selesai (tanpa lompatan posisi).
	var target := 1.0 if intro_floating else 0.0
	var rate := 1.4 if intro_floating else 2.2
	float_blend = move_toward(float_blend, target, delta * rate)
	if float_blend <= 0.0:
		if not intro_floating and visual.position != visual_base_position:
			visual.position = visual_base_position
		return
	float_time += delta
	var eased := smoothstep(0.0, 1.0, float_blend)
	var hover := float_hover_height + sin(float_time * 1.7) * 0.05
	visual.position = visual_base_position + Vector3(0.0, hover * eased, 0.0)


# Sumbu model guru: depan = -Z (dasi di z negatif, look_at menghadap -Z).
# Rotasi X positif pada anggota badan yang menggantung = ujung bawahnya ke DEPAN (-Z).
# Semua mesh berpivot di tengah, jadi sendi dihitung manual di fungsi di bawah
# supaya paha/lengan tetap menempel di pinggul/bahu saat berayun.
const FLOAT_ARM_HALF := 0.46
const FLOAT_LEG_HALF := 0.475
const FLOAT_TORSO_HALF := 0.575


func _hinge_center_delta(half_len: float, theta: float) -> Vector3:
	# Pergeseran pusat mesh bila diputar pada pivot di ujung ATAS.
	return Vector3(0.0, half_len * (1.0 - cos(theta)), -half_len * sin(theta))


func _hinge_bottom_delta(half_len: float, theta: float) -> Vector3:
	# Pergeseran ujung BAWAH mesh (sepatu/tangan) pada putaran yang sama.
	return Vector3(0.0, 2.0 * half_len * (1.0 - cos(theta)), -2.0 * half_len * sin(theta))


func _lean_delta(height_above_hip: float, theta: float) -> Vector3:
	# Pergeseran titik setinggi height_above_hip saat badan condong dari pinggul.
	return Vector3(0.0, height_above_hip * (cos(theta) - 1.0), height_above_hip * sin(theta))


func _animate_float_pose(delta: float) -> void:
	# Pose melayang: kaki menjuntai ke belakang, tangan terkulai sedikit ke depan,
	# badan condong ke depan, semuanya bergoyang pelan seperti hantu.
	var w := 1.0 - exp(-delta * 5.0)
	var sway := sin(float_time * 1.7)
	var sway_b := sin(float_time * 1.7 + 1.3)

	var lean := deg_to_rad(-7.0)          # negatif = badan condong ke depan
	var leg_l_theta := deg_to_rad(-12.0 + sway * 4.0)   # negatif = kaki ke belakang
	var leg_r_theta := deg_to_rad(-12.0 + sway_b * 4.0)
	var arm_l_theta := deg_to_rad(12.0 + sway_b * 5.0)  # positif = tangan ke depan
	var arm_r_theta := deg_to_rad(12.0 + sway * 5.0)
	var hip_y := torso_base_position.y - FLOAT_TORSO_HALF

	if torso:
		torso.rotation = torso.rotation.lerp(torso_base_rotation + Vector3(lean, 0.0, 0.0), w)
		torso.position = torso.position.lerp(torso_base_position + _lean_delta(FLOAT_TORSO_HALF, lean), w)
	if head:
		var head_h := head_base_position.y - hip_y
		head.rotation = head.rotation.lerp(head_base_rotation + Vector3(deg_to_rad(3.0), 0.0, deg_to_rad(sway * 2.0)), w)
		head.position = head.position.lerp(head_base_position + _lean_delta(head_h, lean), w)

	if leg_l:
		leg_l.rotation = leg_l.rotation.lerp(leg_l_base_rotation + Vector3(leg_l_theta, 0.0, 0.0), w)
		leg_l.position = leg_l.position.lerp(leg_l_base_position + _hinge_center_delta(FLOAT_LEG_HALF, leg_l_theta), w)
	if leg_r:
		leg_r.rotation = leg_r.rotation.lerp(leg_r_base_rotation + Vector3(leg_r_theta, 0.0, 0.0), w)
		leg_r.position = leg_r.position.lerp(leg_r_base_position + _hinge_center_delta(FLOAT_LEG_HALF, leg_r_theta), w)
	if left_shoe:
		left_shoe.position = left_shoe.position.lerp(left_shoe_base_position + _hinge_bottom_delta(FLOAT_LEG_HALF, leg_l_theta), w)
	if right_shoe:
		right_shoe.position = right_shoe.position.lerp(right_shoe_base_position + _hinge_bottom_delta(FLOAT_LEG_HALF, leg_r_theta), w)

	if arm_l:
		var shoulder_l := _lean_delta(arm_l_base_position.y + FLOAT_ARM_HALF - hip_y, lean)
		arm_l.rotation = arm_l.rotation.lerp(arm_l_base_rotation + Vector3(arm_l_theta, 0.0, deg_to_rad(-10.0)), w)
		arm_l.position = arm_l.position.lerp(arm_l_base_position + shoulder_l + _hinge_center_delta(FLOAT_ARM_HALF, arm_l_theta), w)
		if hand_l:
			hand_l.rotation = hand_l.rotation.lerp(hand_l_base_rotation + Vector3(deg_to_rad(6.0 + sway_b * 4.0), 0.0, deg_to_rad(-6.0)), w)
			hand_l.position = hand_l.position.lerp(hand_l_base_position + shoulder_l + _hinge_bottom_delta(FLOAT_ARM_HALF, arm_l_theta), w)
	if arm_r:
		var shoulder_r := _lean_delta(arm_r_base_position.y + FLOAT_ARM_HALF - hip_y, lean)
		arm_r.rotation = arm_r.rotation.lerp(arm_r_base_rotation + Vector3(arm_r_theta, 0.0, deg_to_rad(10.0)), w)
		arm_r.position = arm_r.position.lerp(arm_r_base_position + shoulder_r + _hinge_center_delta(FLOAT_ARM_HALF, arm_r_theta), w)
		if hand_r:
			hand_r.rotation = hand_r.rotation.lerp(hand_r_base_rotation + Vector3(deg_to_rad(6.0 + sway * 4.0), 0.0, deg_to_rad(6.0)), w)
			hand_r.position = hand_r.position.lerp(hand_r_base_position + shoulder_r + _hinge_bottom_delta(FLOAT_ARM_HALF, arm_r_theta), w)

	if ruler:
		ruler.rotation = ruler.rotation.lerp(ruler_base_rotation + Vector3(0.0, 0.0, deg_to_rad(10.0 + sway * 3.0)), w)

func _animate_jump_pose() -> void:
	# Siluet melompat: lutut terangkat, tangan terbuka, badan condong.
	# Gunakan kecepatan vertikal untuk transisi lepas landas -> melayang.
	var rising := clampf(body.velocity.y / 14.72, 0.0, 1.0)
	var tuck := 1.0 - rising * 0.35

	if leg_l:
		leg_l.rotation = leg_l_base_rotation + Vector3(deg_to_rad(-38.0 * tuck), 0.0, 0.0)
		leg_l.position = leg_l_base_position + Vector3(0.0, 0.10 * tuck, 0.0)
	if leg_r:
		leg_r.rotation = leg_r_base_rotation + Vector3(deg_to_rad(-38.0 * tuck), 0.0, 0.0)
		leg_r.position = leg_r_base_position + Vector3(0.0, 0.10 * tuck, 0.0)
	if left_shoe:
		left_shoe.position = left_shoe_base_position + Vector3(0.0, 0.10 * tuck, 0.0)
	if right_shoe:
		right_shoe.position = right_shoe_base_position + Vector3(0.0, 0.10 * tuck, 0.0)

	if arm_l:
		arm_l.rotation = arm_l_base_rotation + Vector3(deg_to_rad(-18.0), 0.0, deg_to_rad(-28.0))
	if arm_r:
		arm_r.rotation = arm_r_base_rotation + Vector3(deg_to_rad(-18.0), 0.0, deg_to_rad(28.0))
	if hand_l:
		hand_l.rotation = hand_l_base_rotation + Vector3(deg_to_rad(-12.0), 0.0, deg_to_rad(-18.0))
	if hand_r:
		hand_r.rotation = hand_r_base_rotation + Vector3(deg_to_rad(-12.0), 0.0, deg_to_rad(18.0))
	if torso:
		torso.rotation = torso_base_rotation + Vector3(deg_to_rad(-9.0), 0.0, 0.0)
	if head:
		head.rotation = head_base_rotation + Vector3(deg_to_rad(4.0), 0.0, 0.0)
	if ruler:
		ruler.rotation = ruler_base_rotation + Vector3(0.0, 0.0, deg_to_rad(20.0))


func _process(delta: float) -> void:
	if not ready_for_animation or body == null or visual == null:
		return

	_update_float_blend(delta)

	if bool(body.get_meta("capture_pose", false)) and not bool(body.get_meta("capture_dragging", false)):
		# Pose menangkap: condong ke depan, kedua tangan meraih korban.
		var grab_weight := minf(delta * 9.0, 1.0)
		if torso:
			torso.rotation = torso.rotation.lerp(torso_base_rotation + Vector3(deg_to_rad(-22.0), 0.0, 0.0), grab_weight)
		if arm_l:
			arm_l.rotation = arm_l.rotation.lerp(arm_l_base_rotation + Vector3(deg_to_rad(-58.0), 0.0, deg_to_rad(-24.0)), grab_weight)
		if arm_r:
			arm_r.rotation = arm_r.rotation.lerp(arm_r_base_rotation + Vector3(deg_to_rad(-58.0), 0.0, deg_to_rad(24.0)), grab_weight)
		if hand_l:
			hand_l.rotation = hand_l.rotation.lerp(hand_l_base_rotation + Vector3(deg_to_rad(-20.0), 0.0, deg_to_rad(-12.0)), grab_weight)
		if hand_r:
			hand_r.rotation = hand_r.rotation.lerp(hand_r_base_rotation + Vector3(deg_to_rad(-20.0), 0.0, deg_to_rad(12.0)), grab_weight)
		if head:
			head.rotation = head.rotation.lerp(head_base_rotation + Vector3(deg_to_rad(-8.0), 0.0, 0.0), grab_weight)
		if ruler:
			ruler.rotation = ruler.rotation.lerp(ruler_base_rotation + Vector3(0.0, 0.0, deg_to_rad(35.0)), grab_weight)
		return

	if intro_floating:
		_animate_float_pose(delta)
		return

	# Pose loncat dipicu saat guru benar-benar naik, lalu dipertahankan
	# sepanjang udara sampai mendarat. Tidak mengubah posisi fisik/collision.
	if body.velocity.y > 0.5:
		jump_animation_active = true

	if jump_animation_active and not body.is_on_floor():
		_animate_jump_pose()
		return

	if jump_animation_active and body.is_on_floor() and body.velocity.y <= 0.1:
		jump_animation_active = false

	var horizontal_speed := Vector2(
		body.velocity.x,
		body.velocity.z
	).length()

	var moving := horizontal_speed > 0.15

	if moving:
		# Saat menyeret korban, pakai cadence kejar meski kecepatan fisik
		# guru belum mencapai ambang normal chase (8 unit/detik).
		var capture_dragging := bool(body.get_meta("capture_dragging", false))
		var chasing := horizontal_speed >= 8.0 or capture_dragging
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
			torso.rotation = torso.rotation.lerp(torso_base_rotation, settle)

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
